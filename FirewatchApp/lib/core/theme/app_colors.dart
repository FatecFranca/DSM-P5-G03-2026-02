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

  // Painel de monitoramento (superfícies claras com detalhes laranja)
  static const Color panelBackground = Color(0xFFFFFFFF);
  static const Color metricCard = Color(0xFFF4EFE8);
  static const Color metricCardBorder = Color(0xFFEBE4DA);

  // Níveis de risco
  static const Color riskLow = Color(0xFF22C55E);
  static const Color riskModerate = Color(0xFFFACC15);
  static const Color riskCritical = Color(0xFFDC2626);
  static const Color riskCriticalText = Color(0xFF991B1B);

  // Fundos suaves por nível de risco
  static const Color riskLowSoft = Color(0xFFDCFCE7);
  static const Color riskModerateSoft = Color(0xFFFEF9C3);
  static const Color riskCriticalSoft = Color(0xFFFEE2E2);

  // Superfícies do tema escuro
  static const Color darkBackground = charcoal;
  static const Color darkSurface = Color(0xFF292524);
  static const Color darkSurfaceHigh = Color(0xFF44403C);
  static const Color darkBorder = Color(0xFF44403C);

  // Splash (identidade escura, escopada apenas à tela inicial)
  static const Color splashBackground = Color(0xFF1C1917);
  static const Color splashGlowBrown = Color(0xFF5C2A0E);
  static const Color splashGlowOrange = Color(0xFFB23A00);
  static const Color splashButton = orange;
  static const Color splashButtonText = Color(0xFF1C1917);
  static const Color splashTextPrimary = background;
  static const Color splashTextSecondary = Color(0xFFA8A29E);
  static const Color splashTextMuted = grayLight;

  // Token de risco para texto
  static Color riskTextColor(RiskTone tone) => switch (tone) {
    RiskTone.low => charcoal,
    RiskTone.moderate => charcoal,
    RiskTone.critical => riskCriticalText,
  };
}

/// Classificação de intensidade usada em textos e detalhes de risco.
enum RiskTone { low, moderate, critical }
