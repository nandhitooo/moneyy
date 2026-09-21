import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../utils/helpers.dart';

/// Satu baris transaksi. Geser ke kiri untuk menghapus.
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
    final cs = Theme.of(context).colorScheme;
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            signedAmount,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
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
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
    );
  }
}
