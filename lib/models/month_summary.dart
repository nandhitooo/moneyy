import 'transaction_model.dart';

/// Ringkasan uang untuk satu bulan.
///
/// Saldo = sisa bulan-bulan sebelumnya (carry) + pemasukan - pengeluaran.
class MonthSummary {
  final int income;
  final int expense;
  final int carry;

  const MonthSummary({
    required this.income,
    required this.expense,
    this.carry = 0,
  });

  factory MonthSummary.fromTransactions(
    Iterable<TransactionModel> transactions, {
    int carry = 0,
  }) {
    var income = 0;
    var expense = 0;
    for (final t in transactions) {
      if (t.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return MonthSummary(income: income, expense: expense, carry: carry);
  }

  int get balance => carry + income - expense;

  MonthSummary withCarry(int carry) =>
      MonthSummary(income: income, expense: expense, carry: carry);
}
