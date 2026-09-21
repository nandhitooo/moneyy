import 'package:catatan_keuangan/config/theme.dart';
import 'package:catatan_keuangan/config/theme_controller.dart';
import 'package:catatan_keuangan/widgets/home_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lebar judul "Catatan Keuangan" pada gaya `titleLarge` (22sp), diukur dengan
/// font Roboto asli. Angka ini yang menentukan berapa action yang boleh ada di
/// AppBar, jadi dipakai sebagai anggaran di test.
const double _titleWidthAt22sp = 180;

void main() {
  setUp(() => ThemeController.instance.value = ThemeMode.system);
  tearDown(() => ThemeController.instance.value = ThemeMode.system);

  Future<void> pumpBar(
    WidgetTester tester, {
    Size size = const Size(360, 640),
    VoidCallback? onOpenStats,
    VoidCallback? onRefresh,
    VoidCallback? onLogout,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance,
        builder: (context, themeMode, _) => MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: Scaffold(
            appBar: HomeAppBar(
              onOpenStats: onOpenStats ?? () {},
              onRefresh: onRefresh ?? () {},
              onLogout: onLogout ?? () {},
            ),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  Future<void> openOverflowMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Menu lainnya'));
    await tester.pumpAndSettle();
  }

  group('HomeAppBar anggaran lebar', () {
    testWidgets('ruang judul cukup di layar 360dp', (tester) async {
      await pumpBar(tester);

      // Font bawaan flutter_test menggambar setiap glyph selebar 1em, jadi
      // judul selalu lebih lebar dari ruang yang tersedia. Karena itu lebar
      // kotak judul yang terukur sama dengan ruang yang tersedia, dan bisa
      // dibandingkan dengan lebar asli judul memakai Roboto.
      final available = tester.getRect(find.text('Catatan Keuangan')).width;
      expect(available, greaterThanOrEqualTo(_titleWidthAt22sp));
      expect(tester.takeException(), isNull);
    });

    testWidgets('judul tidak tertindih action', (tester) async {
      await pumpBar(tester);

      final title = tester.getRect(find.text('Catatan Keuangan'));
      final statistik = tester.getRect(find.byTooltip('Statistik'));

      expect(title.right, lessThanOrEqualTo(statistik.left));
      expect(tester.takeException(), isNull);
    });

    testWidgets('bertambahnya action keempat akan memakan ruang judul',
        (tester) async {
      // Batas anggaran: 360 - 48 x jumlah action - 32. Test ini mendokumentasi
      // kenapa action dibatasi tiga, dengan membandingkan layar 320dp.
      await pumpBar(tester, size: const Size(320, 640));

      final available = tester.getRect(find.text('Catatan Keuangan')).width;
      expect(available, lessThan(_titleWidthAt22sp));
      // Walaupun tidak muat, judul dipotong dengan ellipsis, bukan overflow.
      expect(tester.takeException(), isNull);
    });
  });

  group('HomeAppBar aksi', () {
    testWidgets('Statistik tetap tombol langsung dan memanggil aksinya',
        (tester) async {
      var opened = 0;
      await pumpBar(tester, onOpenStats: () => opened++);

      await tester.tap(find.byTooltip('Statistik'));
      await tester.pumpAndSettle();

      expect(opened, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Muat ulang dan Keluar ada di menu overflow', (tester) async {
      await pumpBar(tester);

      // Keduanya tidak lagi tampil sebagai ikon terpisah.
      expect(find.byTooltip('Muat ulang'), findsNothing);
      expect(find.byTooltip('Keluar'), findsNothing);

      await openOverflowMenu(tester);

      expect(find.text('Muat ulang'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('menu overflow memanggil aksi Muat ulang', (tester) async {
      var refreshed = 0;
      var loggedOut = 0;
      await pumpBar(tester, onRefresh: () => refreshed++, onLogout: () => loggedOut++);

      await openOverflowMenu(tester);
      await tester.tap(find.text('Muat ulang'));
      await tester.pumpAndSettle();

      expect(refreshed, 1);
      expect(loggedOut, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('menu overflow memanggil aksi Keluar', (tester) async {
      var refreshed = 0;
      var loggedOut = 0;
      await pumpBar(tester, onRefresh: () => refreshed++, onLogout: () => loggedOut++);

      await openOverflowMenu(tester);
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      expect(loggedOut, 1);
      expect(refreshed, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('HomeAppBar tombol tema', () {
    testWidgets('mengganti themeMode aplikasi', (tester) async {
      await pumpBar(tester);

      // Awalnya mengikuti sistem yang sedang terang, jadi tombolnya menawarkan
      // pindah ke tema gelap.
      expect(ThemeController.instance.value, ThemeMode.system);
      expect(find.byTooltip('Ganti ke tema gelap'), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.dark_mode_outlined));
      await tester.pumpAndSettle();

      expect(ThemeController.instance.value, ThemeMode.dark);
      expect(find.byTooltip('Ganti ke tema terang'), findsOneWidget);
      expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.light_mode_outlined));
      await tester.pumpAndSettle();

      // Ditekan sekali lagi berarti pilihan eksplisit terang, bukan kembali ke
      // mode sistem.
      expect(ThemeController.instance.value, ThemeMode.light);
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
