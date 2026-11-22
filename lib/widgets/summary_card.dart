import 'package:material_ui/material_ui.dart';

import '../models/funding_source.dart';
import '../models/month_summary.dart';
import '../models/source_breakdown.dart';
import '../utils/helpers.dart';

/// Kartu saldo bulan ini.
///
/// Susunannya, dari atas ke bawah:
/// 1. saldo besar sebagai fokus utama,
/// 2. bar tipis proporsi pemasukan vs pengeluaran,
/// 3. statistik bulan (kiri) dan rincian saldo tiap sumber (kanan).
///
/// Bagian 3 dibuat dua kolom supaya kartu tetap pendek; pada lebar yang sangat
/// sempit keduanya kembali ditumpuk.
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
  /// kehilangan 32dp margin dan 40dp padding sehingga hanya tersisa 288dp.
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
    final spentShare = summary.income > 0 && summary.expense > 0
        ? (summary.expense / summary.income * 100).round()
        : null;

    final stats = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MiniStat(
          label: 'Dari bulan lalu',
          value: rupiah.format(summary.carry),
          color: cs.onSurfaceVariant,
          tooltip: 'Sisa saldo dari bulan-bulan sebelumnya '
              'yang otomatis dibawa ke bulan ini.',
        ),
        const SizedBox(height: 14),
        MiniStat(
          label: 'Pemasukan',
          value: rupiah.format(summary.income),
          color: incomeColor(context),
          tooltip: 'Total uang masuk selama bulan ini.',
        ),
        const SizedBox(height: 14),
        MiniStat(
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Saldo bulan ini',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (spentShare != null)
                  Text(
                    '$spentShare% terpakai',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Semantics(
              label: 'Saldo bulan ini ${rupiah.format(summary.balance)}',
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Rp ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(text: thousandFmt.format(summary.balance)),
                    ],
                  ),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _FlowBar(income: summary.income, expense: summary.expense),
            const SizedBox(height: 14),
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

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: stats),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: cs.outlineVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
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
        color: cs.outlineVariant.withValues(alpha: 0.7),
      );
}

/// Bar tipis proporsi uang masuk dan uang keluar bulan ini.
///
/// Tanpa teks, jadi tidak menambah tinggi kartu; maknanya dibaca dari warna
/// dan dari angka pemasukan/pengeluaran di bawahnya.
class _FlowBar extends StatelessWidget {
  final int income;
  final int expense;

  const _FlowBar({required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasIncome = income > 0;
    final hasExpense = expense > 0;

    final bar = Container(
      height: 4,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(2),
      ),
      child: !hasIncome && !hasExpense
          ? null
          : Row(
              children: [
                if (hasIncome)
                  Expanded(
                    flex: income,
                    child: ColoredBox(
                      color: incomeColor(context).withValues(alpha: 0.85),
                    ),
                  ),
                if (hasIncome && hasExpense) const SizedBox(width: 2),
                if (hasExpense)
                  Expanded(
                    flex: expense,
                    child: ColoredBox(
                      color: expenseColor(context).withValues(alpha: 0.85),
                    ),
                  ),
              ],
            ),
    );

    return Semantics(
      label: 'Pemasukan ${rupiah.format(income)}, '
          'pengeluaran ${rupiah.format(expense)}',
      child: bar,
    );
  }
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
        foregroundColor: cs.primary,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final header = Row(
      children: [
        Expanded(
          child: Text(
            'Saldo per sumber',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: cs.onSurfaceVariant,
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
          const SizedBox(height: 4),
          Text(
            'Gagal memuat saldo per sumber.',
            style: theme.textTheme.bodySmall,
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
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: cs.onSurfaceVariant,
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
        const SizedBox(height: 4),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 2),
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
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              color: cs.onSurfaceVariant,
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

/// Satu baris saldo sumber: ikon tipis, lalu nama sumber dengan angkanya di
/// bawah. Nama dan angka disusun dua baris supaya nominal rupiah panjang tidak
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = balance > 0
        ? incomeColor(context)
        : balance < 0
            ? expenseColor(context)
            : cs.onSurfaceVariant;

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
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 15, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant,
                    ),
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

/// Statistik kecil: titik warna, label redup, lalu angka tegas.
///
/// Titik dipakai sebagai penanda warna, bukan ikon, agar kartu tidak terasa
/// seperti kumpulan tombol.
class MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? tooltip;

  const MiniStat({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            height: 6,
            width: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11.5,
                  height: 1.2,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
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
