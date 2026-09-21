import 'package:catatan_keuangan/models/funding_source.dart';
import 'package:catatan_keuangan/widgets/source_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sources = [
  FundingSource(id: 'cash', name: 'Tunai', isCash: true),
  FundingSource(id: 'bank', name: 'Rekening Bank'),
  FundingSource(id: 'wallet', name: 'E-Wallet'),
];

void main() {
  Future<void> pump(
    WidgetTester tester, {
    List<FundingSource> sources = _sources,
    String? selectedId,
    ValueChanged<FundingSource?>? onSelected,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SourcePicker(
              sources: sources,
              selectedId: selectedId,
              onSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDropdown(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
  }

  group('SourcePicker', () {
    testWidgets('tanpa sumber dana menampilkan tombol tambah', (tester) async {
      await pump(tester, sources: const [], selectedId: null);

      expect(find.text('Tambahkan sumber dana'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('menampilkan sumber terpilih sebagai nilai awal',
        (tester) async {
      await pump(tester, selectedId: 'bank');

      expect(find.text('Sumber dana'), findsOneWidget);
      expect(find.text('Rekening Bank'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tanpa sumber terpilih memakai "Belum diisi"', (tester) async {
      await pump(tester, selectedId: null);

      expect(find.text('Belum diisi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('menawarkan Belum diisi dan seluruh sumber dana',
        (tester) async {
      await pump(tester, selectedId: 'cash');
      await openDropdown(tester);

      expect(find.text('Belum diisi'), findsOneWidget);
      for (final source in _sources) {
        expect(find.text(source.name), findsWidgets,
            reason: 'sumber ${source.name} hilang dari dropdown');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('memilih sumber memanggil onSelected dengan sumber itu',
        (tester) async {
      FundingSource? received;
      await pump(
        tester,
        selectedId: 'cash',
        onSelected: (source) => received = source,
      );

      await openDropdown(tester);
      await tester.tap(find.text('E-Wallet').last);
      await tester.pumpAndSettle();

      expect(received?.id, 'wallet');
      expect(received?.name, 'E-Wallet');
      expect(received?.isCash, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('memilih Belum diisi memanggil onSelected(null)', (tester) async {
      var called = false;
      FundingSource? received;
      await pump(
        tester,
        selectedId: 'cash',
        onSelected: (source) {
          called = true;
          received = source;
        },
      );

      await openDropdown(tester);
      await tester.tap(find.text('Belum diisi').last);
      await tester.pumpAndSettle();

      // Dibedakan dari "belum pernah dipanggil" lewat flag terpisah.
      expect(called, isTrue);
      expect(received, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tombol Kelola tetap tersedia', (tester) async {
      await pump(tester, selectedId: 'cash');

      expect(find.byTooltip('Kelola sumber dana'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nama sumber panjang tidak membuat overflow', (tester) async {
      await pump(
        tester,
        sources: const [
          FundingSource(
            id: 'x',
            name: 'Rekening Bersama Keluarga Besar Sekali Panjangnya',
          ),
        ],
        selectedId: 'x',
      );

      expect(tester.takeException(), isNull);

      await openDropdown(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
