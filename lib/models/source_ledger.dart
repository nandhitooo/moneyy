import 'transaction_model.dart';

/// Satu transaksi beserta saldo sumber dana setelah transaksi itu dicatat.
class SourceLedgerEntry {
  final TransactionModel transaction;

  /// Saldo sumber dana sesudah transaksi ini.
  final int balance;

  const SourceLedgerEntry({required this.transaction, required this.balance});
}

/// Riwayat satu sumber dana dengan saldo berjalan.
///
/// Transaksi diurutkan dari yang terlama untuk menghitung saldo bertahap, lalu
/// dibalik supaya yang terbaru tampil di atas. [initialBalance] menjadi saldo
/// sebelum transaksi pertama, sama seperti perhitungan saldo di layar sumber
/// dana.
class SourceLedger {
  final int initialBalance;

  /// Transaksi dengan saldo berjalannya, terbaru di atas.
  final List<SourceLedgerEntry> entries;

  const SourceLedger({this.initialBalance = 0, this.entries = const []});

  /// Saldo terkini: saldo setelah transaksi terbaru, atau saldo awal bila belum
  /// ada transaksi.
  int get balance => entries.isEmpty ? initialBalance : entries.first.balance;

  int get transactionCount => entries.length;

  factory SourceLedger.fromTransactions(
    Iterable<TransactionModel> transactions, {
    int initialBalance = 0,
  }) {
    final sorted = transactions.toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        // Tanggal sama: urutkan memakai id supaya saldo berjalan tetap stabil
        // setiap kali daftar dimuat.
        return (a.id ?? '').compareTo(b.id ?? '');
      });

    var balance = initialBalance;
    final entries = <SourceLedgerEntry>[];
    for (final transaction in sorted) {
      balance += transaction.signedAmount;
      entries.add(
        SourceLedgerEntry(transaction: transaction, balance: balance),
      );
    }

    return SourceLedger(
      initialBalance: initialBalance,
      entries: entries.reversed.toList(),
    );
  }
}
