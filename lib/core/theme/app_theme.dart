import 'package:flutter/material.dart';

/// GreenSync design tokens. Every screen takes its colours from here,
/// so the marketplace and waste-collection screens share one look.
class AppColors {
  static const forest = Color(0xFF0F5E5A);
  static const cream = Color(0xFFF1F8F6);
  static const sand = Color(0xFFF2994A);
  static const sandSoft = Color(0x33F2994A); // accent at 20% opacity
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFD3E5E1);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.forest,
          primary: AppColors.forest,
          secondary: AppColors.sand,
          surface: AppColors.cream,
        ),
        scaffoldBackgroundColor: AppColors.cream,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.sandSoft,
        ),
      );
}

/// Shared text-field look. Use for every form field in the app.
InputDecoration appInput(String label, {String? hint, Widget? suffix}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.surface,
    border: border(AppColors.line, 1),
    enabledBorder: border(AppColors.line, 1),
    focusedBorder: border(AppColors.forest, 2),
  );
}
