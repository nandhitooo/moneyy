import 'package:flutter/material.dart';

import '../models/funding_source.dart';
import '../models/source_breakdown.dart';
import '../models/transaction_model.dart';
import '../utils/helpers.dart';

/// Label chip untuk "semua kategori".
const allCategoriesLabel = 'Semua';

/// Nilai filter untuk transaksi yang belum punya sumber dana.
const unknownSourceFilterId = '__unknown__';

/// Kolom pencarian judul/catatan/kategori.
class TransactionSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const TransactionSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari judul, catatan, atau kategori...',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          suffixIcon: ListenableBuilder(
            listenable: controller,
            builder: (_, __) => controller.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Bersihkan pencarian',
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: controller.clear,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Baris chip sumber dana: tunai, rekening bank, e-wallet, dan lainnya.
class SourceFilterBar extends StatelessWidget {
  final String? selectedId;
  final List<FundingSource> sources;

  /// Tampilkan chip "Belum diisi" bila ada transaksi tanpa sumber dana.
  final bool hasUnknown;
  final ValueChanged<String?> onSelected;

  const SourceFilterBar({
    super.key,
    required this.selectedId,
    required this.sources,
    this.hasUnknown = false,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: const Text('Semua sumber'),
            selected: selectedId == null,
            selectedColor: cs.secondaryContainer,
            onSelected: (_) => onSelected(null),
          ),
        ),
        for (final source in sources)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sourceIcon(source),
                    size: 16,
                    color: selectedId == source.id
                        ? cs.onSecondaryContainer
                        : null,
                  ),
                  const SizedBox(width: 4),
                  Text(source.name),
                ],
              ),
              selected: selectedId == source.id,
              selectedColor: cs.secondaryContainer,
              onSelected: (_) => onSelected(source.id),
            ),
          ),
        if (hasUnknown)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text(unknownSourceLabel),
              selected: selectedId == unknownSourceFilterId,
              selectedColor: cs.secondaryContainer,
              onSelected: (_) => onSelected(unknownSourceFilterId),
            ),
          ),
      ],
    );
  }
}

/// Baris chip kategori. Hanya kategori yang muncul di bulan aktif yang tampil.
class CategoryFilterBar extends StatelessWidget {
  final String? selected;
  final Set<String> usedCategories;
  final ValueChanged<String?> onSelected;

  const CategoryFilterBar({
    super.key,
    required this.selected,
    required this.usedCategories,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final categories = <String>[
      allCategoriesLabel,
      ...expenseCategories.where(usedCategories.contains),
      ...incomeCategories.where(usedCategories.contains),
    ];

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final category = categories[i];
        final isAll = category == allCategoriesLabel;
        final isSelected = isAll ? selected == null : selected == category;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isAll) ...[
                  Icon(
                    categoryIcon(category),
                    size: 16,
                    color: isSelected ? cs.onSecondaryContainer : null,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(category),
              ],
            ),
            selected: isSelected,
            selectedColor: cs.secondaryContainer,
            onSelected: (_) => onSelected(isAll ? null : category),
          ),
        );
      },
    );
  }
}
