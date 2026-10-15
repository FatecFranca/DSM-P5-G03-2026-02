import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/risk_alert.dart';
import '../../core/models/risk_level.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/alert_card.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/risk_widgets.dart';
import '../../shared/widgets/section_badge.dart';

/// Tela de alertas com filtros por nível e detalhes do alerta.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider);
    final filter = ref.watch(alertSeverityFilterProvider);
    final unread = alerts.where((a) => !a.isRead).length;

    final filtered = filter == null
        ? alerts
        : alerts.where((a) => a.severity == filter).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alertas',
                          style: AppTypography.sora(
                            Theme.of(context).colorScheme.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          unread == 0
                              ? 'Tudo em dia'
                              : '$unread não lido${unread > 1 ? 's' : ''}',
                          style: AppTypography.inter(
                            Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const DemoBadge(compact: true),
                  if (unread > 0) ...[
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: () =>
                          ref.read(alertsProvider.notifier).markAllRead(),
                      child: const Text('Marcar lidos'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Filtros por severidade.
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                children: [
                  _SeverityChip(
                    label: 'Todos',
                    level: null,
                    selected: filter == null,
                    onTap: () =>
                        ref.read(alertSeverityFilterProvider.notifier).state = null,
                  ),
                  for (final level in RiskLevel.values) ...[
                    const SizedBox(width: 8),
                    _SeverityChip(
                      label: level.label,
                      level: level,
                      selected: filter == level,
                      onTap: () => ref
                          .read(alertSeverityFilterProvider.notifier)
                          .state = level,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Expanded(
              child: filtered.isEmpty
                  ? _EmptyAlerts(filterActive: filter != null)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.xs,
                        AppSpacing.page,
                        AppSpacing.xxl,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final alert = filtered[index];
                        return AlertCard(
                          alert: alert,
                          onTap: () => _showDetails(context, ref, alert),
                          onToggleRead: () => ref
                              .read(alertsProvider.notifier)
                              .toggleRead(alert.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, WidgetRef ref, RiskAlert alert) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AlertDetailsSheet(alert: alert),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({
    required this.label,
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final RiskLevel? level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? (level?.color ?? AppColors.orange)
              : scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? (level?.color ?? AppColors.orange) : scheme.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (level != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selected ? AppColors.white : level!.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTypography.inter(
                selected ? AppColors.white : scheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts({required this.filterActive});

  final bool filterActive;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 48,
            color: AppColors.grayLight,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            filterActive ? 'Nenhum alerta para este nível' : 'Sem alertas',
            style: AppTypography.inter(
              Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (filterActive) ...[
            const SizedBox(height: 4),
            Text(
              'Experimente outro filtro.',
              style: AppTypography.inter(
                Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Detalhes de um alerta em modal.
class _AlertDetailsSheet extends StatelessWidget {
  const _AlertDetailsSheet({required this.alert});

  final RiskAlert alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.8,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: alert.severity.softColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    alert.severity == RiskLevel.critical
                        ? Icons.warning_amber_rounded
                        : Icons.notifications_active_outlined,
                    size: 28,
                    color: alert.severity.textColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RiskBadge(level: alert.severity, large: true),
                      const SizedBox(height: 6),
                      Text(
                        alert.isRead ? 'Lido' : 'Não lido',
                        style: AppTypography.inter(
                          scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              alert.title,
              style: AppTypography.sora(
                scheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: AppColors.orange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    alert.location,
                    style: AppTypography.inter(
                      scheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Sobre este alerta',
              style: AppTypography.inter(
                scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              alert.description,
              style: AppTypography.inter(
                scheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.55,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color:
                    (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkSurfaceHigh
                            : const Color(0xFFFFF6EC))
                        ,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 20, color: AppColors.orangeText),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Este alerta é um exemplo demonstrativo da interface. '
                      'Alertas reais serão disponibilizados com a integração do backend.',
                      style: AppTypography.inter(
                        AppColors.orangeText,
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}