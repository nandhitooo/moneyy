import 'package:flutter/material.dart';

import '../utils/helpers.dart';

/// Pemilih bulan dengan tombol maju/mundur.
///
/// Bila [onTap] diisi, label bulannya bisa diketuk untuk membuka pemilih bulan
/// (lihat `showMonthPicker`), sehingga tidak perlu menekan tombol maju/mundur
/// berulang kali untuk melompat jauh.
class MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onTap;

  const MonthSelector({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget label = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Chip(
        side: BorderSide.none,
        backgroundColor: cs.secondaryContainer,
        label: SizedBox(
          width: 150,
          child: Text(
            monthFmt.format(month),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    // Tooltip hanya dipasang saat label memang bisa diketuk, supaya tidak ada
    // tooltip kosong yang muncul tanpa pesan.
    if (onTap != null) {
      label = Tooltip(message: 'Ketuk untuk pilih bulan', child: label);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Bulan sebelumnya',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Semantics(
            label: 'Bulan aktif ${monthFmt.format(month)}',
            button: true,
            child: label,
          ),
          IconButton(
            tooltip: 'Bulan berikutnya',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
