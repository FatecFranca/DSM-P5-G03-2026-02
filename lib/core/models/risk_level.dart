import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Nível de risco de queimadas.
///
/// O laranja nunca representa risco: cada nível possui cor própria.
enum RiskLevel {
  low,
  moderate,
  critical;

  String get label => switch (this) {
        RiskLevel.low => 'Baixo',
        RiskLevel.moderate => 'Moderado',
        RiskLevel.critical => 'Crítico',
      };

  Color get color => switch (this) {
        RiskLevel.low => AppColors.riskLow,
        RiskLevel.moderate => AppColors.riskModerate,
        RiskLevel.critical => AppColors.riskCritical,
      };

  Color get softColor => switch (this) {
        RiskLevel.low => AppColors.riskLowSoft,
        RiskLevel.moderate => AppColors.riskModerateSoft,
        RiskLevel.critical => AppColors.riskCriticalSoft,
      };

  /// Cor com contraste adequado para texto sobre [softColor] e [color].
  Color get textColor => AppColors.riskTextColor(switch (this) {
        RiskLevel.low => RiskTone.low,
        RiskLevel.moderate => RiskTone.moderate,
        RiskLevel.critical => RiskTone.critical,
      });

  static RiskLevel fromPercent(double percent) {
    if (percent >= 70) return RiskLevel.critical;
    if (percent >= 40) return RiskLevel.moderate;
    return RiskLevel.low;
  }
}