import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'flame_logo.dart';

/// Cabeçalho padrão das telas: logo, localização e ações.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.onNotifications,
    this.onSettings,
    this.title,
    this.showBack = false,
  });

  final VoidCallback? onNotifications;
  final VoidCallback? onSettings;
  final String? title;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.md,
          AppSpacing.page,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            if (showBack) ...[
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                tooltip: 'Voltar',
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: title == null
                  ? const FirewatchWordmark(compact: true)
                  : Text(
                      title!,
                      style: AppTypography.sora(
                        Theme.of(context).colorScheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
            ),
            IconButton(
              onPressed: onNotifications,
              icon: const Icon(Icons.notifications_none_rounded),
              tooltip: 'Notificações',
            ),
            IconButton(
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Configurações',
            ),
          ],
        ),
      ),
    );
  }
}

/// Linha com ícone de localização e o nome da cidade.
class LocationLabel extends StatelessWidget {
  const LocationLabel({super.key, this.location = AppConstants.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on_outlined, size: 18, color: AppColors.orange),
        const SizedBox(width: AppSpacing.xs),
        Text(
          location,
          style: AppTypography.inter(
            onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}