import 'package:material_ui/material_ui.dart';

import '../models/funding_source.dart';
import '../models/source_ledger.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../utils/helpers.dart';
import '../widgets/status_views.dart';
import 'add_transaction_screen.dart';

/// Detail satu sumber dana: saldo saat ini, saldo awal, dan riwayat transaksi
/// sumber tersebut beserta saldo berjalan setelah tiap transaksi.
class SourceDetailScreen extends StatefulWidget {
  final FundingSource source;

  const SourceDetailScreen({super.key, required this.source});

  @override
  State<SourceDetailScreen> createState() => _SourceDetailScreenState();
}

class _SourceDetailScreenState extends State<SourceDetailScreen> {
  final _service = TransactionService();
  late Stream<List<TransactionModel>> _stream;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final id = widget.source.id;
    _stream = id == null
        ? const Stream<List<TransactionModel>>.empty()
        : _service.watchBySource(id);
  }

  void _retry() => setState(_subscribe);

  Future<void> _openTransaction(TransactionModel transaction) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(existing: transaction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(sourceIcon(widget.source), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.source.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorView(onRetry: _retry);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final ledger = SourceLedger.fromTransactions(
            snapshot.data!,
            initialBalance: widget.source.initialBalance,
          );

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: ledger.entries.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _LedgerHeader(source: widget.source, ledger: ledger);
              }
              if (ledger.entries.isEmpty) {
                return const _NoTransactionNote();
              }
              final entry = ledger.entries[index - 1];
              return _LedgerTile(
                entry: entry,
                onTap: () => _openTransaction(entry.transaction),
              );
            },
          );
        },
      ),
    );
  }
}

/// Ringkasan saldo sumber: saldo terkini, jenis, saldo awal, dan jumlah
/// transaksi.
class _LedgerHeader extends StatelessWidget {
  final FundingSource source;
  final SourceLedger ledger;

  const _LedgerHeader({required this.source, required this.ledger});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.all(16),
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Saldo saat ini',
                style: TextStyle(color: cs.onPrimaryContainer)),
            const SizedBox(height: 4),
            Semantics(
              label: 'Saldo ${source.name} ${rupiah.format(ledger.balance)}',
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  rupiah.format(ledger.balance),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${source.type.label} • Saldo awal '
              '${rupiah.format(source.initialBalance)} • '
              '${ledger.transactionCount} transaksi',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu transaksi dengan saldo berjalan di bawah nominalnya.
class _LedgerTile extends StatelessWidget {
  final SourceLedgerEntry entry;
  final VoidCallback onTap;

  const _LedgerTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final transaction = entry.transaction;
    final isIncome = transaction.isIncome;
    final color = isIncome ? incomeColor(context) : expenseColor(context);
    final signedAmount =
        '${isIncome ? '+' : '-'}${rupiah.format(transaction.amount)}';

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(categoryIcon(transaction.category), color: color),
      ),
      title: Text(
        transaction.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${transaction.category} • ${dateFmt.format(transaction.date)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            signedAmount,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          Text(
            'Saldo ${rupiah.format(entry.balance)}',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NoTransactionNote extends StatelessWidget {
  const _NoTransactionNote();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
      child: Column(
        children: [
          Icon(Icons.receipt_long,
              size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(
            'Belum ada transaksi',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Transaksi yang memakai sumber ini akan muncul di sini, '
            'lengkap dengan saldo berjalannya.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
