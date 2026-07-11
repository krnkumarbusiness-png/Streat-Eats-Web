import 'package:flutter/material.dart';
import 'colors.dart';

class AppStyles {
  // ── Screen Titles ──────────────────────────────────────────
  static const TextStyle screenTitle = TextStyle(
    fontSize: 20, // 24 → 20
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFamily: 'Poppins',
    letterSpacing: -0.5,
  );

  // ── Section Headers ────────────────────────────────────────
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 15, // 18 → 15
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFamily: 'Poppins',
    letterSpacing: -0.3,
  );

  // ── Card Titles ────────────────────────────────────────────
  static const TextStyle cardTitle = TextStyle(
    fontSize: 13, // 15 → 13
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFamily: 'Poppins',
  );

  // ── Body Text ──────────────────────────────────────────────
  static const TextStyle bodyText = TextStyle(
    fontSize: 12, // 14 → 12
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    fontFamily: 'Poppins',
    height: 1.5,
  );

  // ── Price Text ─────────────────────────────────────────────
  static const TextStyle priceText = TextStyle(
    fontSize: 14, // 16 → 14
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    fontFamily: 'Poppins',
  );

  // ── Label / Tag Text ───────────────────────────────────────
  static const TextStyle labelText = TextStyle(
    fontSize: 10, // 11 → 10
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    fontFamily: 'Poppins',
    letterSpacing: 0.8,
  );

  // ── Hint Text ──────────────────────────────────────────────
  static const TextStyle hintText = TextStyle(
    fontSize: 13, // 14 → 13
    fontWeight: FontWeight.normal,
    color: AppColors.textMuted,
    fontFamily: 'Poppins',
  );

  // ── Button Text ────────────────────────────────────────────
  static const TextStyle buttonText = TextStyle(
    fontSize: 14, // 16 → 14
    fontWeight: FontWeight.w700,
    color: Colors.white,
    fontFamily: 'Poppins',
    letterSpacing: 0.3,
  );

  // ── Input Field Decoration ─────────────────────────────────
  static InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: hintText,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
    );
  }

  // ── Primary Button Style ───────────────────────────────────
  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    ),
    padding: const EdgeInsets.symmetric(vertical: 14),
    textStyle: buttonText,
  );

  // ── Card Decoration ────────────────────────────────────────
  static BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border, width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
