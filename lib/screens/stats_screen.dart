import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../models/month_summary.dart';
import '../models/source_breakdown.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../utils/helpers.dart';
import '../widgets/month_selector.dart';
import '../widgets/status_views.dart';
import '../widgets/summary_card.dart';

/// Statistik satu bulan: ringkasan, pengeluaran per kategori, dan arus dana
/// per sumber dana (tunai, rekening bank, e-wallet).
class StatsScreen extends StatefulWidget {
  final DateTime month;

  const StatsScreen({super.key, required this.month});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  /// Palet redup, semuanya cukup gelap di tema terang dan dicerahkan otomatis
  /// di tema gelap lewat [_tint].
  static const _colors = [
    Color(0xFF0F766E),
    Color(0xFF0E7490),
    Color(0xFF4338CA),
    Color(0xFF7E22CE),
    Color(0xFFBE185D),
    Color(0xFFC2410C),
    Color(0xFFA16207),
    Color(0xFF4D7C0F),
  ];

  final _service = TransactionService();
  late DateTime _month;
  late Stream<List<TransactionModel>> _stream;

  @override
  void initState() {
    super.initState();
    _month = widget.month;
    _stream = _service.watchMonth(_month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _stream = _service.watchMonth(_month);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(
              onRetry: () => setState(() {
                _stream = _service.watchMonth(_month);
              }),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              MonthSelector(
                month: _month,
                onPrevious: () => _changeMonth(-1),
                onNext: () => _changeMonth(1),
              ),
              if (transactions.isEmpty)
                const SizedBox(
                  height: 320,
                  child: EmptyStateView(
                    icon: Icons.insights,
                    title: 'Belum ada data bulan ini',
                    message: 'Catat transaksi dulu untuk melihat statistik.',
                  ),
                )
              else
                ..._buildContent(context, transactions),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildContent(
    BuildContext context,
    List<TransactionModel> transactions,
  ) {
    final summary = MonthSummary.fromTransactions(transactions);
    final byCategory = <String, int>{};
    for (final t in transactions.where((t) => !t.isIncome)) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
    }
    final categories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalExpense = categories.fold<int>(0, (sum, e) => sum + e.value);

    final sources = SourceBreakdown.group(transactions);

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: MiniStat(
                    label: 'Pemasukan',
                    value: rupiah.format(summary.income),
                    color: incomeColor(context),
                  ),
                ),
                Expanded(
                  child: MiniStat(
                    label: 'Pengeluaran',
                    value: rupiah.format(summary.expense),
                    color: expenseColor(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (categories.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Text(
            'Belum ada pengeluaran bulan ini.',
            textAlign: TextAlign.center,
          ),
        )
      else ...[
        const _SectionTitle('Pengeluaran per kategori'),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: PieChart(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 58,
              sections: [
                for (var i = 0; i < categories.length; i++)
                  PieChartSectionData(
                    value: categories[i].value.toDouble(),
                    color: _tint(context, i),
                    radius: 46,
                    title: '${_percent(categories[i].value, totalExpense)}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const _SectionTitle('Rincian kategori'),
        for (var i = 0; i < categories.length; i++)
          _BreakdownRow(
            icon: categoryIcon(categories[i].key),
            title: categories[i].key,
            amount: categories[i].value,
            percent: _percent(categories[i].value, totalExpense),
            color: _tint(context, i),
          ),
      ],
      const SizedBox(height: 8),
      const _SectionTitle('Arus dana per sumber'),
      for (var i = 0; i < sources.length; i++)
        _BreakdownRow(
          icon: _sourceIcon(sources[i]),
          title: sources[i].name,
          amount: sources[i].total,
          percent: _percent(sources[i].total, _totalFlow(sources)),
          color: _tint(context, i),
          subtitle: _sourceSubtitle(sources[i]),
        ),
    ];
  }

  static int _totalFlow(List<SourceBreakdown> sources) =>
      sources.fold<int>(0, (sum, s) => sum + s.total);

  static String _sourceSubtitle(SourceBreakdown source) =>
      'Masuk ${rupiah.format(source.income)} • '
      'Keluar ${rupiah.format(source.expense)}';

  static int _percent(int value, int total) =>
      total == 0 ? 0 : (value / total * 100).round();

  /// Warna palet dicerahkan di tema gelap supaya tetap terbaca.
  static Color _tint(BuildContext context, int index) {
    final color = _colors[index % _colors.length];
    return Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(color, Colors.white, 0.45)!
        : color;
  }

  static IconData _sourceIcon(SourceBreakdown source) => source.isCash == true
      ? Icons.payments_outlined
      : Icons.account_balance_wallet_outlined;
}

/// Judul bagian: kecil, redup, dan berjarak lega.
class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Baris rincian: ikon tipis, nama, nominal, dan porsi dalam persen.
class _BreakdownRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final int amount;
  final int percent;
  final Color color;
  final String? subtitle;

  const _BreakdownRow({
    required this.icon,
    required this.title,
    required this.amount,
    required this.percent,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      label: '$title $percent persen, ${rupiah.format(amount)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        rupiah.format(amount),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            minHeight: 4,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$percent%',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
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
