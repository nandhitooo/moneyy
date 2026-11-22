import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/funding_source.dart';
import '../models/source_breakdown.dart';
import '../services/funding_source_service.dart';
import '../services/transaction_service.dart';
import '../utils/helpers.dart';
import '../utils/thousands_input_formatter.dart';
import '../widgets/status_views.dart';
import '../widgets/summary_card.dart';
import 'source_detail_screen.dart';

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
        await _service.add(
          FundingSource(
            name: draft.name,
            type: draft.type,
            initialBalance: draft.initialBalance,
            adminFee: draft.adminFee,
            adminFeeDay: draft.adminFeeDay,
          ),
        );
      } else {
        await _service.update(
          existing.copyWith(
            name: draft.name,
            type: draft.type,
            initialBalance: draft.initialBalance,
            adminFee: draft.adminFee,
            adminFeeDay: draft.adminFeeDay,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    }
  }

  /// Mengatur biaya admin bulanan (nominal + tanggal bayar) lewat dialog
  /// ringkas, tanpa membuka form sumber dana lengkap.
  Future<void> _openAdminFee(FundingSource source) async {
    final draft = await showDialog<_AdminFeeDraft>(
      context: context,
      builder: (_) => _AdminFeeDialog(source: source),
    );
    if (draft == null) return;

    try {
      // Dibangun ulang (bukan copyWith) supaya tanggal ikut dikosongkan saat
      // biaya admin dihapus.
      await _service.update(
        FundingSource(
          id: source.id,
          name: source.name,
          type: source.type,
          initialBalance: source.initialBalance,
          adminFee: draft.amount,
          adminFeeDay: draft.dayOfMonth,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan biaya admin: $e')),
        );
      }
    }
  }

  /// Menimpa saldo terkini sumber dana dengan angka yang diketik pengguna.
  ///
  /// Saldo sumber = saldo awal + pemasukan - pengeluaran. Supaya saldo menjadi
  /// [target] tanpa menambah transaksi palsu, yang disesuaikan adalah saldo
  /// awal: `initialBalance = target - (pemasukan - pengeluaran)`. Transaksi
  /// tidak diubah, jadi riwayatnya tetap utuh.
  Future<void> _openEditBalance(FundingSource source) async {
    final total = _totals.forSource(source.id);
    if (total == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saldo belum termuat. Tunggu sebentar atau muat ulang.'),
        ),
      );
      return;
    }

    final target = await showDialog<int>(
      context: context,
      builder: (_) => _BalanceDialog(
        sourceName: source.name,
        currentBalance: total.net,
      ),
    );
    if (target == null || target == total.net) return;

    try {
      await _service.update(
        source.copyWith(
          initialBalance: target - (total.income - total.expense),
        ),
      );
      if (mounted) unawaited(_loadTotals());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan saldo: $e')),
        );
      }
    }
  }

  /// Membuka riwayat transaksi sumber ini beserta saldo berjalannya.
  Future<void> _openDetail(FundingSource source) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SourceDetailScreen(source: source)),
    );
    if (mounted) unawaited(_loadTotals());
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
          if (_totals.computedOnClient && !_loadFailed) const _ClientSideNote(),
          const SizedBox(height: 8),
          for (final source in _sources)
            _SourceTile(
              source: source,
              balance: _totals.forSource(source.id)?.net,
              loading: _loadingTotals,
              onOpen: () => _openDetail(source),
              onEdit: () => _openForm(source),
              onEditAdminFee: () => _openAdminFee(source),
              onEditBalance: () => _openEditBalance(source),
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Total saldo',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.3,
              ),
            ),
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
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MiniStat(
                    label: 'Tunai',
                    value: rupiah.format(cash),
                    color: cs.onSurfaceVariant,
                    tooltip: 'Saldo semua sumber dana bertanda uang tunai.',
                  ),
                ),
                Expanded(
                  child: MiniStat(
                    label: 'Non-tunai',
                    value: rupiah.format(nonCash),
                    color: cs.onSurfaceVariant,
                    tooltip: 'Saldo sumber non-tunai: rekening bank, e-wallet, '
                        'dan sejenisnya.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Saldo = saldo awal tiap sumber + seluruh pemasukan - seluruh '
              'pengeluaran. Saldo dihitung di perangkat dari data tersimpan, '
              'jadi tidak perlu mencatat transaksi palsu.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
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
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onEditAdminFee;
  final VoidCallback onEditBalance;
  final VoidCallback onDelete;

  const _SourceTile({
    required this.source,
    required this.balance,
    required this.loading,
    required this.onOpen,
    required this.onEdit,
    required this.onEditAdminFee,
    required this.onEditBalance,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = source.adminFeeSchedule;
    final now = DateTime.now();

    return ListTile(
      leading: CircleAvatar(child: Icon(sourceIcon(source))),
      title: Text(source.name),
      isThreeLine: schedule != null,
      subtitle: Text(
        [
          source.initialBalance == 0
              ? source.type.label
              : '${source.type.label} • Saldo awal '
                  '${rupiah.format(source.initialBalance)}',
          if (schedule != null)
            'Admin ${rupiah.format(schedule.amount)} tiap tanggal '
                '${schedule.dayOfMonth} • berikutnya '
                '${dateFmt.format(schedule.nextDate(now))}',
        ].join('\n'),
      ),
      onTap: onOpen,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BalanceText(balance: balance, loading: loading),
          PopupMenuButton<String>(
            tooltip: 'Opsi ${source.name}',
            onSelected: (value) {
              if (value == 'admin') {
                onEditAdminFee();
              } else if (value == 'saldo') {
                onEditBalance();
              } else if (value == 'hapus') {
                onDelete();
              } else {
                onEdit();
              }
            },
            itemBuilder: (_) => [
              // Biaya admin hanya relevan untuk rekening bank dan e-wallet.
              if (!source.isCash)
                const PopupMenuItem(
                  value: 'admin',
                  child: Text('Atur biaya admin'),
                ),
              const PopupMenuItem(value: 'saldo', child: Text('Ubah saldo')),
              const PopupMenuItem(value: 'ubah', child: Text('Ubah')),
              const PopupMenuItem(value: 'hapus', child: Text('Hapus')),
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

/// Dialog untuk menimpa saldo terkini satu sumber dana.
class _BalanceDialog extends StatefulWidget {
  final String sourceName;
  final int currentBalance;

  const _BalanceDialog({
    required this.sourceName,
    required this.currentBalance,
  });

  @override
  State<_BalanceDialog> createState() => _BalanceDialogState();
}

class _BalanceDialogState extends State<_BalanceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _balance;

  @override
  void initState() {
    super.initState();
    // Kolom hanya menerima digit, jadi saldo negatif tidak bisa ditampilkan di
    // sini; angkanya tetap dijelaskan lewat teks bantuan.
    _balance = TextEditingController(
      text: widget.currentBalance > 0
          ? thousandFmt.format(widget.currentBalance)
          : '',
    );
  }

  @override
  void dispose() {
    _balance.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, ThousandsInputFormatter.parse(_balance.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ubah saldo ${widget.sourceName}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _balance,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Saldo saat ini',
                prefixText: 'Rp ',
                helperText: 'Saldo sekarang '
                    '${rupiah.format(widget.currentBalance)}. Perubahan '
                    'menyesuaikan saldo awal, bukan menambah transaksi.',
                helperMaxLines: 3,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Saldo wajib diisi'
                  : null,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}

class _AdminFeeDraft {
  final int amount;
  final int? dayOfMonth;

  const _AdminFeeDraft(this.amount, this.dayOfMonth);
}

/// Dialog ringkas untuk mengatur biaya admin bulanan satu sumber dana.
///
/// Nominal 0 dianggap "tanpa biaya admin", jadi tanggalnya ikut dikosongkan
/// saat disimpan.
class _AdminFeeDialog extends StatefulWidget {
  final FundingSource source;

  const _AdminFeeDialog({required this.source});

  @override
  State<_AdminFeeDialog> createState() => _AdminFeeDialogState();
}

class _AdminFeeDialogState extends State<_AdminFeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  int? _day;

  int get _amountValue => ThousandsInputFormatter.parse(_amount.text);

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    _amount = TextEditingController(
      text: source.adminFee == 0 ? '' : thousandFmt.format(source.adminFee),
    );
    _day = source.adminFeeDay;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = _amountValue;
    Navigator.pop(
      context,
      _AdminFeeDraft(amount, amount == 0 ? null : _day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.source.adminFeeSchedule;
    return AlertDialog(
      scrollable: true,
      title: Text('Biaya admin ${widget.source.name}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Jumlah per bulan',
                prefixText: 'Rp ',
                helperText: schedule == null
                    ? 'Isi 0 atau kosongkan bila tidak ada biaya admin.'
                    : 'Sekarang ${rupiah.format(schedule.amount)} tiap '
                        'tanggal ${schedule.dayOfMonth}.',
                helperMaxLines: 2,
              ),
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            FormField<int?>(
              initialValue: _day,
              validator: (_) => _amountValue > 0 && _day == null
                  ? 'Pilih tanggal bayar'
                  : null,
              builder: (field) => InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Tanggal bayar',
                  errorText: field.errorText,
                  helperText: 'Saldo diperkirakan terpotong tiap tanggal ini.',
                  helperMaxLines: 2,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    isExpanded: true,
                    value: _day,
                    hint: const Text('Pilih tanggal'),
                    items: [
                      for (var day = 1; day <= 31; day++)
                        DropdownMenuItem(
                          value: day,
                          child: Text('Tanggal $day'),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => _day = value);
                      field.didChange(value);
                    },
                  ),
                ),
              ),
            ),
            if (schedule != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    const _AdminFeeDraft(0, null),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus biaya admin'),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}

class _SourceDraft {
  final String name;
  final FundingSourceType type;
  final int initialBalance;
  final int adminFee;
  final int? adminFeeDay;

  const _SourceDraft(
    this.name,
    this.type,
    this.initialBalance,
    this.adminFee,
    this.adminFeeDay,
  );
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
  late final TextEditingController _initialBalance;
  late final TextEditingController _adminFee;
  late FundingSourceType _type;
  int? _adminFeeDay;

  /// Nominal biaya admin yang sedang diketik, dipakai validator tanggal.
  int get _adminFeeValue => ThousandsInputFormatter.parse(_adminFee.text);

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _type = existing?.type ?? FundingSourceType.bank;
    final initial = existing?.initialBalance ?? 0;
    _initialBalance = TextEditingController(
      text: initial == 0 ? '' : thousandFmt.format(initial),
    );
    final fee = existing?.adminFee ?? 0;
    _adminFee = TextEditingController(
      text: fee == 0 ? '' : thousandFmt.format(fee),
    );
    _adminFeeDay = existing?.adminFeeDay;
  }

  @override
  void dispose() {
    _name.dispose();
    _initialBalance.dispose();
    _adminFee.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final isCash = _type == FundingSourceType.cash;
    Navigator.pop(
      context,
      _SourceDraft(
        _name.text.trim(),
        _type,
        ThousandsInputFormatter.parse(_initialBalance.text),
        isCash ? 0 : _adminFeeValue,
        isCash ? null : _adminFeeDay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      // Lima kolom bisa melebihi tinggi dialog di layar pendek.
      scrollable: true,
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
            const SizedBox(height: 12),
            DropdownButtonFormField<FundingSourceType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Jenis'),
              items: [
                for (final type in FundingSourceType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(sourceIconOf(type), size: 18),
                        const SizedBox(width: 8),
                        Text(type.label),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _initialBalance,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Saldo awal',
                prefixText: 'Rp ',
                helperText: 'Uang yang sudah ada sebelum transaksi pertama.',
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
            // Biaya admin tidak relevan untuk uang tunai, jadi kolomnya hanya
            // tampil untuk rekening bank dan e-wallet.
            if (_type != FundingSourceType.cash) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _adminFee,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Biaya admin / bulan',
                  prefixText: 'Rp ',
                  helperText: 'Kosongkan bila tidak ada biaya admin.',
                ),
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              FormField<int?>(
                initialValue: _adminFeeDay,
                validator: (_) => _adminFeeValue > 0 && _adminFeeDay == null
                    ? 'Pilih tanggal bayar'
                    : null,
                builder: (field) => InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tanggal bayar',
                    errorText: field.errorText,
                    helperText: 'Saldo diperkirakan terpotong tiap tanggal ini.',
                    helperMaxLines: 2,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      value: _adminFeeDay,
                      hint: const Text('Pilih tanggal'),
                      items: [
                        for (var day = 1; day <= 31; day++)
                          DropdownMenuItem(
                            value: day,
                            child: Text('Tanggal $day'),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() => _adminFeeDay = value);
                        field.didChange(value);
                      },
                    ),
                  ),
                ),
              ),
            ],
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
