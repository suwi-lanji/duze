import 'package:flutter/material.dart';

class AppColors {


  // Primary gradient colors
  static const Color gradientStart = Color(0xFF64B5F6); // Soft sky blue
  static const Color gradientEnd = Color(0xFF81C784); // Gentle green

 // Accent Colors
  static const Color accentPeach = Color(0xFFFF8A65); // Warm peach for accents
  static const Color accentCyan = Color(0xFF4DD0E1); // Brighter cyan

  // 🌈 Primary gradient colors
  static const Color teal = Color(0xFF00BFA6); // Deeper modern turquoise
  
  static const Color primaryTeal =  Color(0xff3e4784); // Light cyan for accents

  // 🔷 Accent colors for social and callouts
  static const Color facebookBlue = Color(0xFF1877F2); // Updated Facebook brand blue
  static const Color twitterBlue = Color(0xFF1DA1F2); // Twitter/X brand color
  static const Color tiktokBlack = Color(0xFF010101); // Real black for TikTok
  static const Color accentRed = Color(0xFFFF4C4C); // Stronger red for error/mood
  static const Color accentYellow = Color(0xFFFFD740); // Modern warm amber
  static const Color accentTeal = Color(0xFF00ACC1); // Deep button teal

  // ⚪ Neutrals for text and background
  static const Color primaryDark =  Color(0xfff2f9fe);
  static const Color primaryLight = Color(0xfff2f9fe);
  
   




static const Color primary = Color(0xfff2f9fe);
static const Color secondary = Color(0xFFdbe4f3);
static const Color black = Color(0xFF000000);
static const Color white = Color(0xFFFFFFFF);
static const Color grey = Colors.grey;
static const Color red = Color(0xFFec5766);
static const Color green = Color(0xFF43aa8b);
static const Color blue = Color(0xFF28c2ff);
static const Color buttoncolor = Color(0xff3e4784);
static const Color mainFontColor = Color(0xff565c95);
static const Color arrowbgColor = Color(0xffe4e9f7);

  static const Color textPrimary =  Color(0xFF607D8B);
  static const Color textSecondary = Color(0xFF607D8B); // Blue-grey for secondary text
  static const Color textDark = Color(0xFF263238); // Almost black for light bg
 
  static const Color grey600 = Color(0xFFB0BEC5); // Lighter blue-gray
  static const Color blue600 = Color(0xFF1E88E5); // More vibrant blue
 


 // Neutrals
  static const Color backgroundLight = primary;
  static const Color backgroundDark = primary;

  static const Color textLight = Color(0xff565c95);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1E1E1E);


  // ✨ Glassmorphic effects
  static const Color glassBackground = Color(0xFFFFFFFF);
  static const Color glassBorder = Color(0xFFFFFFFF); // Light translucent border
  static const Color border = Color(0xFFFFFFFF);// Light translucent border

  // 🎨 Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [teal, green],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient profileGradient = LinearGradient(
    colors: [Color(0xfff2f9fe), Color(0xfff2f9fe)],
    begin: Alignment.topCenter,
    end: Alignment.centerLeft,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [buttoncolor, buttoncolor],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Color iconLight =  Color(0x1AFFFFFF);

  static const shadow =   Color(0xFFFFFFFF); // Light translucent border ;

  // 🌓 Theme-based dynamic colors
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? primaryDark : primaryLight;
  }

  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textPrimary : textDark;
  }

  static Color getAccentColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? accentTeal : primaryTeal;
  }
}


