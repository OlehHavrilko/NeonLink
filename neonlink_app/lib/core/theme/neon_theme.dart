import 'package:flutter/material.dart';

class NeonTheme {
  // Cyberpunk Color Palette
  static const primary = Color(0xFF00F0FF);      // Neon Cyan
  static const secondary = Color(0xFFFF00AA);    // Neon Magenta
  static const accent = Color(0xFFFFD700);       // Gold
  static const background = Color(0xFF0A0E1A);   // Deep Dark Blue
  static const surface = Color(0xFF1A1F35);      // Dark Slate
  static const text = Color(0xFFE0E0E0);         // Off-White
  
  // OLED
  static const oledBlack = Color(0xFF000000);
  
  // Status zones
  static const safe = Color(0xFF00FF88);
  static const warning = Color(0xFFFFB800);
  static const critical = Color(0xFFFF3366);

  final bool isOLEDMode;

  const NeonTheme({this.isOLEDMode = false});

  NeonTheme copyWith({bool? isOLEDMode}) {
    return NeonTheme(isOLEDMode: isOLEDMode ?? this.isOLEDMode);
  }

  Color get effectiveBackground => isOLEDMode ? oledBlack : background;

  static final darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      tertiary: accent,
      surface: surface,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: text,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      titleTextStyle: TextStyle(
        fontSize: 20,
        color: primary,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
    ),
  );

  static final lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: secondary,
      tertiary: accent,
      surface: Colors.grey[100]!,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: Colors.black,
    ),
    scaffoldBackgroundColor: Colors.white,
  );
}
