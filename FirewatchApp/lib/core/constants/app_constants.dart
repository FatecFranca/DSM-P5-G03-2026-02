import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Constantes globais do aplicativo.
abstract final class AppConstants {
  static const String appName = 'Firewatch';
  static const String slogan = 'Veja o risco antes do fogo.';
  static const String location = 'Franca, SP';
  static const String version = '1.0.0';

  // Splash
  static const String splashPhrase = 'Veja o risco antes do fogo.';
  static const String splashStartLabel = 'Começar';
  static const String splashProjectLabel = 'PROJETO INTEGRADOR • 5º SEMESTRE';

  /// Sinaliza dados demonstrativos até a integração com backend.
  static const String demoDisclaimer = 'Dados demonstrativos';

  static void showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$feature estará disponível em breve com a integração do backend.',
            style: AppTypography.inter(AppColors.white, fontSize: 14),
          ),
        ),
      );
  }
}