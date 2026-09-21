import 'package:cloud_firestore/cloud_firestore.dart';

/// Sumber dana: dari mana uangnya masuk atau keluar.
///
/// `isCash` membedakan uang tunai dari uang non-tunai (rekening bank,
/// e-wallet, dan sejenisnya). Nama sumber bebas ditentukan pengguna.
class FundingSource {
  final String? id;
  final String name;
  final bool isCash;

  const FundingSource({
    this.id,
    required this.name,
    this.isCash = false,
  });

  factory FundingSource.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return FundingSource(
      id: doc.id,
      name: (d['name'] as String?) ?? 'Tanpa nama',
      isCash: (d['isCash'] as bool?) ?? false,
    );
  }

  /// Sumber dana bawaan saat pengguna belum punya daftar sendiri.
  static const defaults = [
    FundingSource(name: 'Tunai', isCash: true),
    FundingSource(name: 'Rekening Bank'),
    FundingSource(name: 'E-Wallet'),
  ];

  FundingSource copyWith({String? id, String? name, bool? isCash}) =>
      FundingSource(
        id: id ?? this.id,
        name: name ?? this.name,
        isCash: isCash ?? this.isCash,
      );

  Map<String, dynamic> toMap() => {'name': name, 'isCash': isCash};
}
