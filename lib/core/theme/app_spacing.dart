import 'package:flutter/material.dart';

/// Spacing & radius tokens from Planning/02 §3 (basis 4)
class AppSpacing {
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;

  static const double screenPadding = 16.0;
  static const double cardSpacing = 12.0;
  static const double ctaBottomPadding = 16.0;

  // Radius
  static const double radiusCard = 12.0;
  static const double radiusCta = 10.0;
  static const double radiusSheet = 16.0;
  static const double radiusBadge = 999.0;

  // Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(27, 42, 74, 0.08),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  static const List<BoxShadow> fabShadow = [
    BoxShadow(
      color: Color.fromRGBO(27, 42, 74, 0.18),
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];
}
