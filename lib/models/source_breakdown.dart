import 'funding_source.dart';
import 'transaction_model.dart';

/// Label untuk transaksi lama yang belum punya sumber dana.
const unknownSourceLabel = 'Belum diisi';

/// Total pemasukan dan pengeluaran per sumber dana.
class SourceBreakdown {
  /// Id sumber dana, null bila transaksi belum punya sumber.
  final String? sourceId;
  final String name;
  final int income;
  final int expense;

  /// True bila sumbernya uang tunai. Transaksi lama bisa bernilai null.
  final bool? isCash;

  const SourceBreakdown({
    this.sourceId,
    required this.name,
    this.income = 0,
    this.expense = 0,
    this.isCash,
  });

  /// Pemasukan dikurangi pengeluaran untuk sumber dana ini.
  int get net => income - expense;

  int get total => income + expense;

  /// Mengelompokkan transaksi per sumber dana, terbesar di atas.
  ///
  /// Pengelompokan memakai id sumber agar sumber dengan nama sama tetap
  /// terpisah, dan memakai nama yang tersalin di transaksi supaya transaksi
  /// lama tetap tampil setelah sumbernya dihapus.
  static List<SourceBreakdown> group(
    Iterable<TransactionModel> transactions,
  ) {
    final byId = <String, SourceBreakdown>{};
    for (final t in transactions) {
      final key = t.sourceId ?? '';
      final current = byId[key];
      byId[key] = SourceBreakdown(
        sourceId: key.isEmpty ? null : key,
        name: current?.name ?? (t.sourceName ?? unknownSourceLabel),
        income: (current?.income ?? 0) + (t.isIncome ? t.amount : 0),
        expense: (current?.expense ?? 0) + (t.isIncome ? 0 : t.amount),
        isCash: current?.isCash ?? t.sourceIsCash,
      );
    }

    final result = byId.values.toList()
      ..sort((a, b) {
        final byExpense = b.expense.compareTo(a.expense);
        return byExpense != 0 ? byExpense : a.name.compareTo(b.name);
      });
    return result;
  }

}

/// Total pemasukan dan pengeluaran satu sumber dana dari hasil agregasi.
///
/// Berbeda dari [SourceBreakdown] yang dihitung dari daftar transaksi, kelas
/// ini hanya berisi angka, jadi nama sumber diambil dari daftar sumber dana.
class SourceTotal {
  /// Null berarti semua transaksi, atau transaksi tanpa sumber dana
  /// bergantung pada cara pemanggilan agregasi.
  final String? sourceId;
  final int income;
  final int expense;

  const SourceTotal({
    this.sourceId,
    this.income = 0,
    this.expense = 0,
  });

  /// Menyusun total dari dua hasil agregasi:
  /// `flow` = semua arus dana (pemasukan + pengeluaran),
  /// `net` = saldo bersih (pemasukan - pengeluaran).
  factory SourceTotal.fromNetAndFlow({
    String? sourceId,
    int net = 0,
    int flow = 0,
  }) {
    // flow = income + expense dan net = income - expense, jadi:
    // income = (flow + net) / 2 dan expense = (flow - net) / 2.
    final income = (flow + net) ~/ 2;
    final expense = (flow - net) ~/ 2;
    return SourceTotal(
      sourceId: sourceId,
      income: income < 0 ? 0 : income,
      expense: expense < 0 ? 0 : expense,
    );
  }

  int get net => income - expense;

  int get total => income + expense;

  bool get isEmpty => income == 0 && expense == 0;
}

/// Hasil agregasi saldo: total keseluruhan plus rincian per sumber dana.
///
/// Kunci peta `bySourceId` memakai string kosong untuk transaksi yang belum
/// punya sumber dana.
class SourceTotals {
  final SourceTotal overall;
  final Map<String, SourceTotal> bySourceId;

  /// True bila angka dihitung di perangkat karena agregasi Firestore gagal
  /// (misalnya index komposit belum siap).
  final bool computedOnClient;

  const SourceTotals({
    this.overall = const SourceTotal(),
    this.bySourceId = const {},
    this.computedOnClient = false,
  });

  SourceTotal? forSource(String? sourceId) => bySourceId[sourceId ?? ''];

  /// Saldo transaksi yang belum punya sumber dana.
  SourceTotal? get unknown => bySourceId[''];

  /// Jumlah saldo sumber bertanda tunai (`isCash` true) atau non-tunai.
  int cashNet(bool isCash, Iterable<FundingSource> sources) {
    var sum = 0;
    for (final source in sources) {
      if (source.isCash == isCash) {
        sum += forSource(source.id)?.net ?? 0;
      }
    }
    return sum;
  }
}

