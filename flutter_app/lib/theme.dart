import 'package:flutter/material.dart';

ThemeData buildTitanTheme() {
  const primary = Color(0xFFCCFF00);
  const background = Color(0xFF0A0A0A);
  const accent = Color(0xFF6200EA);

  return ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'SF Pro Display',
    primaryColor: primary,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: accent,
      background: background,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: -0.5),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(fontSize: 16),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF151515),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF141414),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      selectedColor: Color(0xFF2A2A2A),
      labelStyle: TextStyle(color: Colors.white),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'SF Pro Display',
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    useMaterial3: true,
  );
}
