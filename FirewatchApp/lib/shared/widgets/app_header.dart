import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    this.showNotifications = true,
  });

  final VoidCallback? onNotifications;
  final VoidCallback? onSettings;
  final String? title;
  final bool showBack;
  final bool showNotifications;

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
            if (showNotifications)
              IconButton(
                onPressed: onNotifications ?? () => context.go('/alerts'),
                icon: const Icon(Icons.notifications_none_rounded),
                tooltip: 'Notificações',
              ),
            IconButton(
              onPressed: onSettings ?? () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Configurações',
            ),
          ],
        ),
      ),
    );
  }
}
