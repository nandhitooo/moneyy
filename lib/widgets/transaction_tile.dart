import 'package:material_ui/material_ui.dart';

import '../models/transaction_model.dart';
import '../utils/helpers.dart';

/// Satu baris transaksi. Geser ke kiri untuk menghapus.
///
/// Tampilannya sengaja datar: ikon tipis tanpa lingkaran, judul tegas, dan
/// metadata redup. Warna hanya dipakai pada nominal agar mata langsung
/// tertuju ke angka.
class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isIncome = transaction.isIncome;
    final color = isIncome ? incomeColor(context) : expenseColor(context);
    final signedAmount =
        '${isIncome ? '+' : '-'}${rupiah.format(transaction.amount)}';
    final subtitle = [
      transaction.category,
      if (transaction.sourceName != null) transaction.sourceName!,
      dateFmt.format(transaction.date),
    ].join(' • ');

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: _DeleteBackground(colorScheme: cs),
      onDismissed: (_) => onDelete(),
      child: Semantics(
        label: '${transaction.title}, ${transaction.category}, '
            '${transaction.sourceName ?? ''}, $signedAmount, '
            '${dateFmt.format(transaction.date)}',
        button: true,
        excludeSemantics: true,
        child: ListTile(
          onTap: onTap,
          shape: const RoundedRectangleBorder(),
          minLeadingWidth: 24,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Icon(
            categoryIcon(transaction.category),
            size: 20,
            color: cs.onSurfaceVariant,
          ),
          title: Text(
            transaction.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          trailing: Text(
            signedAmount,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  final ColorScheme colorScheme;

  const _DeleteBackground({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
    );
  }
}
