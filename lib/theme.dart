import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand palette ─────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF7C6648);
  static const Color secondary = Color(0xFFE0D9CD);
  static const Color textColor = Color(0xFF464545);
  static const Color background = Color(0xFFF9F6F3);

  // Derived surface tones
  static const Color surface = background;
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF6F2EC);
  static const Color surfaceContainer = Color(0xFFF3EFE9);
  static const Color surfaceContainerHigh = Color(0xFFEFEAE4);
  static const Color surfaceContainerHighest = Color(0xFFEAE5DF);

  static const Color outline = Color(0xFFC8BFB5);
  static const Color outlineVariant = Color(0xFFDDD7CF);

  // Semantic colours (kept readable on warm backgrounds)
  static const Color successGreen = Color(0xFF3D7A5C);
  static const Color successGreenContainer = Color(0xFFD6EDE3);
  static const Color errorRed = Color(0xFFBA1A1A);
  static const Color errorRedContainer = Color(0xFFFFDAD6);
  static const Color warningOrange = Color(0xFF9E5A00);
  static const Color warningOrangeContainer = Color(0xFFFFDDB8);
  static const Color historySlate = Color(0xFF5B6D7A);
  static const Color historySlateContainer = Color(0xFFDDE6ED);

  // ── Theme ─────────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final base = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );

    final colorScheme = base.copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: secondary,
      onPrimaryContainer: textColor,
      secondary: const Color(0xFF9E8872),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFF0EAE2),
      onSecondaryContainer: textColor,
      tertiary: const Color(0xFF857360),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFEDE3D9),
      onTertiaryContainer: textColor,
      error: errorRed,
      onError: Colors.white,
      errorContainer: errorRedContainer,
      onErrorContainer: const Color(0xFF410002),
      surface: surface,
      onSurface: textColor,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      outline: outline,
      outlineVariant: outlineVariant,
      inverseSurface: textColor,
      onInverseSurface: background,
      inversePrimary: const Color(0xFFCFBDA7),
    );

    final textTheme = GoogleFonts.poppinsTextTheme().copyWith(
      displayLarge: GoogleFonts.poppins(color: textColor),
      displayMedium: GoogleFonts.poppins(color: textColor),
      displaySmall: GoogleFonts.poppins(color: textColor),
      headlineLarge: GoogleFonts.poppins(
          color: textColor, fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.poppins(
          color: textColor, fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.poppins(
          color: textColor, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.poppins(
          color: textColor, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.poppins(
          color: textColor, fontWeight: FontWeight.w500),
      titleSmall: GoogleFonts.poppins(
          color: textColor, fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.poppins(color: textColor),
      bodyMedium: GoogleFonts.poppins(color: textColor),
      bodySmall: GoogleFonts.poppins(
          color: Color(0xFF6B6A6A)),
      labelLarge: GoogleFonts.poppins(
          color: textColor, fontWeight: FontWeight.w500),
      labelMedium: GoogleFonts.poppins(color: textColor),
      labelSmall: GoogleFonts.poppins(
          color: Color(0xFF6B6A6A), letterSpacing: 0.5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,

      // ── AppBar ─────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Colors.black.withValues(alpha:0.08),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.poppins(
          color: textColor,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: const IconThemeData(color: textColor),
        actionsIconTheme: const IconThemeData(color: textColor),
      ),

      // ── Bottom Navigation Bar ──────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceContainerLowest,
        selectedItemColor: primary,
        unselectedItemColor: textColor.withValues(alpha:0.42),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
        showUnselectedLabels: true,
      ),

      // ── Cards ──────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: outlineVariant),
        ),
      ),

      // ── Filled Buttons ─────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: outline.withValues(alpha:0.5),
          textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(double.infinity, 50),
        ),
      ),

      // ── Elevated Buttons ───────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: outline.withValues(alpha:0.4),
          elevation: 0,
          textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500, fontSize: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),

      // ── Outlined Buttons ───────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500, fontSize: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),

      // ── Text Buttons ───────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // ── Input fields ───────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 1.8),
        ),
        labelStyle: GoogleFonts.poppins(
            color: Color(0xFF8A8585), fontSize: 14),
        hintStyle: GoogleFonts.poppins(
            color: Color(0xFFB0ACAC), fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        isDense: true,
      ),

      // ── Chips ──────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: secondary,
        selectedColor: primary,
        labelStyle: GoogleFonts.poppins(
            color: textColor, fontSize: 12),
        secondaryLabelStyle: GoogleFonts.poppins(
            color: Colors.white, fontSize: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      // ── Dividers ───────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ── Switch ─────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha:0.35);
          }
          return null;
        }),
      ),

      // ── FAB ────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),

      // ── Progress indicators ────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: outlineVariant,
      ),

      // ── Snack bars ─────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2E2C2C),
        contentTextStyle: GoogleFonts.poppins(
            color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        elevation: 4,
      ),

      // ── Dialogs ────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.poppins(
          color: textColor,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GoogleFonts.poppins(
            color: textColor, fontSize: 14),
      ),

      // ── Bottom sheets ──────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // ── List tiles ─────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: primary,
      ),

      // ── Icon ───────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(color: textColor),
    );
  }
}
