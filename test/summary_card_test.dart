import 'package:catatan_keuangan/models/funding_source.dart';
import 'package:catatan_keuangan/models/month_summary.dart';
import 'package:catatan_keuangan/models/source_breakdown.dart';
import 'package:catatan_keuangan/widgets/summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _summary = MonthSummary(
  income: 12500000,
  expense: 4500000,
  carry: 3000000,
);

const _sources = [
  FundingSource(id: 'cash', name: 'Tunai', isCash: true),
  FundingSource(id: 'bank', name: 'Rekening Bank'),
  FundingSource(id: 'wallet', name: 'E-Wallet'),
];

const _totals = SourceTotals(
  overall: SourceTotal(income: 12500000, expense: 4500000),
  bySourceId: {
    'cash': SourceTotal(sourceId: 'cash', income: 2500000, expense: 1000000),
    'bank': SourceTotal(sourceId: 'bank', income: 10000000, expense: 2000000),
    'wallet': SourceTotal(sourceId: 'wallet', income: 0, expense: 1500000),
  },
);

SummaryCard _card({
  List<FundingSource> sources = _sources,
  SourceTotals? totals = _totals,
  bool failed = false,
}) =>
    SummaryCard(
      summary: _summary,
      sources: sources,
      sourceTotals: totals,
      sourceBalancesFailed: failed,
      sourceBalancesError: failed ? 'failed-precondition: the query requires an index' : null,
      onManageSources: () {},
      onRetrySourceBalances: () {},
    );

/// Menyiapkan lebar layar dan mengembalikan ukurannya seperti perangkat nyata.
Future<void> _setScreen(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

double _dy(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  group('SummaryCard tata letak dua bagian', () {
    testWidgets('statistik dan rincian saldo berdampingan di layar 360dp',
        (tester) async {
      await _setScreen(tester, const Size(360, 640));
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ListView(children: [_card()]))),
      );

      expect(find.text('Saldo bulan ini'), findsOneWidget);
      expect(find.text('Dari bulan lalu'), findsOneWidget);
      expect(find.text('Saldo per sumber'), findsOneWidget);
      expect(find.text('Tunai'), findsOneWidget);
      expect(find.text('Rekening Bank'), findsOneWidget);
      expect(find.text('E-Wallet'), findsOneWidget);

      // Berdampingan: keduanya mulai di pita vertikal yang sama.
      expect((_dy(tester, 'Dari bulan lalu') - _dy(tester, 'Saldo per sumber')).abs(),
          lessThan(24));
      expect(tester.takeException(), isNull);
    });

    testWidgets('kembali ditumpuk saat kolom terlalu sempit', (tester) async {
      await _setScreen(tester, const Size(280, 640));
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ListView(children: [_card()]))),
      );

      expect(_dy(tester, 'Saldo per sumber') - _dy(tester, 'Dari bulan lalu'),
          greaterThan(100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tanpa sumber dana hanya statistik yang tampil',
        (tester) async {
      await _setScreen(tester, const Size(360, 640));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [_card(sources: const [], totals: null)],
            ),
          ),
        ),
      );

      expect(find.text('Dari bulan lalu'), findsOneWidget);
      expect(find.text('Saldo per sumber'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('SummaryCard tinggi dan overflow', () {
    testWidgets('tinggi kartu tetap di bawah anggaran', (tester) async {
      await _setScreen(tester, const Size(360, 640));
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ListView(children: [_card()]))),
      );

      // Sebelum statistik dan rincian saldo dipisah, kartu setinggi ~400dp dan
      // membuat body home (MonthSelector + kartu + search + 2 filter bar)
      // melampaui layar. Anggaran ini menjaga perbaikan itu tidak hilang lagi.
      expect(tester.getSize(find.byType(SummaryCard)).height, lessThan(300));
    });

    testWidgets('tidak overflow di layar pendek', (tester) async {
      await _setScreen(tester, const Size(360, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            // Meniru body home_screen: anak berukuran tetap lalu Expanded.
            body: Column(
              children: [
                const SizedBox(height: 64), // MonthSelector
                _card(),
                const SizedBox(height: 8),
                const SizedBox(height: 56), // kolom pencarian
                const SizedBox(height: 44), // filter kategori
                const SizedBox(height: 44), // filter sumber dana
                const Expanded(child: SizedBox.expand()),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('rincian sumber dibatasi empat baris', (tester) async {
      await _setScreen(tester, const Size(360, 640));
      const banyak = [
        FundingSource(id: 'a', name: 'Tunai', isCash: true),
        FundingSource(id: 'b', name: 'Rekening Bank'),
        FundingSource(id: 'c', name: 'E-Wallet'),
        FundingSource(id: 'd', name: 'DANA'),
        FundingSource(id: 'e', name: 'OVO'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [_card(sources: banyak, totals: null)],
            ),
          ),
        ),
      );

      expect(find.text('DANA'), findsOneWidget);
      expect(find.text('OVO'), findsNothing);
      expect(find.text('+1 lagi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kegagalan agregasi tampil tanpa overflow', (tester) async {
      await _setScreen(tester, const Size(360, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ListView(children: [_card(failed: true)])),
        ),
      );

      expect(find.text('Gagal memuat saldo per sumber.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
