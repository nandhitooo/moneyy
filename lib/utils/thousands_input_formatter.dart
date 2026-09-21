import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Menampilkan pemisah ribuan saat mengetik, misal `1234567` menjadi
/// `1.234.567`. Hanya digit yang disimpan di dalam text field.
class ThousandsInputFormatter extends TextInputFormatter {
  ThousandsInputFormatter({this.maxDigits = 15})
      : _format = NumberFormat.decimalPattern('id_ID');

  /// Batas jumlah digit, mencegah nilai melebihi kapasitas `int`.
  final int maxDigits;

  final NumberFormat _format;

  static final _nonDigit = RegExp(r'[^0-9]');
  static final _digit = RegExp(r'[0-9]');
  static final _leadingZeros = RegExp(r'^0+(?=[0-9])');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(_nonDigit, '');
    if (digits.length > maxDigits) return oldValue;
    if (digits.isEmpty) return const TextEditingValue();

    final normalized = digits.replaceFirst(_leadingZeros, '');
    final formatted = _format.format(int.parse(normalized));

    // Kursor diletakkan mengikuti jumlah digit di sebelah kirinya agar
    // pengeditan di tengah angka tidak melompat ke akhir.
    final caretText = newValue.text.substring(
      0,
      newValue.selection.baseOffset.clamp(0, newValue.text.length),
    );
    final digitsBeforeCaret = caretText.replaceAll(_nonDigit, '').length;

    var offset = formatted.length;
    if (digitsBeforeCaret < normalized.length) {
      offset = 0;
      var seen = 0;
      for (var i = 0; i < formatted.length; i++) {
        if (_digit.hasMatch(formatted[i])) {
          seen++;
          if (seen == digitsBeforeCaret) {
            offset = i + 1;
            break;
          }
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  /// Mengambil nilai integer dari teks yang sudah berformat.
  static int parse(String text) =>
      int.tryParse(text.replaceAll(_nonDigit, '')) ?? 0;
}
