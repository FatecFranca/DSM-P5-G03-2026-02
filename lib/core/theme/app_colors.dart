import 'package:flutter/material.dart';

/// Tokens de cores do Firewatch.
///
/// O laranja representa a marca, nunca o nível de risco.
/// Os níveis de risco possuem cores próprias ([riskLow], [riskModerate], [riskCritical]).
abstract final class AppColors {
  // Marca
  static const Color orange = Color(0xFFFF6B1A);
  static const Color orangeDark = Color(0xFFE8480C);
  static const Color orangeHover = Color(0xFFF25A0A);
  static const Color amber = Color(0xFFFFB347);
  static const Color orangeText = Color(0xFFC2410C);

  // Neutros
  static const Color charcoal = Color(0xFF1C1917);
  static const Color background = Color(0xFFFAF7F2);
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray = Color(0xFF78716C);
  static const Color grayDark = Color(0xFF57534E);
  static const Color grayLight = Color(0xFFA8A29E);
  static const Color border = Color(0xFFE7E0D6);

  // Níveis de risco
  static const Color riskLow = Color(0xFF22C55E);
  static const Color riskModerate = Color(0xFFFACC15);
  static const Color riskCritical = Color(0xFFDC2626);

  // Fundos suaves por nível de risco
  static const Color riskLowSoft = Color(0xFFDCFCE7);
  static const Color riskModerateSoft = Color(0xFFFEF9C3);
  static const Color riskCriticalSoft = Color(0xFFFEE2E2);

  // Superfícies do tema escuro
  static const Color darkBackground = Color(0xFF15110F);
  static const Color darkSurface = Color(0xFF211B18);
  static const Color darkSurfaceHigh = Color(0xFF2B2420);
  static const Color darkBorder = Color(0xFF3A312C);

  // Splash (identidade escura, escopada apenas à tela inicial)
  static const Color splashBackground = Color(0xFF151515);
  static const Color splashBorder = Color(0xFF3FC8D4);
  static const Color splashButton = Color(0xFFFF6818);
  static const Color splashButtonText = Color(0xFF151515);
  static const Color splashTextPrimary = Color(0xFFFFFFFF);
  static const Color splashTextSecondary = Color(0xFFB5B5B5);
  static const Color splashTextMuted = Color(0xFF6E6E6E);

  // Token de risco para texto
  static Color riskTextColor(RiskTone tone) => switch (tone) {
        RiskTone.low => riskLow,
        RiskTone.moderate => Color(0xFFB8860B),
        RiskTone.critical => riskCritical,
      };
}

/// Classificação de intensidade usada em textos e detalhes de risco.
enum RiskTone {
  low,
  moderate,
  critical,
}