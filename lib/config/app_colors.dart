import 'package:flutter/material.dart';

// Fixed colors — same in light and dark
const kPrimary   = Color(0xFF2C7BE5);
const kBlueLight = Color(0xFF4A9EFF);
const kNavy      = Color(0xFF0A1628);
const kError     = Color(0xFFE24B4A);
const kGold      = Color(0xFFF59E0B);
const kSuccess   = Color(0xFF27AE60);
const kPurple    = Color(0xFF7C3AED);

extension AppColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get cBg      => isDark ? const Color(0xFF0A1628) : const Color(0xFFF4F2EE);
  Color get cSurface => isDark ? const Color(0xFF0D1F35) : Colors.white;
  Color get cBorder  => isDark ? const Color(0xFF1A2D45) : const Color(0xFFEDE9E3);
  Color get cText    => isDark ? const Color(0xFFEEF2FF) : const Color(0xFF1A1828);
  Color get cSub     => isDark ? const Color(0xFF7B8DB0) : const Color(0xFF9096A4);
  Color get cFill    => isDark ? const Color(0xFF0A1A2E) : const Color(0xFFF0F2F5);
}
