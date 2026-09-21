import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../utils/helpers.dart';

/// Pemilih kategori berupa dropdown.
///
/// Daftar kategorinya mengikuti [type]: pemasukan dan pengeluaran punya
/// daftar berbeda.
class CategoryPicker extends StatelessWidget {
  final TxType type;

  /// Kategori yang sedang terpilih.
  final String selected;
  final ValueChanged<String> onSelected;

  const CategoryPicker({
    super.key,
    required this.type,
    required this.selected,
    required this.onSelected,
  });

  List<String> get _categories =>
      type == TxType.expense ? expenseCategories : incomeCategories;

  /// Pilihan yang ditampilkan, selalu memuat [selected].
  ///
  /// Transaksi lama bisa menyimpan kategori di luar daftar tipe aktifnya;
  /// tanpa ini `DropdownButtonFormField` gagal karena nilai awalnya tidak ada
  /// di daftar item.
  List<String> get options {
    final list = List<String>.of(_categories);
    if (!list.contains(selected)) list.insert(0, selected);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selected,
      // Supaya nama kategori panjang tidak melebarkan tombolnya.
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Kategori',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: [
        for (final category in options)
          DropdownMenuItem(
            value: category,
            child: Row(
              children: [
                Icon(categoryIcon(category), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: (value) {
        if (value == null) return;
        onSelected(value);
      },
    );
  }
}
