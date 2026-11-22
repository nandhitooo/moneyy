import 'package:material_ui/material_ui.dart';

/// Tema aplikasi: satu palet tenang, permukaan datar, dan garis tipis.
///
/// Arah desainnya minimalis: tidak ada bayangan, tidak ada blok warna besar,
/// dan warna aksen hanya dipakai untuk angka serta aksi penting. Semua radius
/// dan gaya komponen diatur di sini supaya tidak ada layar yang menulis ulang
/// gayanya sendiri.
class AppTheme {
  const AppTheme._();

  static const double radiusInput = 16;
  static const double radiusCard = 20;
  static const double radiusChip = 999;

  /// Hijau tua: satu-satunya warna aksen aplikasi.
  static const Color seed = Color(0xFF0F766E);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final cs = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final baseText =
        ThemeData(useMaterial3: true, brightness: brightness).textTheme;
    // Isian kolom sedikit lebih gelap dari latar, tanpa garis luar sama sekali.
    final fill =
        cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.5);

    final textTheme = baseText.copyWith(
      headlineMedium: baseText.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8),
      headlineSmall: baseText.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleLarge: baseText.titleLarge
          ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleMedium: baseText.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.1),
      titleSmall: baseText.titleSmall
          ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.35),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: textTheme,
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarThemeData(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: fill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder(Colors.transparent, 0),
        enabledBorder: inputBorder(Colors.transparent, 0),
        focusedBorder: inputBorder(cs.primary, 1.5),
        errorBorder: inputBorder(cs.error),
        focusedErrorBorder: inputBorder(cs.error, 1.5),
        prefixIconColor: cs.onSurfaceVariant,
        suffixIconColor: cs.onSurfaceVariant,
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: isDark ? cs.surfaceContainerLow : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor:
            isDark ? cs.surfaceContainerHigh : cs.surfaceContainerHighest,
        selectedColor: cs.primary.withValues(alpha: 0.12),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        showCheckmark: false,
      ),
      listTileTheme: ListTileThemeData(iconColor: cs.onSurfaceVariant),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? cs.surfaceContainerLow : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          elevation: 0,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInput),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: cs.outlineVariant),
          foregroundColor: cs.onSurface,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInput),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        highlightElevation: 0,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        extendedTextStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: cs.primary),
    );
  }
}
