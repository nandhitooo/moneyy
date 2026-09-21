import 'package:catatan_keuangan/models/transaction_model.dart';
import 'package:catatan_keuangan/widgets/category_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required TxType type,
    required String selected,
    ValueChanged<String>? onSelected,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CategoryPicker(
              type: type,
              selected: selected,
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

  group('CategoryPicker', () {
    testWidgets('menampilkan kategori terpilih sebagai nilai awal',
        (tester) async {
      await pump(tester, type: TxType.expense, selected: 'Makanan');

      expect(find.text('Kategori'), findsOneWidget);
      expect(find.text('Makanan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pengeluaran menawarkan seluruh kategori pengeluaran',
        (tester) async {
      await pump(tester, type: TxType.expense, selected: 'Makanan');
      await openDropdown(tester);

      for (final category in expenseCategories) {
        expect(find.text(category), findsWidgets,
            reason: 'kategori $category hilang dari dropdown');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('pemasukan memakai daftar kategorinya sendiri', (tester) async {
      await pump(tester, type: TxType.income, selected: 'Gaji');
      await openDropdown(tester);

      expect(find.text('Gaji'), findsWidgets);
      expect(find.text('Bonus'), findsWidgets);
      expect(find.text('Makanan'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('memilih kategori memanggil onSelected', (tester) async {
      String? picked;
      await pump(
        tester,
        type: TxType.expense,
        selected: 'Makanan',
        onSelected: (category) => picked = category,
      );

      await openDropdown(tester);
      await tester.tap(find.text('Transportasi').last);
      await tester.pumpAndSettle();

      expect(picked, 'Transportasi');
      expect(tester.takeException(), isNull);
    });

    testWidgets('kategori di luar daftar tipe tetap bisa ditampilkan',
        (tester) async {
      // Data lama bisa menyimpan kategori pemasukan pada transaksi pengeluaran.
      // Tanpa penyisipan, DropdownButtonFormField gagal karena nilai awalnya
      // tidak ada di daftar item.
      await pump(tester, type: TxType.expense, selected: 'Gaji');

      expect(find.text('Gaji'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await openDropdown(tester);
      expect(find.text('Gaji'), findsWidgets);
      expect(find.text('Makanan'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ganti tipe memperbarui daftar dan nilai terpilih',
        (tester) async {
      // [0] kategori terpilih, [1] kategori yang dipakai saat tipe berganti.
      final selected = <String>['Makanan', 'Gaji'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    CategoryPicker(
                      type: selected.first == 'Makanan'
                          ? TxType.expense
                          : TxType.income,
                      selected: selected.first,
                      onSelected: (c) => setState(() => selected[0] = c),
                    ),
                    TextButton(
                      onPressed: () => setState(() => selected[0] = selected[1]),
                      child: const Text('ganti tipe'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Makanan'), findsOneWidget);

      await tester.tap(find.text('ganti tipe'));
      await tester.pumpAndSettle();

      // Nilai terpilih harus ikut berubah, bukan tertinggal di kategori lama.
      expect(find.text('Gaji'), findsOneWidget);
      expect(find.text('Makanan'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
