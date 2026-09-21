import 'dart:async';

import 'package:flutter/material.dart';

import '../models/funding_source.dart';
import '../models/month_summary.dart';
import '../models/source_breakdown.dart';
import '../models/transaction_model.dart';
import '../services/auth_service.dart';
import '../services/funding_source_service.dart';
import '../services/transaction_service.dart';
import '../utils/helpers.dart';
import '../widgets/home_app_bar.dart';
import '../widgets/month_picker.dart';
import '../widgets/month_selector.dart';
import '../widgets/status_views.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_filters.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'sources_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = TransactionService();
  final _sourceService = FundingSourceService();
  final _searchCtrl = TextEditingController();

  late DateTime _month;
  late Stream<List<TransactionModel>> _stream;
  StreamSubscription<List<FundingSource>>? _sourceSub;
  List<FundingSource> _sources = const [];
  SourceTotals? _sourceTotals;
  bool _totalsLoading = false;
  bool _totalsFailed = false;
  String? _totalsError;
  int _totalsToken = 0;

  String _query = ''; // sudah di-trim dan lowercase
  String? _categoryFilter; // null = semua kategori
  String? _sourceFilter; // null = semua sumber dana
  int _carry = 0; // sisa uang dari bulan-bulan sebelumnya
  bool _carryFailed = false;

  /// Transaksi yang sudah dihapus di layar tetapi belum tentu hilang dari
  /// stream, supaya Dismissible tidak dibangun ulang setelah dihapus.
  final Set<String> _pendingDelete = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _stream = _service.watchMonth(_month);
    unawaited(_loadCarry());
    unawaited(_prepareSources());
  }

  @override
  void dispose() {
    _sourceSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Isi sumber dana bawaan saat pertama kali, lalu pantau perubahannya.
  Future<void> _prepareSources() async {
    try {
      await _sourceService.ensureDefaults();
    } catch (_) {
      // Diabaikan: daftar kosong sudah ditangani di layar sumber dana.
    }
    if (!mounted) return;
    _sourceSub = _sourceService.watch().listen(
      (sources) {
        if (!mounted) return;
        setState(() => _sources = sources);
        unawaited(_loadSourceTotals());
      },
      onError: (Object e) {
        if (mounted) {
          setState(() {
            _totalsFailed = true;
            _totalsError = errorDetail(e);
          });
        }
      },
    );
  }

  /// Memuat saldo tiap sumber dana dengan agregasi, tanpa mengunduh dokumen
  /// transaksi. Hasil agregasi bukan stream, jadi dimuat ulang setiap ada
  /// perubahan transaksi.
  Future<void> _loadSourceTotals() async {
    if (_sources.isEmpty) {
      setState(() => _sourceTotals = null);
      return;
    }

    final token = ++_totalsToken;
    setState(() {
      _totalsLoading = true;
      _totalsFailed = false;
      _totalsError = null;
    });

    try {
      final totals = await _service.loadSourceTotals(_sources);
      if (!mounted || token != _totalsToken) return;
      setState(() {
        _sourceTotals = totals;
        _totalsLoading = false;
      });
    } catch (e) {
      if (!mounted || token != _totalsToken) return;
      setState(() {
        _totalsLoading = false;
        _totalsFailed = true;
        _totalsError = errorDetail(e);
      });
    }
  }

  /// Ambil saldo bersih bulan-bulan sebelumnya untuk dibawa ke bulan ini.
  Future<void> _loadCarry() async {
    try {
      final carry = await _service.balanceBefore(_month);
      if (!mounted) return;
      setState(() {
        _carry = carry;
        _carryFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      final firstFailure = !_carryFailed;
      setState(() => _carryFailed = true);
      // Notifikasi hanya sekali agar tidak menumpuk saat koneksi putus.
      if (firstFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat saldo bulan lalu.')),
        );
      }
    }
  }

  void _changeMonth(int delta) =>
      _goToMonth(DateTime(_month.year, _month.month + delta));

  /// Membuka pemilih bulan supaya bisa melompat jauh tanpa menekan tombol
  /// maju/mundur berulang kali.
  Future<void> _pickMonth() async {
    final picked = await showMonthPicker(context, initial: _month);
    if (!mounted || picked == null) return;
    // Bulan yang sama tidak perlu membangun ulang stream dan memuat saldo.
    if (picked.year == _month.year && picked.month == _month.month) return;
    _goToMonth(picked);
  }

  /// Mengganti bulan aktif, lalu memuat ulang saldo bulan sebelumnya yang
  /// dipakai sebagai saldo awal.
  void _goToMonth(DateTime month) {
    setState(() {
      _month = DateTime(month.year, month.month);
      _stream = _service.watchMonth(_month);
    });
    unawaited(_loadCarry());
  }

  /// Dipakai tombol muat ulang dan pull-to-refresh.
  Future<void> _refresh() async {
    setState(() => _stream = _service.watchMonth(_month));
    await _loadCarry();
    await _loadSourceTotals();
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok == true) await AuthService().signOut();
  }

  /// Filter pencarian + kategori, dipakai hanya untuk daftar.
  /// Ringkasan saldo tetap dihitung dari semua transaksi bulan ini.
  bool _matches(TransactionModel transaction) {
    final okCategory =
        _categoryFilter == null || transaction.category == _categoryFilter;
    if (!okCategory || !_matchesSource(transaction)) return false;
    if (_query.isEmpty) return true;
    return transaction.title.toLowerCase().contains(_query) ||
        transaction.note.toLowerCase().contains(_query) ||
        transaction.category.toLowerCase().contains(_query);
  }

  bool _matchesSource(TransactionModel transaction) {
    if (_sourceFilter == null) return true;
    if (_sourceFilter == unknownSourceFilterId) return transaction.sourceId == null;
    return transaction.sourceId == _sourceFilter;
  }

  Future<void> _openForm([TransactionModel? transaction]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(existing: transaction),
      ),
    );
    // Tanggal bisa berubah atau transaksi baru masuk bulan lalu, jadi saldo
    // awal dan saldo per sumber dihitung ulang.
    if (!mounted) return;
    unawaited(_loadCarry());
    unawaited(_loadSourceTotals());
  }

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    final id = transaction.id;
    if (id == null) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _pendingDelete.add(id));
    try {
      await _service.delete(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pendingDelete.remove(id));
      messenger.showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
      return;
    }

    unawaited(_loadCarry());
    unawaited(_loadSourceTotals());
    final controller = messenger.showSnackBar(
      SnackBar(
        content: const Text('Transaksi dihapus'),
        action: SnackBarAction(
          label: 'Urungkan',
          onPressed: () => unawaited(_undoDelete(transaction)),
        ),
      ),
    );
    final reason = await controller.closed;
    // Snackbar ditutup tanpa menekan "Urungkan" -> hapus sudah final.
    if (reason != SnackBarClosedReason.action && mounted) {
      setState(() => _pendingDelete.remove(id));
    }
  }

  Future<void> _undoDelete(TransactionModel transaction) async {
    final id = transaction.id;
    if (id != null) setState(() => _pendingDelete.remove(id));
    try {
      await _service.restore(transaction);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal memulihkan: $e')));
      }
    }
    await _loadCarry();
    await _loadSourceTotals();
  }

  Future<void> _openSources() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SourcesScreen()),
    );
    if (mounted) unawaited(_loadSourceTotals());
  }

  void _openStats() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StatsScreen(month: _month)),
    );
  }

  void _resetFilter() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _categoryFilter = null;
      _sourceFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HomeAppBar(
        onOpenStats: _openStats,
        onRefresh: _refresh,
        onLogout: _confirmLogout,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
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

          final all = snapshot.data!;
          final summary = MonthSummary.fromTransactions(all, carry: _carry);
          final visible = all
              .where((t) => !_pendingDelete.contains(t.id))
              .where(_matches)
              .toList();

          // Seluruh isi layar - termasuk kartu ringkasan dan bar filter - ikut
          // menggulir dalam satu CustomScrollView. Sebelumnya hanya daftar
          // transaksi yang menggulir sementara header berukuran tetap, jadi
          // header yang tinggi membuat layar melaporkan "bottom overflowed".
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: MonthSelector(
                    month: _month,
                    onPrevious: () => _changeMonth(-1),
                    onNext: () => _changeMonth(1),
                    onTap: _pickMonth,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SummaryCard(
                    summary: summary,
                    sourceTotals: _sourceTotals,
                    sources: _sources,
                    sourceBalancesLoading: _totalsLoading,
                    sourceBalancesFailed: _totalsFailed,
                    sourceBalancesError: _totalsError,
                    onRetrySourceBalances: _loadSourceTotals,
                    onManageSources: _openSources,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(
                  child: TransactionSearchField(
                    controller: _searchCtrl,
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                  ),
                ),
                // Kedua bar filter mengembalikan ListView horizontal, jadi
                // tingginya harus dibatasi.
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: CategoryFilterBar(
                      selected: _categoryFilter,
                      usedCategories: all.map((t) => t.category).toSet(),
                      onSelected: (category) =>
                          setState(() => _categoryFilter = category),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: SourceFilterBar(
                      selectedId: _sourceFilter,
                      sources: _sources,
                      hasUnknown: all.any((t) => t.sourceId == null),
                      onSelected: (sourceId) =>
                          setState(() => _sourceFilter = sourceId),
                    ),
                  ),
                ),
                if (all.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateView(
                      title: 'Belum ada transaksi bulan ini',
                      message: 'Tekan tombol di bawah untuk mencatat '
                          'pemasukan atau pengeluaran.',
                      actionLabel: 'Tambah transaksi',
                      onAction: () => _openForm(),
                    ),
                  )
                else if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: NoResultView(onReset: _resetFilter),
                  )
                else
                  SliverPadding(
                    // Ruang untuk FAB supaya transaksi terakhir tidak tertutup.
                    padding: const EdgeInsets.only(bottom: 96),
                    sliver: SliverList.builder(
                      key: const ValueKey('daftar-transaksi'),
                      itemCount: visible.length,
                      itemBuilder: (_, i) => TransactionTile(
                        transaction: visible[i],
                        onTap: () => _openForm(visible[i]),
                        onDelete: () => _deleteTransaction(visible[i]),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
