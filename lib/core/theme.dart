import 'package:flutter/material.dart';

/// Pure Black & White (Monochrome) Design System for BurePrint.
///
/// Strictly uses pure black (#000000), crisp whites (#FFFFFF),
/// and neutral shades of grey. Zero colors (no green, no blue, no red).
class BurePrintTheme {
  const BurePrintTheme._();

  // Primary monochromatic palette constants
  static const Color pureBlack = Color(0xFF000000);
  static const Color nearBlack = Color(0xFF121212);
  static const Color darkGrey = Color(0xFF1E1E1E);
  static const Color mediumDarkGrey = Color(0xFF2C2C2C);
  static const Color midGrey = Color(0xFF757575);
  static const Color borderGreyLight = Color(0xFFE0E0E0);
  static const Color borderGreyDark = Color(0xFF333333);
  static const Color surfaceGreyLight = Color(0xFFF9F9F9);
  static const Color surfaceGreyDark = Color(0xFF181818);
  static const Color pureWhite = Color(0xFFFFFFFF);

  /// Light Theme: Crisp pure white background, jet black text and accents.
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: pureBlack,
      onPrimary: pureWhite,
      secondary: nearBlack,
      onSecondary: pureWhite,
      error: pureBlack,
      onError: pureWhite,
      surface: pureWhite,
      onSurface: pureBlack,
      surfaceContainerHighest: surfaceGreyLight,
      outline: borderGreyLight,
      outlineVariant: Color(0xFFEEEEEE),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pureWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: pureWhite,
        foregroundColor: pureBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: pureBlack,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: pureBlack),
      ),
      cardTheme: CardThemeData(
        color: pureWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderGreyLight, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: pureWhite,
        indicatorColor: pureBlack,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: pureWhite);
          }
          return const IconThemeData(color: midGrey);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: pureBlack,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }
          return const TextStyle(
            color: midGrey,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pureBlack,
          foregroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pureBlack,
          side: const BorderSide(color: pureBlack, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderGreyLight,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Dark Theme: Jet black background, crisp pure white text and accents.
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: pureWhite,
      onPrimary: pureBlack,
      secondary: Color(0xFFE0E0E0),
      onSecondary: pureBlack,
      error: pureWhite,
      onError: pureBlack,
      surface: nearBlack,
      onSurface: pureWhite,
      surfaceContainerHighest: surfaceGreyDark,
      outline: borderGreyDark,
      outlineVariant: Color(0xFF242424),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pureBlack,
      appBarTheme: const AppBarTheme(
        backgroundColor: pureBlack,
        foregroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: pureWhite,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: pureWhite),
      ),
      cardTheme: CardThemeData(
        color: nearBlack,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderGreyDark, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: pureBlack,
        indicatorColor: pureWhite,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: pureBlack);
          }
          return const IconThemeData(color: midGrey);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: pureWhite,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }
          return const TextStyle(
            color: midGrey,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pureWhite,
          foregroundColor: pureBlack,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pureWhite,
          side: const BorderSide(color: pureWhite, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderGreyDark,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
