import 'package:flutter/material.dart';

import '../models/funding_source.dart';
import '../models/month_summary.dart';
import '../models/source_breakdown.dart';
import '../utils/helpers.dart';

/// Kartu saldo bulan ini.
///
/// Isinya dibagi dua bagian berdampingan supaya kartu tetap pendek: statistik
/// bulan (kiri) dan rincian saldo tiap sumber dana (kanan). Sebelumnya keduanya
/// ditumpuk ke bawah sehingga kartu bisa melebihi tinggi layar dan memicu
/// "bottom overflowed". Pada lebar yang sangat sempit keduanya kembali
/// ditumpuk.
class SummaryCard extends StatelessWidget {
  final MonthSummary summary;

  /// Saldo tiap sumber dana (sepanjang waktu). Boleh null bila tidak dipakai.
  final SourceTotals? sourceTotals;
  final List<FundingSource> sources;
  final bool sourceBalancesLoading;
  final bool sourceBalancesFailed;

  /// Pesan teknis saat saldo per sumber gagal dimuat, ditampilkan kecil agar
  /// bisa disalin saat melapor.
  final String? sourceBalancesError;
  final VoidCallback? onRetrySourceBalances;
  final VoidCallback? onManageSources;

  /// Di bawah lebar konten ini dua bagian ditumpuk lagi karena kolomnya
  /// terlalu sempit untuk angka rupiah.
  ///
  /// Diukur dari lebar konten, bukan lebar layar: di layar 360dp kartu ini
  /// kehilangan 32dp margin dan 32dp padding sehingga hanya tersisa 296dp.
  static const _twoColumnMinWidth = 240;

  const SummaryCard({
    super.key,
    required this.summary,
    this.sourceTotals,
    this.sources = const [],
    this.sourceBalancesLoading = false,
    this.sourceBalancesFailed = false,
    this.sourceBalancesError,
    this.onRetrySourceBalances,
    this.onManageSources,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final stats = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MiniStat(
          icon: Icons.savings,
          label: 'Dari bulan lalu',
          value: rupiah.format(summary.carry),
          color: cs.onPrimaryContainer,
          tooltip: 'Sisa saldo dari bulan-bulan sebelumnya '
              'yang otomatis dibawa ke bulan ini.',
        ),
        const SizedBox(height: 12),
        MiniStat(
          icon: Icons.arrow_downward,
          label: 'Pemasukan',
          value: rupiah.format(summary.income),
          color: incomeColor(context),
          tooltip: 'Total uang masuk selama bulan ini.',
        ),
        const SizedBox(height: 12),
        MiniStat(
          icon: Icons.arrow_upward,
          label: 'Pengeluaran',
          value: rupiah.format(summary.expense),
          color: expenseColor(context),
          tooltip: 'Total uang keluar selama bulan ini.',
        ),
      ],
    );

    final hasBalances = sources.isNotEmpty || sourceBalancesFailed;
    final balances = hasBalances
        ? _SourceBalances(
            totals: sourceTotals,
            sources: sources,
            loading: sourceBalancesLoading,
            failed: sourceBalancesFailed,
            error: sourceBalancesError,
            onRetry: onRetrySourceBalances,
            onManage: onManageSources,
          )
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Saldo bulan ini', style: TextStyle(color: cs.onPrimaryContainer)),
            const SizedBox(height: 4),
            Semantics(
              label: 'Saldo bulan ini ${rupiah.format(summary.balance)}',
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  rupiah.format(summary.balance),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (balances == null) return stats;

                if (constraints.maxWidth < _twoColumnMinWidth) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      stats,
                      const SizedBox(height: 16),
                      _sectionDivider(cs),
                      const SizedBox(height: 12),
                      balances,
                    ],
                  );
                }

                // Tanpa IntrinsicHeight: memaksa tinggi sama membuat header
                // bagian kanan ikut teregang, baris saldo terdorong ke bawah,
                // dan kartu jadi lebih tinggi dari sebelumnya. Kedua bagian
                // disejajarkan dari atas dan pemisahnya dibuat dengan border
                // yang tidak butuh tinggi pasti.
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: stats),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: cs.onPrimaryContainer.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: balances,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionDivider(ColorScheme cs) => Divider(
        height: 1,
        color: cs.onPrimaryContainer.withValues(alpha: 0.2),
      );
}

/// Rincian saldo tiap sumber dana dalam satu kolom.
class _SourceBalances extends StatelessWidget {
  final SourceTotals? totals;
  final List<FundingSource> sources;
  final bool loading;
  final bool failed;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onManage;

  /// Maksimal baris yang tampil supaya kartu tidak memanjang ke bawah.
  static const _maxRows = 4;

  const _SourceBalances({
    required this.totals,
    required this.sources,
    required this.loading,
    required this.failed,
    this.error,
    this.onRetry,
    this.onManage,
  });

  /// Tombol teks sekecil mungkin.
  ///
  /// Padding bawaan `TextButton` Material 3 membuat tombol ini selebar ~85dp,
  /// dan di tata letak dua kolom itu menghabiskan hampir seluruh lebar bagian
  /// kanan sampai labelnya terpotong jadi banyak baris.
  ButtonStyle _tightButton(ColorScheme cs) => TextButton.styleFrom(
        foregroundColor: cs.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 11),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final header = Row(
      children: [
        Expanded(
          child: Text(
            'Saldo per sumber',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (onManage != null)
          TextButton(
            onPressed: onManage,
            style: _tightButton(cs),
            child: const Text('Kelola'),
          ),
      ],
    );

    if (failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Text(
            'Gagal memuat saldo per sumber.',
            style: TextStyle(color: cs.onPrimaryContainer),
          ),
          if (onRetry != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onRetry,
                style: _tightButton(cs),
                child: const Text('Coba lagi'),
              ),
            ),
          if (error != null)
            SelectableText(
              error!,
              style: TextStyle(
                fontSize: 11,
                color: cs.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
        ],
      );
    }

    final unknown = totals?.unknown;
    final items = <_SourceBalanceItem>[
      for (final source in sources)
        _SourceBalanceItem(
          icon: sourceIcon(source),
          label: source.name,
          balance: totals?.forSource(source.id)?.net ?? 0,
        ),
      if (unknown != null && !unknown.isEmpty)
        _SourceBalanceItem(
          icon: Icons.help_outline,
          label: unknownSourceLabel,
          balance: unknown.net,
        ),
    ];
    final shown = items.take(_maxRows).toList();
    final hiddenCount = items.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 4),
          )
        else
          for (final item in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SourceBalanceRow(
                icon: item.icon,
                label: item.label,
                balance: item.balance,
                onTap: onManage,
              ),
            ),
        if (!loading && hiddenCount > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onManage,
              style: _tightButton(cs),
              child: Text('+$hiddenCount lagi'),
            ),
          ),
        if (totals?.computedOnClient ?? false)
          Text(
            'Saldo dihitung di perangkat karena agregasi Firestore belum siap.',
            style: TextStyle(
              fontSize: 11,
              color: cs.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
      ],
    );
  }
}

class _SourceBalanceItem {
  final IconData icon;
  final String label;
  final int balance;

  const _SourceBalanceItem({
    required this.icon,
    required this.label,
    required this.balance,
  });
}

/// Satu baris saldo sumber: ikon, lalu nama sumber dengan angkanya di bawah.
///
/// Nama dan angka disusun dua baris supaya nominal rupiah panjang tidak
/// terpotong saat kolomnya hanya selebar separuh kartu.
class _SourceBalanceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int balance;
  final VoidCallback? onTap;

  const _SourceBalanceRow({
    required this.icon,
    required this.label,
    required this.balance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = balance > 0
        ? incomeColor(context)
        : balance < 0
            ? expenseColor(context)
            : cs.onPrimaryContainer;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Semantics(
        label: '$label, saldo ${rupiah.format(balance)}',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 16, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
                  ),
                  Text(
                    rupiah.format(balance),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? tooltip;

  const MiniStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ],
    );

    final stat = Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: content,
    );

    // Tooltip tampil saat tekan lama / hover di atas stat.
    return tooltip == null ? stat : Tooltip(message: tooltip!, child: stat);
  }
}
