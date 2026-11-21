import 'package:catatan_keuangan/models/source_ledger.dart';
import 'package:catatan_keuangan/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel _tx({
  required String id,
  required int amount,
  required DateTime date,
  TxType type = TxType.expense,
}) =>
    TransactionModel(
      id: id,
      title: id,
      amount: amount,
      type: type,
      category: 'Lainnya',
      date: date,
    );

void main() {
  group('SourceLedger', () {
    test('saldo berjalan dimulai dari saldo awal, terbaru di atas', () {
      final ledger = SourceLedger.fromTransactions(
        [
          _tx(
            id: 'b',
            amount: 50000,
            date: DateTime(2026, 1, 2),
          ),
          _tx(
            id: 'a',
            amount: 200000,
            date: DateTime(2026, 1, 1),
            type: TxType.income,
          ),
        ],
        initialBalance: 100000,
      );

      expect(ledger.entries.map((e) => e.transaction.id), ['b', 'a']);
      expect(ledger.entries.first.balance, 250000);
      expect(ledger.entries.last.balance, 300000);
      expect(ledger.balance, 250000);
      expect(ledger.transactionCount, 2);
    });

    test('tanpa transaksi, saldo sama dengan saldo awal', () {
      final ledger = SourceLedger.fromTransactions(
        const [],
        initialBalance: 75000,
      );

      expect(ledger.entries, isEmpty);
      expect(ledger.balance, 75000);
      expect(ledger.transactionCount, 0);
    });

    test('tanggal sama diurutkan memakai id agar saldo stabil', () {
      final date = DateTime(2026, 2, 1);
      final ledger = SourceLedger.fromTransactions([
        _tx(id: 'z', amount: 20000, date: date),
        _tx(id: 'm', amount: 10000, date: date, type: TxType.income),
      ]);

      // Urutan perhitungan: m (pemasukan) lebih dulu, lalu z.
      expect(ledger.entries.map((e) => e.transaction.id), ['z', 'm']);
      expect(ledger.entries.first.balance, -10000);
      expect(ledger.entries.last.balance, 10000);
    });
  });
}
