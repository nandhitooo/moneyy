import 'package:flutter/material.dart';

/// Mode tema aplikasi, satu sumber untuk seluruh app.
///
/// Hanya disimpan di memori: project ini belum memakai penyimpanan lokal, jadi
/// pilihan pengguna kembali mengikuti tema sistem setiap aplikasi dijalankan
/// ulang.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([super.value = ThemeMode.system]);

  /// Instance yang dipakai [MaterialApp] dan diubah sakelar tema di AppBar.
  static final ThemeController instance = ThemeController();

  /// True bila pengguna pernah memilih tema gelap secara eksplisit.
  ///
  /// [ThemeMode.system] tidak dihitung gelap walau sistemnya gelap; status yang
  /// terlihat di UI dibaca dari `Theme.of(context).brightness` supaya sakelar
  /// menampilkan keadaan sebenarnya sejak awal.
  bool get isDark => value == ThemeMode.dark;

  /// Mengikuti posisi sakelar: nyala berarti tema gelap dipilih eksplisit.
  void setDark(bool dark) => value = dark ? ThemeMode.dark : ThemeMode.light;
}
