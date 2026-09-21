import 'package:cloud_firestore/cloud_firestore.dart';

enum TxType { income, expense }

const expenseCategories = [
  'Makanan',
  'Transportasi',
  'Belanja',
  'Tagihan',
  'Hiburan',
  'Kesehatan',
  'Pendidikan',
  'Lainnya',
];

const incomeCategories = [
  'Gaji',
  'Bonus',
  'Usaha',
  'Investasi',
  'Hadiah',
  'Lainnya',
];

class TransactionModel {
  final String? id;
  final String title;
  final int amount; // dalam Rupiah, disimpan sebagai integer
  final TxType type;
  final String category;
  final DateTime date;
  final String note;

  /// Sumber dana (tunai, rekening bank, e-wallet). Boleh kosong untuk
  /// transaksi lama yang dibuat sebelum fitur ini ada.
  final String? sourceId;
  final String? sourceName;

  /// Disalin saat transaksi dibuat: true bila sumbernya uang tunai.
  final bool? sourceIsCash;

  const TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note = '',
    this.sourceId,
    this.sourceName,
    this.sourceIsCash,
  });

  /// Membaca dokumen Firestore dengan nilai cadangan agar satu dokumen rusak
  /// tidak membuat seluruh daftar gagal dimuat.
  factory TransactionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return TransactionModel(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      type: d['type'] == 'income' ? TxType.income : TxType.expense,
      category: (d['category'] as String?) ?? 'Lainnya',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: (d['note'] as String?) ?? '',
      sourceId: d['sourceId'] as String?,
      sourceName: d['sourceName'] as String?,
      sourceIsCash: d['sourceIsCash'] as bool?,
    );
  }

  bool get isIncome => type == TxType.income;

  /// Dampak ke saldo: pemasukan menambah, pengeluaran mengurangi.
  int get signedAmount => isIncome ? amount : -amount;

  TransactionModel copyWith({String? id}) => TransactionModel(
        id: id ?? this.id,
        title: title,
        amount: amount,
        type: type,
        category: category,
        date: date,
        note: note,
        sourceId: sourceId,
        sourceName: sourceName,
        sourceIsCash: sourceIsCash,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'amount': amount,
        'type': type == TxType.income ? 'income' : 'expense',
        'category': category,
        'date': Timestamp.fromDate(date),
        'note': note,
        // Dipakai agregasi saldo supaya cukup satu field: tanpa ini setiap
        // query butuh composite index `type + date` atau `sourceId + type`.
        'signedAmount': signedAmount,
        'sourceId': sourceId,
        'sourceName': sourceName,
        'sourceIsCash': sourceIsCash,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
