import 'dart:async';

import 'package:flutter/material.dart';

import '../models/funding_source.dart';
import '../models/source_breakdown.dart';
import '../services/funding_source_service.dart';
import '../services/transaction_service.dart';
import '../utils/helpers.dart';
import '../widgets/status_views.dart';
import '../widgets/summary_card.dart';

/// Kelola sumber dana (tunai, rekening bank, e-wallet) sekaligus memantau
/// saldo tiap sumber.
///
/// Saldo = semua pemasukan dikurangi semua pengeluaran untuk sumber tersebut,
/// dihitung dengan agregasi Firestore. Hasil agregasi bukan stream, jadi saldo
/// dimuat ulang saat layar dibuka dan saat pengguna menarik daftar ke bawah.
class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  final _service = FundingSourceService();
  final _txService = TransactionService();

  StreamSubscription<List<FundingSource>>? _sourceSub;
  List<FundingSource> _sources = const [];
  SourceTotals _totals = const SourceTotals();
  bool _loadingTotals = true;
  bool _loadFailed = false;
  String? _loadError;
  bool _sourcesFailed = false;

  /// Penanda agar hasil pemuatan lama tidak menimpa hasil terbaru.
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _subscribeSources();
  }

  /// Memantau daftar sumber dana, lalu memuat ulang saldonya setiap daftar
  /// berubah (misalnya setelah sumber ditambah atau dihapus).
  void _subscribeSources() {
    _sourceSub?.cancel();
    _sourceSub = _service.watch().listen(
      (sources) {
        if (!mounted) return;
        setState(() => _sources = sources);
        unawaited(_loadTotals());
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _sourcesFailed = true;
          _loadingTotals = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _sourceSub?.cancel();
    super.dispose();
  }

  /// Memuat saldo semua sumber dana dengan agregasi, tanpa mengunduh dokumen
  /// transaksi.
  Future<void> _loadTotals() async {
    final token = ++_loadToken;
    setState(() {
      _loadingTotals = true;
      _loadFailed = false;
      _loadError = null;
    });

    try {
      final totals = await _txService.loadSourceTotals(_sources);
      if (!mounted || token != _loadToken) return;

      setState(() {
        _totals = totals;
        _loadingTotals = false;
      });
    } catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _loadingTotals = false;
        _loadFailed = true;
        _loadError = errorDetail(e);
      });
    }
  }

  Future<void> _seedDefaults() async {
    try {
      await _service.ensureDefaults();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menambah sumber: $e')));
      }
    }
  }

  Future<void> _openForm([FundingSource? existing]) async {
    final draft = await showDialog<_SourceDraft>(
      context: context,
      builder: (_) => _SourceFormDialog(existing: existing),
    );
    if (draft == null) return;

    try {
      if (existing == null) {
        await _service.add(draft.name, isCash: draft.isCash);
      } else {
        await _service.update(
          existing.copyWith(name: draft.name, isCash: draft.isCash),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    }
  }

  /// Sumber dana tidak boleh dihapus selama masih dipakai transaksi, supaya
  /// tidak ada transaksi yang kehilangan sumbernya.
  Future<void> _confirmDelete(FundingSource source) async {
    final id = source.id;
    if (id == null) return;

    int usedCount;
    try {
      usedCount = await _txService.countBySource(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memeriksa pemakaian: $e')),
        );
      }
      return;
    }
    if (!mounted) return;

    if (usedCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${source.name} masih dipakai'),
          content: Text(
            'Ada $usedCount transaksi yang memakai sumber ini. '
            'Ubah sumber transaksi tersebut dulu sebelum menghapus.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hapus ${source.name}?'),
        content: const Text('Sumber ini belum dipakai transaksi mana pun.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _service.delete(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sumber Dana'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang saldo',
            icon: const Icon(Icons.refresh),
            onPressed: _loadTotals,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_sourcesFailed) {
      return ErrorView(
        onRetry: () {
          setState(() => _sourcesFailed = false);
          _subscribeSources();
        },
      );
    }
    if (_sources.isEmpty) {
      return EmptyStateView(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Belum ada sumber dana',
        message: 'Tambahkan tunai, rekening bank, atau e-wallet '
            'untuk menandai setiap transaksi.',
        actionLabel: 'Pakai sumber bawaan',
        onAction: _seedDefaults,
      );
    }

    final unknown = _totals.unknown;

    return RefreshIndicator(
      onRefresh: _loadTotals,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        children: [
          if (_loadFailed)
            _LoadFailedBanner(detail: _loadError, onRetry: _loadTotals)
          else
            _BalanceHeader(
              overall: _totals.overall,
              loading: _loadingTotals,
              cash: _totals.cashNet(true, _sources),
              nonCash: _totals.cashNet(false, _sources),
            ),
          if (_totals.computedOnClient && !_loadFailed)
            const _ClientSideNote(),
          const SizedBox(height: 8),
          for (final source in _sources)
            _SourceTile(
              source: source,
              balance: _totals.forSource(source.id)?.net,
              loading: _loadingTotals,
              onEdit: () => _openForm(source),
              onDelete: () => _confirmDelete(source),
            ),
          if (unknown != null)
            _UnknownSourceTile(total: unknown, loading: _loadingTotals),
        ],
      ),
    );
  }
}

/// Ringkasan saldo gabungan dan pecahan tunai / non-tunai.
class _BalanceHeader extends StatelessWidget {
  final SourceTotal overall;
  final bool loading;
  final int cash;
  final int nonCash;

  const _BalanceHeader({
    required this.overall,
    required this.loading,
    required this.cash,
    required this.nonCash,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Total saldo', style: TextStyle(color: cs.onPrimaryContainer)),
            const SizedBox(height: 4),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 4),
              )
            else
              Semantics(
                label: 'Total saldo ${rupiah.format(overall.net)}',
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    rupiah.format(overall.net),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MiniStat(
                    icon: Icons.payments_outlined,
                    label: 'Tunai',
                    value: rupiah.format(cash),
                    color: cs.onPrimaryContainer,
                    tooltip: 'Saldo semua sumber dana bertanda uang tunai.',
                  ),
                ),
                Expanded(
                  child: MiniStat(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Non-tunai',
                    value: rupiah.format(nonCash),
                    color: cs.onPrimaryContainer,
                    tooltip: 'Saldo sumber non-tunai: rekening bank, e-wallet, '
                        'dan sejenisnya.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Saldo dihitung dari seluruh pemasukan dikurangi seluruh '
              'pengeluaran tiap sumber. Sumber tanpa tanda tunai/non-tunai '
              'hanya masuk ke total.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

/// Catatan bahwa angka saldo dihitung di perangkat, bukan oleh Firestore.
class _ClientSideNote extends StatelessWidget {
  const _ClientSideNote();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        'Saldo dihitung di perangkat karena agregasi Firestore belum siap.',
        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
      ),
    );
  }
}

/// Banner saat agregasi saldo gagal, tanpa menutupi daftar sumber.
class _LoadFailedBanner extends StatelessWidget {
  final String? detail;
  final Future<void> Function() onRetry;

  const _LoadFailedBanner({this.detail, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        color: cs.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_off, color: cs.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Gagal memuat saldo. Periksa koneksi lalu coba lagi.',
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                  ),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
              if (detail != null)
                SelectableText(
                  detail!,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onErrorContainer.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final FundingSource source;
  final int? balance;
  final bool loading;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SourceTile({
    required this.source,
    required this.balance,
    required this.loading,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Icon(sourceIcon(source))),
      title: Text(source.name),
      subtitle: Text(source.isCash ? 'Uang tunai' : 'Non-tunai'),
      onTap: onEdit,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BalanceText(balance: balance, loading: loading),
          PopupMenuButton<String>(
            tooltip: 'Opsi ${source.name}',
            onSelected: (value) {
              if (value == 'hapus') {
                onDelete();
              } else {
                onEdit();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'ubah', child: Text('Ubah')),
              PopupMenuItem(value: 'hapus', child: Text('Hapus')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Transaksi lama tanpa sumber dana, ditampilkan agar total tetap jelas.
class _UnknownSourceTile extends StatelessWidget {
  final SourceTotal total;
  final bool loading;

  const _UnknownSourceTile({required this.total, required this.loading});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.surfaceContainerHighest,
        child: Icon(Icons.help_outline, color: cs.onSurfaceVariant),
      ),
      title: const Text(unknownSourceLabel),
      subtitle: const Text('Transaksi lama yang belum ditandai sumber dana'),
      trailing: _BalanceText(balance: total.net, loading: loading),
    );
  }
}

class _BalanceText extends StatelessWidget {
  final int? balance;
  final bool loading;

  const _BalanceText({required this.balance, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading || balance == null) {
      return const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final value = balance!;
    final color = value > 0
        ? incomeColor(context)
        : value < 0
            ? expenseColor(context)
            : Theme.of(context).colorScheme.onSurfaceVariant;
    return Text(
      rupiah.format(value),
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}

class _SourceDraft {
  final String name;
  final bool isCash;

  const _SourceDraft(this.name, this.isCash);
}

/// Dialog tambah/ubah sumber dana.
class _SourceFormDialog extends StatefulWidget {
  final FundingSource? existing;

  const _SourceFormDialog({this.existing});

  @override
  State<_SourceFormDialog> createState() => _SourceFormDialogState();
}

class _SourceFormDialogState extends State<_SourceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late bool _isCash;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _isCash = widget.existing?.isCash ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _SourceDraft(_name.text.trim(), _isCash));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Ubah Sumber Dana' : 'Sumber Dana Baru'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama',
                hintText: 'Contoh: DANA, BCA, Dompet',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isCash,
              title: const Text('Uang tunai'),
              subtitle: Text(
                _isCash ? 'Dianggap uang cash' : 'Rekening bank atau e-wallet',
              ),
              onChanged: (value) => setState(() => _isCash = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Simpan' : 'Tambah'),
        ),
      ],
    );
  }
}
