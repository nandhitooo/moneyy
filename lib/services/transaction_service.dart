import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/funding_source.dart';
import '../models/source_breakdown.dart';
import '../models/transaction_model.dart';

class TransactionService {
  /// Versi skema field `signedAmount`. Naikkan bila rumusnya berubah, supaya
  /// pengisian ulang data lama dijalankan lagi.
  static const signedAmountVersion = 1;

  static Future<void>? _migrationInFlight;

  final _db = FirebaseFirestore.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Pengguna belum login.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('transactions');

  DocumentReference<Map<String, dynamic>> get _metaRef =>
      _db.collection('users').doc(_uid).collection('meta').doc('migration');

  /// Stream transaksi satu bulan, terbaru di atas.
  Stream<List<TransactionModel>> watchMonth(DateTime month) {
    final (start, end) = _monthRange(month);
    return _col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(TransactionModel.fromDoc).toList());
  }

  /// Saldo bersih (pemasukan - pengeluaran) semua transaksi sebelum bulan ini.
  ///
  /// Memakai agregasi `sum(signedAmount)` dengan filter `date`. Firestore
  /// menghitung agregasi lewat index scan, jadi butuh composite index
  /// `date` + `signedAmount` dari `firestore.indexes.json`.
  Future<int> balanceBefore(DateTime month) async {
    await _ensureSignedAmountsSafely();
    final start = Timestamp.fromDate(_monthRange(month).$1);
    final snapshot = await _col
        .where('date', isLessThan: start)
        .aggregate(sum('signedAmount'))
        .get();
    return snapshot.getSum('signedAmount')?.round() ?? 0;
  }

  Future<void> add(TransactionModel tx) async {
    await _col.add({
      ...tx.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Dipakai untuk undo hapus: menulis ulang transaksi dengan id aslinya.
  Future<void> restore(TransactionModel tx) async {
    await _col.doc(tx.id).set({
      ...tx.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(TransactionModel tx) {
    final id = tx.id;
    if (id == null) {
      throw ArgumentError('Transaksi tanpa id tidak bisa diubah.');
    }
    return _col.doc(id).update(tx.toMap());
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Total seluruh transaksi, tanpa filter sumber dana.
  Future<SourceTotal> totalsOverall() => _totals(_col);

  /// Total per sumber dana, memakai agregasi sehingga dokumen transaksi tidak
  /// perlu diunduh.
  ///
  /// Filter `sourceId` selalu dipasangkan dengan agregasi `sum`, jadi butuh
  /// composite index `sourceId` + `amount` dan `sourceId` + `signedAmount`.
  /// Transaksi tanpa sumber dihitung sebagai selisih di [loadSourceTotals].
  Future<List<SourceTotal>> totalsBySource(Iterable<String> sourceIds) =>
      Future.wait(sourceIds.map((id) =>
          _totals(_col.where('sourceId', isEqualTo: id), sourceId: id)));

  /// Memuat total keseluruhan sekaligus total per sumber dana.
  ///
  /// Jalur utama memakai agregasi Firestore. Bila agregasi ditolak, angka
  /// dihitung di perangkat supaya saldo tetap tampil, dan hasilnya ditandai
  /// [SourceTotals.computedOnClient].
  Future<SourceTotals> loadSourceTotals(
    Iterable<FundingSource> sources,
  ) async {
    final list = sources.toList();
    await _ensureSignedAmountsSafely();

    try {
      return await _aggregateSourceTotals(list);
    } on FirebaseException catch (e) {
      debugPrint('Agregasi saldo gagal (${e.code}): ${e.message}');
      return _clientSideSourceTotals(list);
    }
  }

  Future<SourceTotals> _aggregateSourceTotals(
    List<FundingSource> sources,
  ) async {
    final ids = sources.map((s) => s.id).whereType<String>().toList();
    final overall = await totalsOverall();
    final perSource = await totalsBySource(ids);

    var knownIncome = 0;
    var knownExpense = 0;
    for (final total in perSource) {
      knownIncome += total.income;
      knownExpense += total.expense;
    }

    return SourceTotals(
      overall: overall,
      bySourceId: {
        for (final total in perSource) total.sourceId ?? '': total,
        // Transaksi tanpa sumber (atau bersumber yang sudah tidak ada) dihitung
        // sebagai selisih, jadi tidak perlu query `sourceId == null`.
        '': SourceTotal(
          income: overall.income - knownIncome,
          expense: overall.expense - knownExpense,
        ),
      },
    );
  }

  /// Cadangan tanpa agregasi: seluruh dokumen transaksi dibaca lalu dijumlahkan
  /// di perangkat. Hanya dipakai saat agregasi ditolak.
  Future<SourceTotals> _clientSideSourceTotals(
    List<FundingSource> sources,
  ) async {
    final knownIds = sources.map((s) => s.id).whereType<String>().toSet();
    final snapshot = await _col.get();

    var overallIncome = 0;
    var overallExpense = 0;
    final incomeById = <String, int>{};
    final expenseById = <String, int>{};

    for (final doc in snapshot.docs) {
      final transaction = TransactionModel.fromDoc(doc);
      final sourceId = transaction.sourceId;
      final key =
          sourceId != null && knownIds.contains(sourceId) ? sourceId : '';

      if (transaction.isIncome) {
        overallIncome += transaction.amount;
        incomeById[key] = (incomeById[key] ?? 0) + transaction.amount;
      } else {
        overallExpense += transaction.amount;
        expenseById[key] = (expenseById[key] ?? 0) + transaction.amount;
      }
    }

    return SourceTotals(
      overall: SourceTotal(income: overallIncome, expense: overallExpense),
      bySourceId: {
        for (final source in sources)
          if (source.id != null)
            source.id!: SourceTotal(
              sourceId: source.id,
              income: incomeById[source.id] ?? 0,
              expense: expenseById[source.id] ?? 0,
            ),
        '': SourceTotal(
          income: incomeById[''] ?? 0,
          expense: expenseById[''] ?? 0,
        ),
      },
      computedOnClient: true,
    );
  }

  /// Jumlah transaksi yang memakai satu sumber dana, dipakai sebagai pengaman
  /// sebelum sumber dana dihapus.
  Future<int> countBySource(String sourceId) async {
    final result =
        await _col.where('sourceId', isEqualTo: sourceId).count().get();
    return result.count ?? 0;
  }

  /// Menghitung total dari dua agregasi: `sum(amount)` untuk arus dana dan
  /// `sum(signedAmount)` untuk saldo bersih. Keduanya butuh composite index
  /// dengan field filter di depan (lihat `firestore.indexes.json`).
  Future<SourceTotal> _totals(
    Query<Map<String, dynamic>> query, {
    String? sourceId,
  }) async {
    final sums = await Future.wait([
      query.aggregate(sum('amount')).get(),
      query.aggregate(sum('signedAmount')).get(),
    ]);
    return SourceTotal.fromNetAndFlow(
      sourceId: sourceId,
      flow: sums[0].getSum('amount')?.round() ?? 0,
      net: sums[1].getSum('signedAmount')?.round() ?? 0,
    );
  }

  /// Menjalankan pengisian `signedAmount` tanpa menggagalkan pemuatan saldo:
  /// data lama yang belum lengkap cukup membuat angkanya kurang tepat, bukan
  /// membuat layar error.
  Future<void> _ensureSignedAmountsSafely() async {
    try {
      await _ensureSignedAmounts();
    } catch (e) {
      debugPrint('Pengisian field signedAmount dilewati: $e');
    }
  }

  /// Memastikan setiap transaksi punya field `signedAmount` supaya agregasi
  /// saldo bisa memakai satu field saja.
  ///
  /// Hanya berjalan sekali per versi skema; penanda disimpan di
  /// `users/{uid}/meta/migration`.
  Future<void> _ensureSignedAmounts() {
    return _migrationInFlight ??=
        _runEnsureSignedAmounts().whenComplete(() => _migrationInFlight = null);
  }

  Future<void> _runEnsureSignedAmounts() async {
    final meta = await _metaRef.get();
    final doneVersion =
        (meta.data()?['signedAmountVersion'] as num?)?.toInt() ?? 0;
    if (doneVersion >= signedAmountVersion) return;

    final snapshot = await _col.get();
    final updates = <(DocumentReference<Map<String, dynamic>>, int)>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toInt() ?? 0;
      final expected = data['type'] == 'income' ? amount : -amount;
      if ((data['signedAmount'] as num?)?.toInt() != expected) {
        updates.add((doc.reference, expected));
      }
    }

    // Firestore membatasi 500 operasi per batch.
    const chunkSize = 400;
    for (var i = 0; i < updates.length; i += chunkSize) {
      final batch = _db.batch();
      for (final (reference, value) in updates.skip(i).take(chunkSize)) {
        batch.update(reference, {'signedAmount': value});
      }
      await batch.commit();
    }

    await _metaRef.set({
      'signedAmountVersion': signedAmountVersion,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Awal bulan dan awal bulan berikutnya, dipakai untuk filter rentang.
  static (DateTime, DateTime) _monthRange(DateTime month) => (
        DateTime(month.year, month.month),
        DateTime(month.year, month.month + 1),
      );
}
