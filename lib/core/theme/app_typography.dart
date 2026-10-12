import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografia do Firewatch.
///
/// - Sora para títulos.
/// - Inter para textos e interface.
/// - JetBrains Mono para números, porcentagens e medições.
abstract final class AppTypography {
  static TextStyle sora(
    Color color, {
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.sora(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle inter(
    Color color, {
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle mono(
    Color color, {
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) {
    return GoogleFonts.jetBrainsMono(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }
}