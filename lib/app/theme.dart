import 'package:flutter/material.dart';
import '../frontend/modules/shared/senior_styles.dart';

class SeniorSyncTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: SeniorStyles.primaryBlue,
      scaffoldBackgroundColor: SeniorStyles.backgroundGray,
      colorScheme: ColorScheme.fromSeed(
        seedColor: SeniorStyles.primaryBlue,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: false,
        titleTextStyle: SeniorStyles.header,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: SeniorStyles.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SeniorStyles.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: const TextStyle(fontSize: 18),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: Colors.white,
        indicatorColor: SeniorStyles.primaryBlue.withOpacity(0.1),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
