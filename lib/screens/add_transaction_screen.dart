import 'dart:async';

import 'package:flutter/material.dart';

import '../models/funding_source.dart';
import '../models/transaction_model.dart';
import '../services/funding_source_service.dart';
import '../services/transaction_service.dart';
import '../utils/helpers.dart';
import '../utils/thousands_input_formatter.dart';
import '../widgets/category_picker.dart';
import '../widgets/source_picker.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? existing;

  const AddTransactionScreen({super.key, this.existing});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = TransactionService();
  final _sourceService = FundingSourceService();

  late TxType _type;
  late String _category;
  late DateTime _date;
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;

  StreamSubscription<List<FundingSource>>? _sourceSub;
  List<FundingSource> _sources = const [];
  String? _sourceId;
  String? _sourceName;
  bool? _sourceIsCash;

  /// True setelah pengguna memilih sumbernya sendiri, supaya pengisian otomatis
  /// tidak menimpa pilihan itu (misalnya pilihan **Belum diisi**).
  bool _sourceTouched = false;

  bool _saving = false;
  bool _saved = false;

  bool get _isEdit => widget.existing != null;

  List<String> get _categories =>
      _type == TxType.expense ? expenseCategories : incomeCategories;


  int get _amountValue => ThousandsInputFormatter.parse(_amount.text);

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? TxType.expense;
    _category = e?.category ?? _categories.first;
    _date = e?.date ?? DateTime.now();
    _sourceId = e?.sourceId;
    _sourceName = e?.sourceName;
    _sourceIsCash = e?.sourceIsCash;
    _title = TextEditingController(text: e?.title ?? '');
    _amount = TextEditingController(text: e != null ? e.amount.toString() : '');
    _note = TextEditingController(text: e?.note ?? '');
    _amount.addListener(() => setState(() {})); // preview real-time
    _sourceSub = _sourceService.watch().listen(_onSources);
  }

  /// Transaksi baru langsung memakai sumber tunai pertama supaya sumber dana
  /// terisi tanpa usaha tambahan.
  ///
  /// Pengisian otomatis berhenti setelah pengguna memilih sendiri, supaya
  /// pilihan **Belum diisi** tidak ditimpa saat daftar sumber dana berubah.
  void _onSources(List<FundingSource> sources) {
    if (!mounted) return;
    setState(() {
      _sources = sources;
      if (_isNew &&
          !_sourceTouched &&
          _sourceId == null &&
          sources.isNotEmpty) {
        final firstCash = sources.firstWhere(
          (s) => s.isCash,
          orElse: () => sources.first,
        );
        _sourceId = firstCash.id;
        _sourceName = firstCash.name;
        _sourceIsCash = firstCash.isCash;
      }
    });
  }

  /// Menerapkan pilihan dropdown sumber dana. `null` berarti **Belum diisi**.
  void _selectSource(FundingSource? source) {
    setState(() {
      _sourceTouched = true;
      _sourceId = source?.id;
      _sourceName = source?.name;
      _sourceIsCash = source?.isCash;
    });
  }

  @override
  void dispose() {
    _sourceSub?.cancel();
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Ada perubahan yang belum disimpan? Dipakai untuk mencegah form tertutup
  /// tanpa sengaja.
  bool get _hasChanges {
    final e = widget.existing;
    if (_saved) return false;
    return _title.text.trim() != (e?.title ?? '') ||
        _amountValue != (e?.amount ?? 0) ||
        _note.text.trim() != (e?.note ?? '') ||
        _type != (e?.type ?? TxType.expense) ||
        _category != (e?.category ?? _categories.first) ||
        _sourceId != e?.sourceId;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final model = TransactionModel(
      id: widget.existing?.id,
      title: _title.text.trim(),
      amount: _amountValue,
      type: _type,
      category: _category,
      date: _date,
      note: _note.text.trim(),
      sourceId: _sourceId,
      sourceName: _sourceName,
      sourceIsCash: _sourceIsCash,
    );

    try {
      if (_isEdit) {
        await _service.update(model);
      } else {
        await _service.add(model);
      }
      if (!mounted) return;
      setState(() => _saved = true);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buang perubahan?'),
        content: const Text('Perubahan yang belum disimpan akan hilang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Lanjut mengisi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Buang'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _type == TxType.income
        ? incomeColor(context)
        : expenseColor(context);
    final amount = _amountValue;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Navigator diambil sebelum await supaya tidak memakai BuildContext
        // setelah jeda async.
        final navigator = Navigator.of(context);
        final discard = await _confirmDiscard();
        if (discard && mounted) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'Ubah Transaksi' : 'Transaksi Baru')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<TxType>(
                segments: const [
                  ButtonSegment(
                    value: TxType.expense,
                    label: Text('Pengeluaran'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: TxType.income,
                    label: Text('Pemasukan'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _category = _categories.first;
                }),
              ),
              const SizedBox(height: 20),
              // Preview besar: langsung terlihat berapa yang dicatat.
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Rp ${thousandFmt.format(amount)}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: amount > 0 ? accent : cs.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Judul',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Judul wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [ThousandsInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Jumlah',
                  prefixText: 'Rp ',
                  helperText: 'Pemisah ribuan otomatis ditambahkan.',
                ),
                validator: (v) => ThousandsInputFormatter.parse(v ?? '') <= 0
                    ? 'Masukkan jumlah lebih dari 0'
                    : null,
              ),
              const SizedBox(height: 20),
              CategoryPicker(
                type: _type,
                selected: _category,
                onSelected: (category) =>
                    setState(() => _category = category),
              ),
              const SizedBox(height: 20),
              SourcePicker(
                sources: _sources,
                selectedId: _sourceId,
                onSelected: _selectSource,
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(dateFmt.format(_date)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Simpan Perubahan' : 'Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
