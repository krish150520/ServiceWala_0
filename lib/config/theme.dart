import 'package:flutter/material.dart';

/// ServiceWala Design System - Unified Theme & Constants
/// Matches the Customer App visual reference:
/// Clean White Background, Cobalt Blue (#0047FF), Dark Navy (#111827),
/// Slate Grey (#475569), Muted Grey (#94A3B8), Soft Grey Cards (#F8FAFC),
/// and Subtle Borders (#E2E8F0).
class AppColors {
  // Primary Blue Brand Palette
  static const Color primary = Color(0xFF0047FF);
  static const Color primaryLight = Color(0xFFEBF1FF);
  static const Color primaryDark = Color(0xFF0039CC);
  static const Color secondary = Color(0xFF0047FF);
  static const Color secondaryLight = Color(0xFFEBF1FF);

  // Backgrounds & Surfaces (matching reference clean white & soft grey)
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundGrey = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceCard = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFF1F5F9);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF111827); // Dark navy headings (#111827)
  static const Color textSecondary = Color(0xFF475569); // Slate grey body (#475569)
  static const Color textMuted = Color(0xFF94A3B8); // Muted grey placeholders (#94A3B8)
  static const Color textHint = Color(0xFF94A3B8);

  // Status & Feedback
  static const Color success = Color(0xFF16A34A); // Success green (#16A34A)
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color error = Color(0xFFDC2626); // Error red (#DC2626)
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0047FF);
  static const Color infoLight = Color(0xFFEBF1FF);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);

  // Misc & Accents
  static const Color border = Color(0xFFE2E8F0); // Subtle border (#E2E8F0)
  static const Color divider = Color(0xFFE2E8F0);
  static const Color online = Color(0xFF16A34A);
  static const Color offline = Color(0xFF94A3B8);

  // Category Squircle Pastel Backgrounds (matching Customer App Reference)
  static const Color catElectricianBg = Color(0xFFE6F9EE);
  static const Color catElectricianIcon = Color(0xFF16A34A);

  static const Color catPlumberBg = Color(0xFFE0F7FA);
  static const Color catPlumberIcon = Color(0xFF00ACC1);

  static const Color catCarpenterBg = Color(0xFFFFF3E0);
  static const Color catCarpenterIcon = Color(0xFFD97706);

  static const Color catAcBg = Color(0xFFE1F5FE);
  static const Color catAcIcon = Color(0xFF0288D1);

  static const Color catVehicleBg = Color(0xFFFCE4EC);
  static const Color catVehicleIcon = Color(0xFFD81B60);

  static const Color catPainterBg = Color(0xFFF3E8FF);
  static const Color catPainterIcon = Color(0xFF9333EA);

  static const Color catCleaningBg = Color(0xFFEBF8FF);
  static const Color catCleaningIcon = Color(0xFF3182CE);

  // Precision Partner Suite (Stitch Design Tokens)
  static const Color stitchSurface = Color(0xFFFAF8FF);
  static const Color stitchSurfaceDim = Color(0xFFD2D9F4);
  static const Color stitchSurfaceBright = Color(0xFFFAF8FF);
  static const Color stitchSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color stitchSurfaceContainerLow = Color(0xFFF2F3FF);
  static const Color stitchSurfaceContainer = Color(0xFFEAEDFF);
  static const Color stitchSurfaceContainerHigh = Color(0xFFE2E7FF);
  static const Color stitchSurfaceContainerHighest = Color(0xFFDAE2FD);
  static const Color stitchOnSurface = Color(0xFF131B2E);
  static const Color stitchOnSurfaceVariant = Color(0xFF434655);
  static const Color stitchInverseSurface = Color(0xFF283044);
  static const Color stitchInverseOnSurface = Color(0xFFEEF0FF);
  static const Color stitchOutline = Color(0xFF747687);
  static const Color stitchOutlineVariant = Color(0xFFC4C5D8);
  static const Color stitchSurfaceTint = Color(0xFF184CE9);
  static const Color stitchPrimary = Color(0xFF0032B0);
  static const Color stitchPrimaryContainer = Color(0xFF0A46E4);
  static const Color stitchPrimaryCobalt = Color(0xFF0A46E4);
  static const Color stitchOnPrimaryContainer = Color(0xFFC6CEFF);
  static const Color stitchPrimaryFixed = Color(0xFFDDE1FF);
  static const Color stitchPrimaryFixedDim = Color(0xFFB8C4FF);
  static const Color stitchOnPrimaryFixed = Color(0xFF001354);
  static const Color stitchOnPrimaryFixedVariant = Color(0xFF0036BB);
  static const Color stitchSecondary = Color(0xFF00668A);
  static const Color stitchSecondaryFixed = Color(0xFFC4E7FF);
  static const Color stitchTertiary = Color(0xFF004D33);
  static const Color stitchTertiaryFixed = Color(0xFF6FFBBE);
  static const Color stitchTertiaryFixedDim = Color(0xFF4EDEA3);
  static const Color stitchOnTertiaryFixed = Color(0xFF002113);
  static const Color stitchOnTertiaryFixedVariant = Color(0xFF005236);
  static const Color stitchTertiaryBg = Color(0xFFECFDF5);
}

class AppTextStyles {
  static const TextStyle headingLarge = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.25,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.1,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: AppColors.surface,
        error: AppColors.error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
          size: 22,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border, width: 0.8),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTextStyles.button.copyWith(color: AppColors.textPrimary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        prefixIconColor: AppColors.textMuted,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.8,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedColor: AppColors.primaryLight,
        labelStyle: AppTextStyles.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        side: const BorderSide(color: AppColors.border, width: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}
