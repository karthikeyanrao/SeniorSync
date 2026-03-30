
import 'package:flutter/material.dart';

class SeniorStyles {
  // Colors
  static const Color primaryBlue = Color(0xFF1A73E8);
  static const Color successGreen = Color(0xFF1E8E3E);
  static const Color alertRed = Color(0xFFD93025);
  static const Color warningOrange = Color(0xFFF29900);
  static const Color surfaceWhite = Colors.white;
  static const Color backgroundGray = Color(0xFFF8F9FA);

  // Text Styles
  static const TextStyle header = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
    letterSpacing: -0.5,
  );

  static const TextStyle subheader = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.black54,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 18,
    color: Colors.black54,
  );

  static const TextStyle largeButtonText = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );

  // Shapes & Shadows
  static const double cardRadius = 20.0;
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ];

  static BoxDecoration cardDecoration = BoxDecoration(
    color: surfaceWhite,
    borderRadius: BorderRadius.circular(cardRadius),
    boxShadow: softShadow,
  );
}
