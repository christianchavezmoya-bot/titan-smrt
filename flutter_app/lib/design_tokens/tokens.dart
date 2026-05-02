import 'package:flutter/material.dart';

/// Titan Design Tokens - Foundation Layer
/// Based on Component Library Specification

// ============================================================================
// COLORS
// ============================================================================

class TitanColors {
  // Primary palette
  static const Color primary500 = Color(0xFFFF6B35); // Energy/CTA
  static const Color primary400 = Color(0xFFFF8A5C);
  static const Color primary600 = Color(0xFFE55A2B);
  
  // Surface colors
  static const Color surface800 = Color(0xFF121212); // Dark bg
  static const Color surface700 = Color(0xFF1A1A1A);
  static const Color surface600 = Color(0xFF242424);
  static const Color surface500 = Color(0xFF2E2E2E);
  
  // Text colors (adaptive contrast)
  static const Color text900 = Color(0xFFFFFFFF);
  static const Color text800 = Color(0xFFE0E0E0);
  static const Color text700 = Color(0xFFBDBDBD);
  static const Color text600 = Color(0xFF9E9E9E);
  static const Color text100 = Color(0xFF000000);
  
  // Status colors (WCAG AA compliant)
  static const Color statusSuccess = Color(0xFF2ECC71);
  static const Color statusWarn = Color(0xFFF39C12);
  static const Color statusError = Color(0xFFE74C3C);
  static const Color statusInfo = Color(0xFF3498DB);
  
  // Accent colors
  static const Color accent = Color(0xFF6200EA);
  static const Color highlight = Color(0xFFCCFF00); // Lime green for emphasis
  
  // Overlay colors
  static const Color overlayLight = Color(0x1AFFFFFF);
  static const Color overlayDark = Color(0x33000000);
}

// ============================================================================
// TYPOGRAPHY
// ============================================================================

class TitanTypography {
  // Font families
  static const String fontFamilyUI = 'Inter';
  static const String fontFamilyMetric = 'DIN Alternate';
  
  // Font sizes (4px baseline grid)
  static const double fontSize10 = 10.0;
  static const double fontSize12 = 12.0;
  static const double fontSize14 = 14.0;
  static const double fontSize16 = 16.0;
  static const double fontSize18 = 18.0;
  static const double fontSize20 = 20.0;
  static const double fontSize24 = 24.0;
  static const double fontSize32 = 32.0;
  
  // Font weights
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemiBold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;
  
  // Line heights
  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.5;
  static const double lineHeightRelaxed = 1.75;
}

// ============================================================================
// SPACING
// ============================================================================

class TitanSpacing {
  // Multiples of 4
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;
}

// ============================================================================
// MOTION
// ============================================================================

class TitanMotion {
  // Durations
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);
  
  // Easings
  static const Curve easingStandard = Cubic(0.4, 0.0, 0.2, 1);
  static const Curve easingDecelerate = Cubic(0.0, 0.0, 0.2, 1);
  static const Curve easingAccelerate = Cubic(0.4, 0.0, 1.0, 1.0);
  static const Curve easingSpring = Curves.elasticOut;
}

// ============================================================================
// ELEVATION
// ============================================================================

class TitanElevation {
  // Shadow definitions (platform-adaptive)
  static List<BoxShadow> shadow1 = [
    const BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
  ];
  
  static List<BoxShadow> shadow2 = [
    const BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];
  
  static List<BoxShadow> shadow3 = [
    const BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];
}

// ============================================================================
// BORDER RADIUS
// ============================================================================

class TitanRadius {
  static const double radius4 = 4.0;
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius24 = 24.0;
  static const double radiusFull = 999.0;
}

// ============================================================================
// BREAKPOINTS (for responsive design)
// ============================================================================

class TitanBreakpoints {
  static const double mobile = 375.0;
  static const double tablet = 768.0;
  static const double desktop = 1024.0;
  static const double wide = 1440.0;
}