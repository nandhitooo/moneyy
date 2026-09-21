import 'package:catatan_keuangan/widgets/month_picker.dart';
import 'package:catatan_keuangan/widgets/month_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

DateTime? _picked;
bool _opened = false;

void main() {
  setUpAll(() async {
    // Sama seperti `main()`: nama bulan `id_ID` baru tersedia setelah ini.
    await initializeDateFormatting('id_ID');
  });

  setUp(() {
    _picked = null;
    _opened = false;
  });

  /// Membuka pemilih bulan lewat `showMonthPicker`, seperti home screen.
  Future<void> openPicker(WidgetTester tester, DateTime initial) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  _opened = true;
                  _picked = await showMonthPicker(context, initial: initial);
                },
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(_opened, isTrue);
  }

  group('showMonthPicker', () {
    testWidgets('menampilkan tahun awal dan dua belas bulan', (tester) async {
      await openPicker(tester, DateTime(2026, 9));

      expect(find.text('Pilih bulan'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      for (final name in monthNames) {
        expect(find.text(name), findsOneWidget, reason: 'bulan $name hilang');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('memilih bulan mengembalikan bulan di tahun aktif',
        (tester) async {
      await openPicker(tester, DateTime(2026, 9));

      await tester.tap(find.text('Maret'));
      await tester.pumpAndSettle();

      expect(_picked, DateTime(2026, 3));
    });

    testWidgets('tombol tahun mengubah daftar bulan ke tahun lain',
        (tester) async {
      await openPicker(tester, DateTime(2026, 9));

      await tester.tap(find.byTooltip('Tahun berikutnya'));
      await tester.pumpAndSettle();

      expect(find.text('2027'), findsOneWidget);
      expect(find.text('2026'), findsNothing);

      await tester.tap(find.text('Januari'));
      await tester.pumpAndSettle();

      expect(_picked, DateTime(2027, 1));
    });

    testWidgets('tahun mundur juga bekerja', (tester) async {
      await openPicker(tester, DateTime(2026, 9));

      await tester.tap(find.byTooltip('Tahun sebelumnya'));
      await tester.tap(find.byTooltip('Tahun sebelumnya'));
      await tester.pumpAndSettle();

      expect(find.text('2024'), findsOneWidget);

      await tester.tap(find.text('Desember'));
      await tester.pumpAndSettle();

      expect(_picked, DateTime(2024, 12));
    });

    testWidgets('Batal mengembalikan null', (tester) async {
      await openPicker(tester, DateTime(2026, 9));

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(_picked, isNull);
    });

    testWidgets('Bulan ini mengembalikan bulan berjalan', (tester) async {
      await openPicker(tester, DateTime(2020, 1));

      await tester.tap(find.text('Bulan ini'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      expect(_picked, DateTime(now.year, now.month));
    });

    testWidgets('tidak overflow di dialog sempit', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);

      // Nama bulan terpanjang adalah "September"; font bawaan test jauh lebih
      // lebar dari Roboto, jadi ini sekaligus menguji pemotongan labelnya.
      await openPicker(tester, DateTime(2026, 9));

      expect(find.text('September'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('MonthSelector', () {
    testWidgets('label bulan bisa diketuk saat onTap diisi', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthSelector(
              month: DateTime(2026, 9),
              onPrevious: () {},
              onNext: () {},
              onTap: () => taps++,
            ),
          ),
        ),
      );

      expect(find.text('September 2026'), findsOneWidget);
      expect(find.byTooltip('Ketuk untuk pilih bulan'), findsOneWidget);

      await tester.tap(find.text('September 2026'));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tanpa onTap label tidak memasang tooltip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthSelector(
              month: DateTime(2026, 9),
              onPrevious: () {},
              onNext: () {},
            ),
          ),
        ),
      );

      expect(find.byTooltip('Ketuk untuk pilih bulan'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('melompat jauh dalam tiga ketukan', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _Host()));

      expect(find.text('September 2026'), findsOneWidget);

      // Buka pemilih, mundur dua tahun, pilih Januari.
      await tester.tap(find.text('September 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tahun sebelumnya'));
      await tester.tap(find.byTooltip('Tahun sebelumnya'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Januari'));
      await tester.pumpAndSettle();

      expect(find.text('Januari 2024'), findsOneWidget);
      expect(find.text('aktif 2024-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tombol maju/mundur satu bulan tetap bekerja', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _Host()));

      await tester.tap(find.byTooltip('Bulan berikutnya'));
      await tester.pumpAndSettle();
      expect(find.text('aktif 2026-10'), findsOneWidget);

      await tester.tap(find.byTooltip('Bulan sebelumnya'));
      await tester.tap(find.byTooltip('Bulan sebelumnya'));
      await tester.pumpAndSettle();
      expect(find.text('aktif 2026-8'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Meniru home screen: label bulan membuka pemilih bulan dan hasilnya
/// menggantikan bulan aktif. Dipakai agar alur `_pickMonth` ikut teruji tanpa
/// perlu Firebase.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  DateTime month = DateTime(2026, 9);

  Future<void> _pick() async {
    final picked = await showMonthPicker(context, initial: month);
    if (picked == null) return;
    if (picked.year == month.year && picked.month == month.month) return;
    setState(() => month = DateTime(picked.year, picked.month));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          MonthSelector(
            month: month,
            onPrevious: () =>
                setState(() => month = DateTime(month.year, month.month - 1)),
            onNext: () =>
                setState(() => month = DateTime(month.year, month.month + 1)),
            onTap: _pick,
          ),
          Text('aktif ${month.year}-${month.month}'),
        ],
      ),
    );
  }
}
