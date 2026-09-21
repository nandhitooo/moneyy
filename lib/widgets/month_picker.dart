import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Nama bulan Indonesia, dihitung sekali saat pertama kali dibutuhkan.
///
/// Locale `id_ID` sudah diinisialisasi di `main()` lewat
/// `initializeDateFormatting`, jadi daftar ini tidak boleh dihitung lebih awal.
final List<String> monthNames = List.generate(
  12,
  (i) => DateFormat.MMMM('id_ID').format(DateTime(2026, i + 1)),
);

/// Membuka pemilih bulan dan mengembalikan bulan yang dipilih.
///
/// Mengembalikan `null` bila pengguna menekan **Batal**. Dipakai
/// [MonthSelector] supaya bisa melompat ke bulan mana pun tanpa menekan tombol
/// maju/mundur berulang kali.
Future<DateTime?> showMonthPicker(
  BuildContext context, {
  required DateTime initial,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _MonthPickerDialog(initial: initial),
  );
}

/// Dialog pemilih bulan: navigasi tahun di atas, lalu 12 bulan dalam 4 baris.
class _MonthPickerDialog extends StatefulWidget {
  final DateTime initial;

  const _MonthPickerDialog({required this.initial});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
  }

  void _changeYear(int delta) => setState(() => _year += delta);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Pilih bulan'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Tahun sebelumnya',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeYear(-1),
                ),
                Expanded(
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Tahun berikutnya',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeYear(1),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (var row = 0; row < 4; row++)
              Row(
                children: [
                  for (var col = 0; col < 3; col++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: _MonthButton(
                          label: monthNames[row * 3 + col],
                          selected: widget.initial.year == _year &&
                              widget.initial.month == row * 3 + col + 1,
                          onPressed: () => Navigator.pop(
                            context,
                            DateTime(_year, row * 3 + col + 1),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () {
            final now = DateTime.now();
            Navigator.pop(context, DateTime(now.year, now.month));
          },
          child: const Text('Bulan ini'),
        ),
      ],
    );
  }
}

/// Satu tombol bulan.
///
/// Labelnya memakai [FittedBox] supaya nama terpanjang ("September") tidak
/// pernah membuat baris melaporkan overflow saat kolomnya sempit.
class _MonthButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _MonthButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 44,
      child: Material(
        color: selected ? cs.secondaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? cs.onSecondaryContainer : cs.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
