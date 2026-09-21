import 'package:catatan_keuangan/models/month_summary.dart';
import 'package:catatan_keuangan/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel _tx(int amount, TxType type) => TransactionModel(
      title: 'uji',
      amount: amount,
      type: type,
      category: 'Lainnya',
      date: DateTime(2026, 9, 1),
    );

void main() {
  group('MonthSummary.fromTransactions', () {
    test('memisahkan pemasukan dan pengeluaran', () {
      final summary = MonthSummary.fromTransactions([
        _tx(500000, TxType.income),
        _tx(100000, TxType.expense),
        _tx(50000, TxType.expense),
      ]);

      expect(summary.income, 500000);
      expect(summary.expense, 150000);
      expect(summary.balance, 350000);
    });

    test('saldo memperhitungkan sisa bulan lalu', () {
      final summary = MonthSummary.fromTransactions(
        [_tx(250000, TxType.income)],
        carry: 100000,
      );

      expect(summary.balance, 350000);
      expect(summary.withCarry(0).carry, 0);
    });

    test('daftar kosong menghasilkan nol', () {
      final summary = MonthSummary.fromTransactions(const []);

      expect(summary.income, 0);
      expect(summary.expense, 0);
      expect(summary.balance, 0);
    });
  });

  group('TransactionModel.signedAmount', () {
    test('pemasukan menambah, pengeluaran mengurangi', () {
      expect(_tx(1000, TxType.income).signedAmount, 1000);
      expect(_tx(1000, TxType.expense).signedAmount, -1000);
    });
  });
}
