import 'package:flutter/material.dart';

import '../../core/models/risk_alert.dart';
import '../../core/models/risk_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'risk_widgets.dart';

/// Card de alerta com nível de severidade, título, local e horário.
class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.alert,
    required this.onTap,
    required this.onToggleRead,
  });

  final RiskAlert alert;
  final VoidCallback onTap;
  final VoidCallback? onToggleRead;

  String get _timeLabel {
    final t = alert.time;
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    return 'há ${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: alert.severity.softColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  alert.severity == RiskLevel.critical
                      ? Icons.warning_amber_rounded
                      : Icons.notifications_active_outlined,
                  size: 22,
                  color: alert.severity.textColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.inter(
                              scheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (!alert.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.orange,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            alert.location,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.inter(
                              scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        RiskBadge(level: alert.severity),
                        const Spacer(),
                        Text(
                          _timeLabel,
                          style: AppTypography.inter(
                            scheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onToggleRead != null) ...[
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  onPressed: onToggleRead,
                  tooltip: alert.isRead ? 'Marcar como não lido' : 'Marcar como lido',
                  icon: Icon(
                    alert.isRead
                        ? Icons.done_all_rounded
                        : Icons.mark_email_read_outlined,
                    size: 20,
                    color: alert.isRead
                        ? scheme.onSurfaceVariant
                        : AppColors.orange,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}