import 'package:flutter/material.dart';

const Color kPrimary   = Color(0xFF2C7BE5);
const Color kBlueLight = Color(0xFF4A9EF5);
const Color kNavy      = Color(0xFF0B1220);
const Color kNavyCard  = Color(0xFF1E2D45);
const Color kGold      = Color(0xFFF59E0B);
const Color kSuccess   = Color(0xFF27AE60);
const Color kError     = Color(0xFFE24B4A);
const Color kPurple    = Color(0xFF7C3AED);

const double kMaxContentWidth = 500;

const Map<String, Map<String, dynamic>> kCategoryStyles = {
  'Café':        {'emoji': '☕', 'color': Color(0xFF2C7BE5)},
  'Boulangerie': {'emoji': '🥐', 'color': Color(0xFFD4A017)},
  'Restaurant':  {'emoji': '🍽',  'color': Color(0xFFC0392B)},
  'Healthy':     {'emoji': '🥗', 'color': Color(0xFF27AE60)},
  'Librairie':   {'emoji': '📚', 'color': Color(0xFF8E44AD)},
  'Coiffeur':    {'emoji': '✂',  'color': Color(0xFF2980B9)},
};
