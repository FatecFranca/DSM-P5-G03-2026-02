import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/data/demo_data.dart';
import '../../core/models/risk_level.dart';
import '../../core/models/weather_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/section_badge.dart';

enum _ForecastPeriod { hours, days }

/// Tela de previsão: próximas horas/dias com gráficos meteorológicos.
class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  _ForecastPeriod _period = _ForecastPeriod.hours;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            const AppHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DemoBadge(),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Previsão do risco',
                    style: AppTypography.sora(
                      Theme.of(context).colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedButton<_ForecastPeriod>(
                    segments: const [
                      ButtonSegment(
                        value: _ForecastPeriod.hours,
                        label: Text('Próximas horas'),
                        icon: Icon(Icons.schedule_rounded),
                      ),
                      ButtonSegment(
                        value: _ForecastPeriod.days,
                        label: Text('Próximos dias'),
                        icon: Icon(Icons.calendar_today_rounded),
                      ),
                    ],
                    selected: {_period},
                    onSelectionChanged: (selection) =>
                        setState(() => _period = selection.first),
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStatePropertyAll(
                        AppTypography.inter(
                          Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  if (_period == _ForecastPeriod.hours)
                    ..._buildHours(context)
                  else
                    ..._buildDays(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHours(BuildContext context) {
    final hours = DemoSettings.nextHours;
    return [
      const SectionTitle(title: 'Próximas horas'),
      const SizedBox(height: AppSpacing.md),
      SizedBox(
        height: 184,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: hours.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) => _HourCard(hour: hours[index]),
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      const SectionTitle(title: 'Temperatura'),
      const SizedBox(height: AppSpacing.md),
      _MetricChartCard(
        key: const ValueKey('temp-hours'),
        values: [for (final h in hours) h.weather.temperature],
        color: AppColors.orange,
        unit: '°C',
        labels: [for (final h in hours) h.label],
        minY: 20,
        maxY: 40,
      ),
      const SizedBox(height: AppSpacing.xl),
      const SectionTitle(title: 'Umidade do ar'),
      const SizedBox(height: AppSpacing.md),
      _MetricChartCard(
        key: const ValueKey('humidity-hours'),
        values: [for (final h in hours) h.weather.humidity],
        color: AppColors.riskLow,
        unit: '%',
        labels: [for (final h in hours) h.label],
        minY: 0,
        maxY: 60,
      ),
      const SizedBox(height: AppSpacing.xl),
      _WeatherConditionRow(metrics: hours[0].weather),
    ];
  }

  List<Widget> _buildDays(BuildContext context) {
    final days = DemoSettings.nextDays;
    return [
      const SectionTitle(title: 'Próximos dias'),
      const SizedBox(height: AppSpacing.md),
      for (final day in days) ...[
        _DayCard(day: day),
        const SizedBox(height: AppSpacing.sm),
      ],
      const SizedBox(height: AppSpacing.xl),
      const SectionTitle(title: 'Evolução estimada do risco'),
      const SizedBox(height: AppSpacing.md),
      _MetricChartCard(
        key: const ValueKey('risk-days'),
        values: [for (final d in days) d.risk],
        color: AppColors.riskCritical,
        unit: '%',
        labels: [for (final d in days) d.shortDay],
        minY: 0,
        maxY: 100,
      ),
      const SizedBox(height: AppSpacing.xl),
      _WeatherConditionRow(metrics: DemoSettings.currentWeather),
    ];
  }
}

/// Card de previsão por hora.
class _HourCard extends StatelessWidget {
  const _HourCard({required this.hour});

  final ForecastHour hour;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final level = RiskLevel.fromPercent(hour.risk);

    return Container(
      width: 92,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            hour.label,
            style: AppTypography.inter(
              scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Icon(
            hour.weather.temperature >= 32
                ? Icons.wb_sunny_rounded
                : Icons.cloud_outlined,
            size: 26,
            color: AppColors.orange,
          ),
          Text(
            '${hour.weather.temperature.toStringAsFixed(1)}°',
            style: AppTypography.mono(
              scheme.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: level.softColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${hour.risk.toStringAsFixed(0)}%',
              style: AppTypography.mono(
                level.textColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card de previsão por dia.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final ForecastDay day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final level = RiskLevel.fromPercent(day.risk);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.weekdayLabel,
                  style: AppTypography.inter(
                    scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${day.day.day.toString().padLeft(2, '0')}/${day.day.month.toString().padLeft(2, '0')}',
                  style: AppTypography.inter(
                    scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Icon(
            day.maxTemperature >= 32 ? Icons.wb_sunny_rounded : Icons.cloud_outlined,
            size: 22,
            color: AppColors.orange,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.weatherLabel,
                  style: AppTypography.inter(
                    scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.minTemperature.toStringAsFixed(0)}° / ${day.maxTemperature.toStringAsFixed(0)}° · ${day.humidity.toStringAsFixed(0)}% umidade',
                  style: AppTypography.mono(
                    scheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: level.softColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '${day.risk.toStringAsFixed(0)}%',
                  style: AppTypography.mono(
                    level.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  level.label.toLowerCase(),
                  style: AppTypography.inter(
                    level.textColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card com gráfico de linha para uma métrica.
class _MetricChartCard extends StatelessWidget {
  const _MetricChartCard({
    super.key,
    required this.values,
    required this.color,
    required this.unit,
    required this.labels,
    required this.minY,
    required this.maxY,
  });

  final List<double> values;
  final Color color;
  final String unit;
  final List<String> labels;
  final double minY;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final spots = <FlSpot>[
      for (final (i, v) in values.indexed) FlSpot(i.toDouble(), v),
    ];
    final last = values.last.toStringAsFixed(1);

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
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                'Média $last $unit',
                style: AppTypography.inter(
                  scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4,
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
                      reservedSize: 40,
                      interval: (maxY - minY) / 4,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(0),
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
                        final index = value.toInt().clamp(0, labels.length - 1);
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[index],
                            style: AppTypography.inter(
                              scheme.onSurfaceVariant,
                              fontSize: 10.5,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: color,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: false,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: color,
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
                          color.withValues(alpha: 0.28),
                          color.withValues(alpha: 0.0),
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

/// Linha de cards com as condições meteorológicas atuais.
class _WeatherConditionRow extends StatelessWidget {
  const _WeatherConditionRow({required this.metrics});

  final WeatherConditions metrics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.darkBorder : AppColors.border;

    Widget tile(IconData icon, String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: AppColors.orange),
              const SizedBox(height: 6),
              Text(
                value,
                style: AppTypography.mono(
                  scheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.inter(
                  scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Condições meteorológicas'),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            tile(
              Icons.thermostat_rounded,
              'Temperatura',
              '${metrics.temperature.toStringAsFixed(1)}°C',
            ),
            const SizedBox(width: AppSpacing.sm),
            tile(
              Icons.water_drop_outlined,
              'Umidade',
              '${metrics.humidity.toStringAsFixed(0)}%',
            ),
            const SizedBox(width: AppSpacing.sm),
            tile(
              Icons.air_rounded,
              'Vento',
              '${metrics.windSpeed.toStringAsFixed(1)} km/h',
            ),
          ],
        ),
      ],
    );
  }
}