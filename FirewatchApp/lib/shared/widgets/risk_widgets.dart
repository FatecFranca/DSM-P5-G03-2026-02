import 'package:flutter/material.dart';

import '../../core/models/risk_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Indicador de nível de risco (chip com a cor correspondente).
class RiskBadge extends StatelessWidget {
  const RiskBadge({super.key, required this.level, this.large = false});

  final RiskLevel level;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? AppSpacing.lg : AppSpacing.md,
        vertical: large ? AppSpacing.sm + 2 : AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: level.softColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 10 : 8,
            height: large ? 10 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: level.color,
            ),
          ),
          SizedBox(width: large ? AppSpacing.sm : AppSpacing.xs),
          Text(
            'Risco ${level.label}',
            style: AppTypography.inter(
              level.textColor,
              fontSize: large ? 14 : 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de progresso segmentada em verde, amarelo e vermelho.
///
/// Representa a distribuição do espectro de risco (0–100%).
class SegmentedRiskBar extends StatelessWidget {
  const SegmentedRiskBar({super.key, required this.percent, this.height = 12});

  final double percent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100).toDouble();
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const segments = [0.30, 0.40, 0.30];
          const colors = [
            AppColors.riskLow,
            AppColors.riskModerate,
            AppColors.riskCritical,
          ];
          final width = constraints.maxWidth;
          final filledWidth = width * (clamped / 100);
          final markerLeft = (filledWidth - height / 2).clamp(
            0.0,
            width - height / 2,
          );

          final children = <Widget>[];
          double offset = 0;
          for (var i = 0; i < 3; i++) {
            final segmentWidth = width * segments[i];
            final isFilled = offset + segmentWidth <= filledWidth;
            children.add(
              SizedBox(
                width: segmentWidth,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isFilled
                        ? colors[i]
                        : colors[i].withValues(alpha: 0.28),
                    borderRadius: BorderRadius.horizontal(
                      left: i == 0 ? Radius.circular(height) : Radius.zero,
                      right: i == 2 ? Radius.circular(height) : Radius.zero,
                    ),
                  ),
                ),
              ),
            );
            offset += segmentWidth;
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(height),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
                // Marcador do valor atual.
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  left: markerLeft,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: height / 2,
                    decoration: BoxDecoration(
                      color: AppColors.charcoal,
                      borderRadius: BorderRadius.circular(height),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
