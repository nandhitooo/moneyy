import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/funding_source.dart';

/// Daftar sumber dana milik satu pengguna.
///
/// Nama sumber disalin ke setiap transaksi, jadi menghapus sumber dana tidak
/// membuat transaksi lama kehilangan keterangan.
class FundingSourceService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Pengguna belum login.');
    return _db.collection('users').doc(uid).collection('sources');
  }

  Stream<List<FundingSource>> watch() => _col
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(FundingSource.fromDoc).toList());

  /// Menulis sumber dana bawaan bila pengguna belum punya satu pun.
  /// Mengembalikan true bila penulisan dilakukan.
  Future<bool> ensureDefaults() async {
    final snapshot = await _col.limit(1).get();
    if (snapshot.docs.isNotEmpty) return false;

    final batch = _db.batch();
    for (final source in FundingSource.defaults) {
      batch.set(_col.doc(), {...source.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
    return true;
  }

  Future<void> add(String name, {required bool isCash}) => _col.add({
        'name': name,
        'isCash': isCash,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> update(FundingSource source) {
    final id = source.id;
    if (id == null) throw ArgumentError('Sumber dana tanpa id tidak bisa diubah.');
    return _col.doc(id).update(source.toMap());
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
