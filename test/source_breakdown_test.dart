import 'package:catatan_keuangan/models/funding_source.dart';
import 'package:catatan_keuangan/models/source_breakdown.dart';
import 'package:catatan_keuangan/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel _tx({
  required int amount,
  required TxType type,
  String? sourceId,
  String? sourceName,
  bool? sourceIsCash,
}) =>
    TransactionModel(
      title: 'uji',
      amount: amount,
      type: type,
      category: 'Lainnya',
      date: DateTime(2026, 9, 1),
      sourceId: sourceId,
      sourceName: sourceName,
      sourceIsCash: sourceIsCash,
    );

void main() {
  group('SourceBreakdown.group', () {
    test('menjumlahkan pemasukan dan pengeluaran per sumber', () {
      final result = SourceBreakdown.group([
        _tx(
          amount: 500000,
          type: TxType.income,
          sourceId: 'bank',
          sourceName: 'BCA',
          sourceIsCash: false,
        ),
        _tx(
          amount: 200000,
          type: TxType.expense,
          sourceId: 'bank',
          sourceName: 'BCA',
          sourceIsCash: false,
        ),
        _tx(
          amount: 50000,
          type: TxType.expense,
          sourceId: 'cash',
          sourceName: 'Tunai',
          sourceIsCash: true,
        ),
      ]);

      expect(result, hasLength(2));
      final bank = result.firstWhere((s) => s.name == 'BCA');
      expect(bank.income, 500000);
      expect(bank.expense, 200000);
      expect(bank.net, 300000);
      expect(bank.total, 700000);
      expect(bank.isCash, isFalse);

      final cash = result.firstWhere((s) => s.name == 'Tunai');
      expect(cash.isCash, isTrue);
      expect(cash.expense, 50000);
    });

    test('transaksi tanpa sumber masuk ke label "Belum diisi"', () {
      final result = SourceBreakdown.group([
        _tx(amount: 10000, type: TxType.expense),
      ]);

      expect(result.single.name, unknownSourceLabel);
      expect(result.single.isCash, isNull);
    });

    test('diurutkan dari pengeluaran terbesar', () {
      final result = SourceBreakdown.group([
        _tx(amount: 10000, type: TxType.expense, sourceId: 'a', sourceName: 'A'),
        _tx(amount: 90000, type: TxType.expense, sourceId: 'b', sourceName: 'B'),
      ]);

      expect(result.map((s) => s.name), ['B', 'A']);
    });

    test('daftar kosong menghasilkan daftar kosong', () {
      expect(SourceBreakdown.group(const []), isEmpty);
    });

    test('menyimpan id sumber pada hasil pengelompokan', () {
      final grouped = SourceBreakdown.group([
        _tx(
          amount: 25000,
          type: TxType.expense,
          sourceId: 'cash',
          sourceName: 'Tunai',
        ),
        _tx(amount: 10000, type: TxType.expense),
      ]);

      expect(grouped.map((b) => b.sourceId), containsAll(['cash', null]));
    });
  });

  group('SourceTotal', () {
    test('net adalah pemasukan dikurangi pengeluaran', () {
      const total = SourceTotal(
        sourceId: 'bank',
        income: 900000,
        expense: 250000,
      );

      expect(total.net, 650000);
      expect(total.total, 1150000);
      expect(total.sourceId, 'bank');
    });

    test('nilai awal nol', () {
      const total = SourceTotal();

      expect(total.net, 0);
      expect(total.sourceId, isNull);
      expect(total.isEmpty, isTrue);
    });

    test('fromNetAndFlow memulihkan pemasukan dan pengeluaran', () {
      final total = SourceTotal.fromNetAndFlow(
        sourceId: 'bank',
        flow: 1150000,
        net: 650000,
      );

      expect(total.income, 900000);
      expect(total.expense, 250000);
      expect(total.net, 650000);
      expect(total.sourceId, 'bank');
    });

    test('fromNetAndFlow menangani nilai nol dan minus', () {
      final kosong = SourceTotal.fromNetAndFlow();
      expect(kosong.income, 0);
      expect(kosong.expense, 0);
      expect(kosong.isEmpty, isTrue);

      final minus = SourceTotal.fromNetAndFlow(net: -50000, flow: 50000);
      expect(minus.income, 0);
      expect(minus.expense, 50000);
      expect(minus.net, -50000);
    });
  });

  group('SourceTotals', () {
    const cash = FundingSource(id: 'cash', name: 'Tunai', isCash: true);
    const bank = FundingSource(id: 'bank', name: 'BCA');
    const totals = SourceTotals(
      overall: SourceTotal(income: 1000000, expense: 400000),
      bySourceId: {
        'cash': SourceTotal(sourceId: 'cash', income: 300000, expense: 100000),
        'bank': SourceTotal(sourceId: 'bank', income: 700000, expense: 250000),
        '': SourceTotal(expense: 50000),
      },
    );

    test('forSource mencari memakai id sumber', () {
      expect(totals.forSource('cash')?.net, 200000);
      expect(totals.forSource(null)?.net, -50000);
      expect(totals.forSource('tidak-ada'), isNull);
    });

    test('unknown mengambil transaksi tanpa sumber', () {
      expect(totals.unknown?.net, -50000);
    });

    test('cashNet memisahkan tunai dan non-tunai', () {
      expect(totals.cashNet(true, const [cash, bank]), 200000);
      expect(totals.cashNet(false, const [cash, bank]), 450000);
    });

    test('total keseluruhan terpisah dari jumlah per sumber', () {
      expect(totals.overall.net, 600000);
    });
  });
}
