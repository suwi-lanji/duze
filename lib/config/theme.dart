import 'dart:ui';

import 'package:duze/shared/widgets/app_colors.dart';
import 'package:flutter/material.dart';


class AppTheme {
  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color secondaryColor = Color(0xFFA29BFE);
  static const Color accentColor = Color(0xFFFF8A65); // new peach coral

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      background: AppColors.backgroundLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      color: AppColors.cardLight,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: AppColors.glassBorder,
          width: 1,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gradientStart,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
    ),
    textTheme:TextTheme(
          displayLarge: TextStyle(color: AppColors.mainFontColor),
          displayMedium: TextStyle(color: AppColors.mainFontColor),
          displaySmall: TextStyle(color: AppColors.mainFontColor),
          headlineLarge: TextStyle(color: AppColors.mainFontColor),
          headlineMedium: TextStyle(color: AppColors.mainFontColor),
          headlineSmall: TextStyle(color: AppColors.mainFontColor),
          titleLarge: TextStyle(color: AppColors.mainFontColor),
          titleMedium: TextStyle(color: AppColors.mainFontColor),
          titleSmall: TextStyle(color: AppColors.mainFontColor),
          bodyLarge: TextStyle(color: AppColors.mainFontColor),
          bodyMedium: TextStyle(color: AppColors.mainFontColor),
          bodySmall: TextStyle(color: AppColors.mainFontColor),
          labelLarge: TextStyle(color: AppColors.mainFontColor),
          labelMedium: TextStyle(color: AppColors.mainFontColor),
          labelSmall: TextStyle(color: AppColors.mainFontColor),
        ).apply(fontFamily: 'Poppins'),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.backgroundDark,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      background: AppColors.backgroundDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.backgroundDark,
      foregroundColor: AppColors.textLight,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      color: AppColors.cardDark,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: AppColors.glassBorder,
          width: 1,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentCyan,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
    ),
  );
}
