import 'package:catatan_keuangan/widgets/status_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layar home menaruh header (kartu ringkasan, pencarian, filter) dan isi
/// kosong dalam satu `CustomScrollView`, memakai
/// `SliverFillRemaining(hasScrollBody: false)`.
///
/// Sliver itu mengukur tinggi anaknya lewat intrinsic sizing
/// (`extent = max(sisa ruang, childExtent)`), jadi empty state yang lebih
/// tinggi dari ruang sisa akan tumbuh. Test ini menjaga syaratnya: seluruh isi
/// empty state harus tetap mendukung intrinsic, dan tidak boleh overflow walau
/// header sudah menghabiskan layar.
void main() {
  Future<void> pumpScroll(WidgetTester tester, {
    required double headerHeight,
    required Widget empty,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: headerHeight,
                  child: const ColoredBox(color: Colors.amber),
                ),
              ),
              SliverFillRemaining(hasScrollBody: false, child: empty),
            ],
          ),
        ),
      ),
    );
  }

  Widget emptyState() => EmptyStateView(
        title: 'Belum ada transaksi bulan ini',
        message: 'Tekan tombol di bawah untuk mencatat pemasukan '
            'atau pengeluaran.',
        actionLabel: 'Tambah transaksi',
        onAction: () {},
      );

  group('header home yang menggulir', () {
    testWidgets('isi kosong memakai sisa ruang saat header pendek',
        (tester) async {
      await pumpScroll(tester, headerHeight: 100, empty: emptyState());

      expect(find.text('Belum ada transaksi bulan ini'), findsOneWidget);
      expect(find.text('Tambah transaksi'), findsOneWidget);

      // Sisa ruang (500dp) lebih besar dari tinggi isi, jadi isi mengisi penuh
      // layar dan tombolnya berada di dalam viewport.
      final button = tester.getRect(find.text('Tambah transaksi'));
      expect(button.bottom, lessThanOrEqualTo(600));
      expect(tester.takeException(), isNull);
    });

    testWidgets('isi kosong tumbuh, bukan overflow, saat sisa ruang kurang',
        (tester) async {
      // Sisa ruang cuma 120dp, sedangkan isi butuh lebih dari itu.
      await pumpScroll(tester, headerHeight: 480, empty: emptyState());

      expect(tester.takeException(), isNull);

      // Karena tumbuh melewati layar, isinya harus bisa digulir sampai terlihat.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('Tambah transaksi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('isi kosong tetap aman saat header melebihi layar',
        (tester) async {
      await pumpScroll(tester, headerHeight: 700, empty: emptyState());

      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada transaksi bulan ini'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('NoResultView juga aman di sliver yang sama', (tester) async {
      await pumpScroll(
        tester,
        headerHeight: 480,
        empty: NoResultView(onReset: () {}),
      );

      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('Tidak ada hasil'), findsOneWidget);
      expect(find.text('Reset filter'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
