import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/data/demo_data.dart';
import '../../core/models/risk_level.dart';
import '../../core/models/weather_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/risk_hero_card.dart';
import '../../shared/widgets/risk_widgets.dart';
import '../../shared/widgets/section_badge.dart';
import '../../shared/widgets/weather_metric_card.dart';

/// Tela de detalhes do risco: fatores, medições e evolução estimada.
class RiskDetailsScreen extends StatelessWidget {
  const RiskDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final weather = DemoSettings.currentWeather;
    final level = RiskLevel.fromPercent(DemoSettings.currentRisk);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detalhes do risco',
          style: AppTypography.sora(
            Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          RiskHeroCard(showDisclaimer: false),
          const SizedBox(height: AppSpacing.md),
          const Align(
            alignment: Alignment.center,
            child: DemoBadge(),
          ),

          const SizedBox(height: AppSpacing.xl),
          _IntensityCard(level: level),
          const SizedBox(height: AppSpacing.xl),

          const SectionTitle(title: 'Medições atuais'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: WeatherMetricCard(
                  icon: Icons.thermostat_rounded,
                  label: 'Temperatura',
                  value: weather.temperature.toStringAsFixed(1),
                  unit: '°C',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: WeatherMetricCard(
                  icon: Icons.water_drop_outlined,
                  label: 'Umidade',
                  value: weather.humidity.toStringAsFixed(0),
                  unit: '%',
                  iconColor: const Color(0xFF0EA5E9),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: WeatherMetricCard(
                  icon: Icons.air_rounded,
                  label: 'Vento',
                  value: weather.windSpeed.toStringAsFixed(1),
                  unit: 'km/h',
                  iconColor: const Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: WeatherMetricCard(
                  icon: Icons.umbrella_outlined,
                  label: 'Precipitação',
                  value: weather.precipitation.toStringAsFixed(1),
                  unit: 'mm',
                  iconColor: const Color(0xFF0284C7),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          const _RiskChartCard(),
          const SizedBox(height: AppSpacing.xl),

          const SectionTitle(title: 'Fatores relacionados'),
          const SizedBox(height: AppSpacing.md),
          for (final factor in DemoSettings.riskFactors) ...[
            _RiskFactorTile(factor: factor),
            const SizedBox(height: AppSpacing.md),
          ],

          const SizedBox(height: AppSpacing.xl),
          const SectionTitle(title: 'O que isso significa'),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: level.softColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RiskBadge(level: level),
                const SizedBox(height: AppSpacing.md),
                Text(
                  DemoSettings.riskMeaning,
                  style: AppTypography.inter(
                    level.textColor,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

/// Indicador visual de intensidade com barra vertical.
class _IntensityCard extends StatelessWidget {
  const _IntensityCard({required this.level});

  final RiskLevel level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Text(
            'Intensidade',
            style: AppTypography.inter(
              scheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          for (var step = 1; step <= 4; step++) ...[
            Container(
              width: 22,
              height: 10,
              decoration: BoxDecoration(
                color: step <= 3 ? level.color : level.color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            if (step != 4) const SizedBox(width: 4),
          ],
          const SizedBox(width: AppSpacing.md),
          Text(
            '${DemoSettings.currentRisk.toStringAsFixed(1).replaceAll('.', ',')}%',
            style: AppTypography.mono(
              level.textColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gráfico de evolução estimada do risco.
class _RiskChartCard extends StatelessWidget {
  const _RiskChartCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = DemoSettings.riskEvolution;
    final lineColor = AppColors.orange;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evolução estimada do risco',
            style: AppTypography.sora(
              scheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Próximos 7 dias · dados demonstrativos',
            style: AppTypography.inter(
              scheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: (isDark ? AppColors.darkBorder : AppColors.border)
                        .withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 25,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: AppTypography.mono(
                          scheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt().clamp(0, days.length - 1);
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            days[index].shortDay,
                            style: AppTypography.inter(
                              scheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < days.length; i++)
                        FlSpot(i.toDouble(), days[i].risk),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.32,
                    color: lineColor,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: AppColors.orange,
                        strokeWidth: 2,
                        strokeColor: scheme.surface,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.orange.withValues(alpha: 0.28),
                          AppColors.orange.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha de fator de risco com contribuição percentual.
class _RiskFactorTile extends StatelessWidget {
  const _RiskFactorTile({required this.factor});

  final RiskFactor factor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  factor.name,
                  style: AppTypography.inter(
                    scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${factor.percent.toStringAsFixed(0)}%',
                style: AppTypography.mono(
                  scheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: factor.weight / 100,
              minHeight: 8,
              color: AppColors.orange,
              backgroundColor:
                  (isDark ? AppColors.darkBorder : AppColors.border),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            factor.description,
            style: AppTypography.inter(
              scheme.onSurfaceVariant,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}