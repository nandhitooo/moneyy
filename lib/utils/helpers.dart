import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/funding_source.dart';

final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final thousandFmt = NumberFormat.decimalPattern('id_ID');
final dateFmt = DateFormat('d MMM yyyy', 'id_ID');
final monthFmt = DateFormat('MMMM yyyy', 'id_ID');

/// Warna pemasukan/pengeluaran yang tetap kontras di light dan dark mode.
Color incomeColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.green.shade400
        : Colors.green.shade700;

Color expenseColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.red.shade400
        : Colors.red.shade700;

/// Ringkas pesan error supaya bisa ditampilkan di layar dan disalin pengguna.
/// [maxLength] dibuat lega supaya tautan pembuatan index dari Firestore tidak
/// ikut terpotong.
String errorDetail(Object error, {int maxLength = 400}) {
  final String text;
  if (error is FirebaseException) {
    final message = (error.message ?? '').split('\n').first.trim();
    text = message.isEmpty ? error.code : '${error.code}: $message';
  } else {
    text = error.toString().replaceFirst('Exception: ', '').trim();
  }
  return text.length > maxLength ? '${text.substring(0, maxLength)}…' : text;
}

/// Ikon sumber dana: uang tunai atau non-tunai (bank / e-wallet).
IconData sourceIcon(FundingSource source) => source.isCash
    ? Icons.payments_outlined
    : Icons.account_balance_wallet_outlined;

IconData categoryIcon(String category) {
  switch (category) {
    case 'Makanan':
      return Icons.restaurant;
    case 'Transportasi':
      return Icons.directions_car;
    case 'Belanja':
      return Icons.shopping_bag;
    case 'Tagihan':
      return Icons.receipt_long;
    case 'Hiburan':
      return Icons.movie;
    case 'Kesehatan':
      return Icons.favorite;
    case 'Pendidikan':
      return Icons.school;
    case 'Gaji':
      return Icons.payments;
    case 'Bonus':
      return Icons.card_giftcard;
    case 'Usaha':
      return Icons.storefront;
    case 'Investasi':
      return Icons.trending_up;
    case 'Hadiah':
      return Icons.redeem;
    default:
      return Icons.category;
  }
}
