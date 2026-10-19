import 'package:flutter/material.dart';

import '../../core/models/risk_level.dart';
import '../../core/models/risk_prediction.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'weather_metric_card.dart';

/// Resultado real com o percentual em destaque e contexto meteorológico.
class RiskResultSheet extends StatelessWidget {
  const RiskResultSheet({
    super.key,
    required this.prediction,
    this.locationName,
  });

  final RiskPrediction prediction;
  final String? locationName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final level = prediction.level;
    final weather = prediction.weather;
    final title = switch (level) {
      RiskLevel.low => 'Condições favoráveis',
      RiskLevel.moderate => 'Atenção',
      RiskLevel.critical => 'Alerta máximo',
    };
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          maxWidth: 560,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locationName ?? 'Sua localização',
                          style: AppTypography.sora(
                            scheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Risco de queimada',
                          style: AppTypography.inter(
                            scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar resultado',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: level.softColor,
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                ),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        prediction.percentageLabel,
                        style: AppTypography.mono(
                          level.textColor,
                          fontSize: 88,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                          letterSpacing: -4,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          level == RiskLevel.low
                              ? Icons.check_circle_outline_rounded
                              : Icons.warning_amber_rounded,
                          color: level.textColor,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            level.label,
                            textAlign: TextAlign.center,
                            style: AppTypography.sora(
                              level.textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: prediction.probability,
                        minHeight: 8,
                        color: level.color,
                        backgroundColor: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Probabilidade da classe de risco crítico',
                      textAlign: TextAlign.center,
                      style: AppTypography.inter(
                        AppColors.grayDark,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _MetricRow(
                children: [
                  WeatherMetricCard(
                    icon: Icons.thermostat_outlined,
                    label: 'Temperatura',
                    value: weather.temperature.toStringAsFixed(1),
                    unit: '°C',
                    iconColor: AppColors.orangeText,
                  ),
                  WeatherMetricCard(
                    icon: Icons.water_drop_outlined,
                    label: 'Umidade do ar',
                    value: weather.humidity.toStringAsFixed(1),
                    unit: '%',
                    iconColor: AppColors.orangeText,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _MetricRow(
                children: [
                  WeatherMetricCard(
                    icon: Icons.grain_rounded,
                    label: 'Precipitação',
                    value: weather.precipitation.toStringAsFixed(1),
                    unit: 'mm',
                    iconColor: AppColors.orangeText,
                  ),
                  WeatherMetricCard(
                    icon: Icons.air_rounded,
                    label: 'Vento',
                    value: weather.windSpeed.toStringAsFixed(1),
                    unit: 'km/h',
                    iconColor: AppColors.orangeText,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.sora(
                        scheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      prediction.recommendation.isEmpty
                          ? 'Acompanhe as condições e os avisos oficiais.'
                          : prediction.recommendation,
                      style: AppTypography.inter(
                        scheme.onSurface,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '${prediction.latitude.toStringAsFixed(4)}, ${prediction.longitude.toStringAsFixed(4)}',
                textAlign: TextAlign.center,
                style: AppTypography.mono(
                  scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: children[0]),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: children[1]),
      ],
    ),
  );
}
