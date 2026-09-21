import 'package:flutter/material.dart';

import '../models/funding_source.dart';
import '../models/source_breakdown.dart';
import '../screens/sources_screen.dart';
import '../utils/helpers.dart';

/// Pemilih sumber dana berupa dropdown.
///
/// Pilihan **Belum diisi** selalu ditawarkan supaya transaksi lama yang belum
/// punya sumber dana bisa dikosongkan lagi. Bila daftar sumber dana kosong,
/// yang tampil tombol untuk mengisi sumber dana bawaan.
class SourcePicker extends StatelessWidget {
  final List<FundingSource> sources;

  /// Id sumber terpilih, `null` bila transaksi belum punya sumber dana.
  final String? selectedId;

  /// Dipanggil dengan sumber yang dipilih, atau `null` untuk **Belum diisi**.
  final ValueChanged<FundingSource?> onSelected;

  /// Penanda pilihan "Belum diisi".
  ///
  /// Memakai string kosong karena id dokumen Firestore tidak pernah kosong,
  /// sedangkan `DropdownButtonFormField` tidak menerima item bernilai `null`.
  static const noSourceId = '';

  const SourcePicker({
    super.key,
    required this.sources,
    required this.selectedId,
    required this.onSelected,
  });

  Future<void> _openManager(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SourcesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return OutlinedButton.icon(
        onPressed: () => _openManager(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambahkan sumber dana'),
      );
    }

    final selected = sources.where((s) => s.id == selectedId).firstOrNull;

    return DropdownButtonFormField<String>(
      initialValue: selectedId ?? noSourceId,
      // Supaya nama sumber yang panjang tidak melebarkan tombolnya.
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Sumber dana',
        prefixIcon: Icon(
          selected == null ? Icons.help_outline : sourceIcon(selected),
        ),
        suffixIcon: IconButton(
          tooltip: 'Kelola sumber dana',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => _openManager(context),
        ),
      ),
      items: [
        const DropdownMenuItem(
          value: noSourceId,
          child: Text(unknownSourceLabel),
        ),
        for (final source in sources)
          if (source.id != null)
            DropdownMenuItem(
              value: source.id,
              child: Row(
                children: [
                  Icon(sourceIcon(source), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      source.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
      ],
      onChanged: (id) {
        if (id == null) return;
        if (id == noSourceId) {
          onSelected(null);
          return;
        }
        onSelected(sources.firstWhere((s) => s.id == id));
      },
    );
  }
}
