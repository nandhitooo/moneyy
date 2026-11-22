import 'package:material_ui/material_ui.dart';

import '../models/funding_source.dart';
import '../models/source_breakdown.dart';
import '../models/transaction_model.dart';
import '../utils/helpers.dart';

/// Label chip untuk "semua kategori".
const allCategoriesLabel = 'Semua';

/// Nilai filter untuk transaksi yang belum punya sumber dana.
const unknownSourceFilterId = '__unknown__';

/// Kolom pencarian judul/catatan/kategori, dengan tombol pembuka filter.
///
/// Pencarian dan filter dulu tampil sebagai tiga baris terpisah (kolom cari,
/// chip kategori, chip sumber) yang selalu memakan ruang. Sekarang filter cukup
/// satu tombol di samping kolom cari; pilihannya ada di bottom sheet.
class TransactionSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Bila diisi, tombol filter tampil di kanan kolom pencarian.
  final VoidCallback? onOpenFilters;

  /// Jumlah filter aktif, ditampilkan sebagai badge pada tombol filter.
  final int activeFilterCount;

  const TransactionSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onOpenFilters,
    this.activeFilterCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari transaksi...',
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
          ),
          if (onOpenFilters != null) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Filter',
              onPressed: onOpenFilters,
              icon: Badge(
                isLabelVisible: activeFilterCount > 0,
                label: Text('$activeFilterCount'),
                child: const Icon(Icons.tune, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ringkasan filter yang sedang aktif.
///
/// Tidak mengambil ruang sama sekali saat tidak ada filter, jadi layar home
/// terasa lapang sampai pengguna benar-benar menyaring sesuatu.
class ActiveTransactionFilters extends StatelessWidget {
  final String? category;
  final String? sourceId;
  final List<FundingSource> sources;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String?> onSource;
  final VoidCallback onReset;

  const ActiveTransactionFilters({
    super.key,
    required this.category,
    required this.sourceId,
    required this.sources,
    required this.onCategory,
    required this.onSource,
    required this.onReset,
  });

  String? get _sourceName {
    final id = sourceId;
    if (id == null) return null;
    if (id == unknownSourceFilterId) return unknownSourceLabel;
    return sources.where((s) => s.id == id).firstOrNull?.name;
  }

  @override
  Widget build(BuildContext context) {
    final sourceName = _sourceName;
    if (category == null && sourceName == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (category != null)
                  InputChip(
                    label: Text(category!),
                    deleteButtonTooltipMessage: 'Hapus filter kategori',
                    onDeleted: () => onCategory(null),
                  ),
                if (sourceName != null)
                  InputChip(
                    label: Text(sourceName),
                    deleteButtonTooltipMessage: 'Hapus filter sumber dana',
                    onDeleted: () => onSource(null),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onReset,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

/// Isi bottom sheet filter: kategori dan sumber dana.
///
/// Pilihannya langsung diterapkan ke layar di belakangnya, jadi pengguna tidak
/// perlu menekan tombol "Terapkan".
class TransactionFilterSheet extends StatefulWidget {
  final String? category;
  final String? sourceId;
  final Set<String> usedCategories;
  final List<FundingSource> sources;
  final bool hasUnknown;
  final void Function(String? category, String? sourceId) onChanged;

  const TransactionFilterSheet({
    super.key,
    required this.category,
    required this.sourceId,
    required this.usedCategories,
    required this.sources,
    required this.hasUnknown,
    required this.onChanged,
  });

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late String? _category = widget.category;
  late String? _sourceId = widget.sourceId;

  bool get _hasFilter => _category != null || _sourceId != null;

  void _apply() => widget.onChanged(_category, _sourceId);

  void _reset() {
    setState(() {
      _category = null;
      _sourceId = null;
    });
    _apply();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('Filter', style: theme.textTheme.titleMedium),
                ),
                if (_hasFilter)
                  TextButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
          ),
          const _FilterLabel('Kategori'),
          SizedBox(
            height: 44,
            child: CategoryFilterBar(
              selected: _category,
              usedCategories: widget.usedCategories,
              onSelected: (category) {
                setState(() => _category = category);
                _apply();
              },
            ),
          ),
          const SizedBox(height: 8),
          const _FilterLabel('Sumber dana'),
          SizedBox(
            height: 44,
            child: SourceFilterBar(
              selectedId: _sourceId,
              sources: widget.sources,
              hasUnknown: widget.hasUnknown,
              onSelected: (sourceId) {
                setState(() => _sourceId = sourceId);
                _apply();
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String text;

  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
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
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: const Text('Semua sumber'),
            selected: selectedId == null,
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
                  Icon(sourceIcon(source), size: 16),
                  const SizedBox(width: 4),
                  Text(source.name),
                ],
              ),
              selected: selectedId == source.id,
              onSelected: (_) => onSelected(source.id),
            ),
          ),
        if (hasUnknown)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text(unknownSourceLabel),
              selected: selectedId == unknownSourceFilterId,
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
                  Icon(categoryIcon(category), size: 16),
                  const SizedBox(width: 4),
                ],
                Text(category),
              ],
            ),
            selected: isSelected,
            onSelected: (_) => onSelected(isAll ? null : category),
          ),
        );
      },
    );
  }
}
