import 'package:catatan_keuangan/config/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThemeController', () {
    test('mulai dengan mengikuti tema sistem', () {
      final controller = ThemeController();

      expect(controller.value, ThemeMode.system);
      expect(controller.isDark, isFalse);
    });

    test('setDark(true) memilih tema gelap', () {
      final controller = ThemeController();

      controller.setDark(true);

      expect(controller.value, ThemeMode.dark);
      expect(controller.isDark, isTrue);
    });

    test('setDark(false) memilih tema terang, bukan kembali ke sistem', () {
      final controller = ThemeController();

      controller.setDark(false);

      expect(controller.value, ThemeMode.light);
      expect(controller.isDark, isFalse);
    });

    test('memberi tahu pendengar setiap kali mode berubah', () {
      final controller = ThemeController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setDark(true);
      controller.setDark(false);

      expect(notifications, 2);
      expect(controller.value, ThemeMode.light);
    });

    test('instance dipakai bersama seluruh aplikasi', () {
      expect(identical(ThemeController.instance, ThemeController.instance), isTrue);
    });
  });
}
