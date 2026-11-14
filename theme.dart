import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0B0B12);
  static const card = Color(0xFF161622);
  static const card2 = Color(0xFF1E1E2E);
  static const violet = Color(0xFF8B5CF6);
  static const pink = Color(0xFFEC4899);
  static const gold = Color(0xFFFBBF24);
}

const brandGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [AppColors.violet, AppColors.pink],
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.violet,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF10101A),
      indicatorColor: Color(0x408B5CF6),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: const Color(0x558B5CF6),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
