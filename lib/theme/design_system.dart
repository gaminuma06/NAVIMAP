import 'package:flutter/material.dart';

class DesignSystem {
  // Colors
  static const Color surface = Color(0xFF131313);
  static const Color surfaceContainer = Color(0xFF1A1A1A);
  static const Color primary = Color(0xFF00E676); // Tactical Green
  static const Color secondary = Color(0xFF2979FF); // Navigation Blue
  static const Color error = Color(0xFFFF3D00); // Alert Orange
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color outline = Color(0xFF333333);
  
  // Spacing
  static const double spacingUnit = 4.0;
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  
  // Radius
  static const double radiusSm = 2.0;
  static const double radiusDefault = 4.0;
  static const double radiusMd = 6.0;
  static const double radiusLg = 8.0;

  // Text Styles
  static const TextStyle headlineLg = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle headlineMd = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const TextStyle bodyLg = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyMd = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySm = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle labelCaps = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
  );

  static const TextStyle monoData = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontFamily: 'monospace', // Fallback to monospace if font not loaded
  );
}
