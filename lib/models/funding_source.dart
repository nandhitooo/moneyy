import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_fee_schedule.dart';

/// Jenis sumber dana.
///
/// Nilai [name] dipakai sebagai field `type` di Firestore, jadi jangan diubah
/// tanpa migrasi dokumen lama.
enum FundingSourceType {
  cash('Uang tunai'),
  bank('Rekening bank'),
  eWallet('E-wallet');

  const FundingSourceType(this.label);

  /// Label yang ditampilkan ke pengguna.
  final String label;

  /// Membaca jenis sumber dari dokumen Firestore.
  ///
  /// Dokumen lama hanya menyimpan `isCash`, jadi jenisnya diturunkan dari field
  /// itu: tunai atau rekening bank.
  static FundingSourceType fromDoc(Map<String, dynamic> data) {
    final name = data['type'] as String?;
    for (final type in values) {
      if (type.name == name) return type;
    }
    return (data['isCash'] as bool?) ?? false
        ? FundingSourceType.cash
        : FundingSourceType.bank;
  }
}

/// Sumber dana: dari mana uangnya masuk atau keluar.
///
/// [type] membedakan uang tunai, rekening bank, dan e-wallet. Nama sumber bebas
/// ditentukan pengguna. [initialBalance] menyimpan uang yang sudah ada sebelum
/// transaksi pertama dicatat, supaya saldo bisa diisi tanpa transaksi palsu.
class FundingSource {
  final String? id;
  final String name;
  final FundingSourceType type;

  /// Saldo awal dalam Rupiah, ikut dihitung pada saldo sumber ini.
  final int initialBalance;

  /// Biaya admin bulanan dalam Rupiah. 0 berarti tidak ada biaya admin.
  final int adminFee;

  /// Tanggal potong biaya admin (1-31). Null bila belum diatur.
  final int? adminFeeDay;

  const FundingSource({
    this.id,
    required this.name,
    this.type = FundingSourceType.bank,
    this.initialBalance = 0,
    this.adminFee = 0,
    this.adminFeeDay,
  });

  factory FundingSource.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return FundingSource(
      id: doc.id,
      name: (d['name'] as String?) ?? 'Tanpa nama',
      type: FundingSourceType.fromDoc(d),
      initialBalance: (d['initialBalance'] as num?)?.toInt() ?? 0,
      adminFee: (d['adminFee'] as num?)?.toInt() ?? 0,
      adminFeeDay: (d['adminFeeDay'] as num?)?.toInt(),
    );
  }

  /// Jadwal biaya admin, atau null bila nominal atau tanggalnya belum diatur.
  ///
  /// Tanggal yang tersimpan di luar 1-31 diabaikan supaya dokumen lama yang
  /// rusak tidak membuat layar error.
  AdminFeeSchedule? get adminFeeSchedule {
    final day = adminFeeDay;
    if (adminFee <= 0 || day == null || day < 1 || day > 31) return null;
    return AdminFeeSchedule(amount: adminFee, dayOfMonth: day);
  }

  /// True bila sumbernya uang tunai. Transaksi menyalin penanda ini, jadi
  /// nilainya tetap disimpan di dokumen.
  bool get isCash => type == FundingSourceType.cash;

  /// Sumber dana bawaan saat pengguna belum punya daftar sendiri.
  static const defaults = [
    FundingSource(name: 'Tunai', type: FundingSourceType.cash),
    FundingSource(name: 'Rekening Bank', type: FundingSourceType.bank),
    FundingSource(name: 'E-Wallet', type: FundingSourceType.eWallet),
  ];

  FundingSource copyWith({
    String? id,
    String? name,
    FundingSourceType? type,
    int? initialBalance,
    int? adminFee,
    int? adminFeeDay,
  }) =>
      FundingSource(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        initialBalance: initialBalance ?? this.initialBalance,
        adminFee: adminFee ?? this.adminFee,
        adminFeeDay: adminFeeDay ?? this.adminFeeDay,
      );

  /// `isCash` tetap ditulis supaya versi aplikasi lama dan data transaksi tetap
  /// konsisten.
  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type.name,
        'isCash': isCash,
        'initialBalance': initialBalance,
        'adminFee': adminFee,
        'adminFeeDay': adminFeeDay,
      };
}
