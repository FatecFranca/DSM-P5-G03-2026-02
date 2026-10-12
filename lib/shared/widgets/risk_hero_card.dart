import 'package:flutter/material.dart';

import '../../core/data/demo_data.dart';
import '../../core/models/risk_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'risk_widgets.dart';
import 'section_badge.dart';

/// Card de risco em destaque com percentual, nível e barra segmentada.
class RiskHeroCard extends StatelessWidget {
  const RiskHeroCard({
    super.key,
    this.percent,
    this.onTap,
    this.showDisclaimer = true,
  });

  final double? percent;
  final VoidCallback? onTap;

  /// Exibe o selo de dados demonstrativos dentro do card.
  final bool showDisclaimer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = percent ?? DemoSettings.currentRisk;
    final level = RiskLevel.fromPercent(p);

    String lastUpdateLabel() {
      final n = DemoSettings.lastUpdated;
      final hh = n.hour.toString().padLeft(2, '0');
      final mm = n.minute.toString().padLeft(2, '0');
      const months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
      return 'Atualizado em ${n.day} ${months[n.month - 1]} às $hh:$mm';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [AppColors.darkSurfaceHigh, AppColors.darkSurface]
                  : [AppColors.white, const Color(0xFFFFF6EC)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RiskBadge(level: level, large: true),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Risco de queimada',
                style: AppTypography.inter(
                  scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    p.toStringAsFixed(1).replaceAll('.', ','),
                    style: AppTypography.mono(
                      scheme.onSurface,
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -2,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(
                      '%',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SegmentedRiskBar(percent: p, height: 14),
              const SizedBox(height: AppSpacing.md),
              Text(
                p >= 70
                    ? 'Condições críticas para ignição e propagação do fogo.'
                    : p >= 40
                        ? 'Atenção: condições meteorológicas favorecem queimadas.'
                        : 'Condições meteorológicas estão dentro da normalidade.',
                style: AppTypography.inter(
                  scheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      lastUpdateLabel(),
                      style: AppTypography.inter(
                        scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (showDisclaimer) ...[
                const SizedBox(height: AppSpacing.lg),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: DemoBadge(compact: true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}