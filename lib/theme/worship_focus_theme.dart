import 'package:flutter/material.dart';

/// Modern Evergreen, shared with the planner's brand.css.
class WorshipFocusTheme {
  WorshipFocusTheme._();

  static const fontFamily = 'CMG Sans';
  static const forest = Color(0xFF245B4A);
  static const warmWhite = Color(0xFFF7F9F7);
  static const sage = Color(0xFFC4D6C8);
  static const ink = Color(0xFF293B35);
  static const stage = Color(0xFF111D18);
  static const stagePanel = Color(0xFF263B2F);

  static final light = _create(Brightness.light);
  static final dark = _create(Brightness.dark);

  static ThemeData _create(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF18271F) : Colors.white;
    final canvas = isDark ? stage : warmWhite;
    final colors =
        ColorScheme.fromSeed(
          seedColor: forest,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFFB7D7C3) : forest,
          onPrimary: isDark ? const Color(0xFF18342A) : Colors.white,
          primaryContainer: isDark
              ? const Color(0xFF354E3F)
              : const Color(0xFFE3EEE6),
          onPrimaryContainer: isDark ? const Color(0xFFE7EEE8) : forest,
          secondary: isDark ? sage : const Color(0xFF35644D),
          secondaryContainer: isDark
              ? const Color(0xFF354E3F)
              : const Color(0xFFE3EEE6),
          onSecondaryContainer: isDark ? const Color(0xFFE7EEE8) : forest,
          surface: surface,
          onSurface: isDark ? const Color(0xFFF1F3EC) : ink,
          onSurfaceVariant: isDark
              ? const Color(0xFFB7C6BC)
              : const Color(0xFF56685C),
          surfaceContainerLowest: canvas,
          surfaceContainerLow: isDark
              ? const Color(0xFF202E25)
              : const Color(0xFFEDF3EE),
          surfaceContainer: isDark
              ? const Color(0xFF223328)
              : const Color(0xFFF0F5F1),
          surfaceContainerHigh: isDark ? stagePanel : const Color(0xFFE3EEE6),
          surfaceContainerHighest: isDark
              ? const Color(0xFF354E3F)
              : const Color(0xFFD8E6DC),
          outline: isDark ? const Color(0xFF829789) : const Color(0xFF7B8C81),
          outlineVariant: isDark
              ? const Color(0xFF415248)
              : const Color(0xFFD9E1D5),
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final theme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: colors,
      scaffoldBackgroundColor: canvas,
      appBarTheme: AppBarThemeData(
        backgroundColor: surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: colors.outlineVariant)),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: shape.copyWith(side: BorderSide(color: colors.outlineVariant)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: canvas,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: colors.primary,
        selectedTileColor: colors.secondaryContainer,
        shape: shape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: colors.secondaryContainer,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
      ),
      dividerColor: colors.outlineVariant,
    );
    return theme.copyWith(
      textTheme: theme.textTheme.copyWith(
        headlineLarge: theme.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
