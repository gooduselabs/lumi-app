import 'package:flutter/material.dart';

/// Lumi palette: deep night background with a violet -> pink "glow".
abstract final class AppColors {
  static const bg = Color(0xFF0B0816);
  static const bgElevated = Color(0xFF130E24);
  static const surface = Color(0xFF1A1430);
  static const surfaceHigh = Color(0xFF241C40);
  static const stroke = Color(0x22FFFFFF);

  static const violet = Color(0xFF7C5CFF);
  static const pink = Color(0xFFFF5CA8);
  static const cyan = Color(0xFF3DDCFF);
  static const amber = Color(0xFFFFC75C);
  static const mint = Color(0xFF4BE3A4);
  static const danger = Color(0xFFFF5C6C);

  static const text = Color(0xFFF4F1FF);
  static const textMuted = Color(0xFF9D95BC);
  static const textFaint = Color(0xFF6B6488);

  static const primaryGradient = LinearGradient(
    colors: [violet, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const coolGradient = LinearGradient(
    colors: [Color(0xFF3D7BFF), cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const warmGradient = LinearGradient(
    colors: [Color(0xFFFF8A5C), pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
