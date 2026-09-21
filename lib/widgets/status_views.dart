import 'package:flutter/material.dart';

/// Ilustrasi kosong dengan ikon dan ajakan aksi.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  const EmptyStateView({
    super.key,
    this.icon = Icons.receipt_long,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon = Icons.add,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: Icon(actionIcon),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Filter aktif tetapi tidak ada transaksi yang cocok.
class NoResultView extends StatelessWidget {
  final VoidCallback onReset;

  const NoResultView({super.key, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.search_off,
      title: 'Tidak ada hasil',
      message: 'Coba kata kunci lain atau reset filter.',
      actionLabel: 'Reset filter',
      actionIcon: Icons.filter_alt_off,
      onAction: onReset,
    );
  }
}

/// Gagal memuat data, lengkap dengan tombol coba lagi.
class ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const ErrorView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: cs.error),
            const SizedBox(height: 12),
            Text(
              'Gagal memuat data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Periksa koneksi internet lalu coba lagi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
