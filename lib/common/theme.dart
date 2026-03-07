import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP THEME
// Central place for all colors, text styles, input decorations,
// button styles, box decorations and spacing used across the app.
// Import this file in any page: import 'theme.dart';
// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._(); // prevent instantiation

  // ── MaterialApp ThemeData ──────────────────────────────────────────────────
  static ThemeData get themeData => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// COLORS
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Brand
  static const Color primary       = Color(0xFF1558E7);
  static const Color primaryDark   = Color(0xFF0636A8);
  static const Color primaryLight  = Color(0xFFEEF4FF);
  static const Color primaryAccent = Color(0xFFAAD4FF);

  // Backgrounds
  static const Color background    = Color(0xFFF8FAFF);
  static const Color surface       = Colors.white;
  static const Color inputFill     = Color(0xFFF5F7FA);

  // Text
  static const Color textPrimary   = Color(0xFF0A0F1E);
  static const Color textSecondary = Color(0xFF8A96AE);
  static const Color textHint      = Color(0xFFBBC4D6);
  static const Color textLabel     = Color(0xFF64718A);
  static const Color textMuted     = Color(0xFFB0BACC);

  // Border
  static const Color border        = Color(0xFFDDE3EF);
  static const Color borderLight   = Color(0xFFEEF2FA);

  // Status
  static const Color success       = Color(0xFF2F855A);
  static const Color successBg     = Color(0xFFEAFAF1);
  static const Color error         = Color(0xFFE53E3E);

  // Icon
  static const Color iconDefault   = Color(0xFFA0ABBE);
  static const Color iconMuted     = Color(0xFF9AA5B8);
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT STYLES
// ─────────────────────────────────────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  // Headlines
  static TextStyle headline(bool isTablet) => TextStyle(
        color: AppColors.textPrimary,
        fontSize: isTablet ? 26 : 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      );

  static TextStyle heroHeadline(bool isTablet) => TextStyle(
        color: Colors.white,
        fontSize: isTablet ? 26 : 22,
        fontWeight: FontWeight.w800,
        height: 1.25,
        letterSpacing: -0.4,
      );

  static TextStyle heroAccent(bool isTablet) => TextStyle(
        color: AppColors.primaryAccent,
        fontSize: isTablet ? 26 : 22,
        fontWeight: FontWeight.w800,
        height: 1.25,
        letterSpacing: -0.4,
      );

  // Body
  static TextStyle subtitle(bool isTablet) => TextStyle(
        color: AppColors.textSecondary,
        fontSize: isTablet ? 14.5 : 13.5,
      );

  static TextStyle heroSubtitle(bool isTablet) => TextStyle(
        color: Colors.white.withOpacity(0.72),
        fontSize: isTablet ? 14 : 13,
        height: 1.65,
        letterSpacing: 0.1,
      );

  static TextStyle body(bool isTablet) => TextStyle(
        color: AppColors.textPrimary,
        fontSize: isTablet ? 15.5 : 14.5,
        fontWeight: FontWeight.w500,
      );

  // Labels
  static TextStyle fieldLabel(bool isTablet) => TextStyle(
        color: AppColors.textLabel,
        fontSize: isTablet ? 11 : 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      );

  static TextStyle hint(bool isTablet) => TextStyle(
        color: AppColors.textHint,
        fontSize: isTablet ? 15 : 14,
        fontWeight: FontWeight.w400,
      );

  // Brand
  static TextStyle brandCore(bool isTablet) => TextStyle(
        color: AppColors.textPrimary,
        fontSize: isTablet ? 22 : 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      );

  static TextStyle brandMicron(bool isTablet) => TextStyle(
        color: AppColors.primary,
        fontSize: isTablet ? 22 : 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      );

  // Links
  static TextStyle link(bool isTablet) => TextStyle(
        color: AppColors.primary,
        fontSize: isTablet ? 13.5 : 12.5,
        fontWeight: FontWeight.w600,
      );

  // Footer
  static const TextStyle footer = TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        letterSpacing: 0.2,
      );

  // Button
  static TextStyle button(bool isTablet) => TextStyle(
        fontSize: isTablet ? 16.5 : 15.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: Colors.white,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DECORATIONS
// ─────────────────────────────────────────────────────────────────────────────

class AppDecorations {
  AppDecorations._();

  // ── Input field (idle) ─────────────────────────────────────────────────────
  static BoxDecoration inputIdle = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.border, width: 1.2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // ── Input field (focused) ──────────────────────────────────────────────────
  static BoxDecoration inputFocused = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.primary, width: 1.8),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withOpacity(0.10),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // ── Card (white surface) ───────────────────────────────────────────────────
  static BoxDecoration card = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppColors.borderLight, width: 1.2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // ── Hero gradient card ─────────────────────────────────────────────────────
  static BoxDecoration heroCard = BoxDecoration(
    borderRadius: BorderRadius.circular(24),
    gradient: const LinearGradient(
      colors: [AppColors.primary, AppColors.primaryDark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withOpacity(0.38),
        blurRadius: 36,
        offset: const Offset(0, 16),
        spreadRadius: -4,
      ),
    ],
  );

  // ── Logo container ─────────────────────────────────────────────────────────
  static BoxDecoration logoBox(bool isTablet) => BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// BUTTON STYLES
// ─────────────────────────────────────────────────────────────────────────────

class AppButtonStyles {
  AppButtonStyles._();

  static ButtonStyle primary = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.primary.withOpacity(0.45),
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    ),
  );

  static ButtonStyle outline = OutlinedButton.styleFrom(
    side: const BorderSide(color: AppColors.border, width: 1.2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    ),
    backgroundColor: AppColors.surface,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SPACING
// ─────────────────────────────────────────────────────────────────────────────

class AppSpacing {
  AppSpacing._();

  static double horizontalPadding(bool isTablet, double screenWidth) =>
      isTablet ? screenWidth * 0.14 : 24.0;

  static double topPadding(bool isTablet)    => isTablet ? 56 : 40;
  static double sectionGap(bool isTablet)    => isTablet ? 40 : 30;
  static double fieldGap(bool isTablet)      => isTablet ? 18 : 14;
  static double buttonHeight(bool isTablet)  => isTablet ? 56 : 52;
  static double logoSize(bool isTablet)      => isTablet ? 46 : 40;
  static double logoIconSize(bool isTablet)  => isTablet ? 24 : 21;
}

// ─────────────────────────────────────────────────────────────────────────────
// SNACKBAR HELPER
// ─────────────────────────────────────────────────────────────────────────────

class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}