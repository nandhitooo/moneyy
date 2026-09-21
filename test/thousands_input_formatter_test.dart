import 'package:catatan_keuangan/utils/thousands_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final formatter = ThousandsInputFormatter();

  TextEditingValue typing(String text) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );

  group('ThousandsInputFormatter', () {
    test('menambahkan pemisah ribuan', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        typing('1234567'),
      );

      expect(result.text, '1.234.567');
      expect(ThousandsInputFormatter.parse(result.text), 1234567);
    });

    test('mengabaikan karakter selain digit', () {
      final result = formatter.formatEditUpdate(
        typing('1.234'),
        typing('1.234a5'),
      );

      expect(result.text, '12.345');
    });

    test('membuang nol di depan', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        typing('0005'),
      );

      expect(result.text, '5');
    });

    test('nilai kosong tetap kosong', () {
      final result = formatter.formatEditUpdate(typing('1'), typing(''));

      expect(result.text, '');
    });

    test('menolak digit melebihi batas', () {
      const oldValue = TextEditingValue();
      final tooLong = '1' * 16;

      final result = formatter.formatEditUpdate(oldValue, typing(tooLong));

      expect(result, oldValue);
    });

    test('parse membaca nol untuk input kosong', () {
      expect(ThousandsInputFormatter.parse(''), 0);
    });
  });
}
