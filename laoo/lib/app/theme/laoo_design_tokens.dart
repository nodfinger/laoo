import 'package:flutter/material.dart';

abstract final class LaooColors {
  static const white = Color(0xFFFFFFFF);
  static const background = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF7FAF8);
  static const textPrimary = Color(0xFF17221A);
  static const textSecondary = Color(0xFF66746A);
  static const border = Color(0xFFE4EAE6);

  static const green = Color(0xFF168364);
  static const greenDark = Color(0xFF0B4B3B);
  static const greenLight = Color(0xFFE8F7EF);
  static const blue = Color(0xFF3B82F6);
  static const purple = Color(0xFF8B5CF6);
  static const pink = Color(0xFFFF4DA6);
  static const orange = Color(0xFFF97316);
  static const gold = Color(0xFFD4A017);
  static const brown = Color(0xFF795548);
  static const gray = Color(0xFF6B7280);
  static const teal = Color(0xFF0F9D8A);
  static const dark = Color(0xFF263238);
  static const success = Color(0xFF1F9D55);
  static const error = Color(0xFFD94A4A);
}

abstract final class LaooRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
}

abstract final class LaooShadows {
  static const soft = <BoxShadow>[
    BoxShadow(color: Color(0x10000000), blurRadius: 24, offset: Offset(0, 10)),
  ];
}
