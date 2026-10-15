import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/demo_data.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/alert_card.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/risk_hero_card.dart';
import '../../shared/widgets/section_badge.dart';
import '../../shared/widgets/weather_metric_card.dart';

/// Tela principal: risco em destaque, clima e alertas recentes.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = DemoSettings.currentWeather;
    final alerts = ref.watch(alertsProvider);
    final recentAlerts = alerts.take(2).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future<void>.delayed(const Duration(milliseconds: 900));
          },
          color: AppColors.orange,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              const AppHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card principal de risco.
                    RiskHeroCard(
                      onTap: () => context.go('/risk-details'),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Métricas meteorológicas.
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
                            label: 'Umidade do ar',
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
                            icon: Icons.umbrella_outlined,
                            label: 'Precipitação',
                            value: weather.precipitation.toStringAsFixed(1),
                            unit: 'mm',
                            iconColor: const Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: WeatherMetricCard(
                            icon: Icons.air_rounded,
                            label: 'Vento',
                            value: weather.windSpeed.toStringAsFixed(1),
                            unit: 'km/h',
                            iconColor: const Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    const _AlertMaximumCard(),
                    const SizedBox(height: AppSpacing.lg),
                    const _WeatherSummaryCard(),
                    const SizedBox(height: AppSpacing.lg),

                    // Ações principais.
                    FilledButton.icon(
                      onPressed: () => context.go('/risk-details'),
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('Ver detalhes do risco'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/map'),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Ver mapa'),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                    SectionTitle(
                      title: 'Alertas recentes',
                      action: 'Ver todos',
                      onAction: () => context.go('/alerts'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final alert in recentAlerts) ...[
                      AlertCard(
                        alert: alert,
                        onTap: () => context.go('/alerts'),
                        onToggleRead: () =>
                            ref.read(alertsProvider.notifier).toggleRead(alert.id),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card de alerta máximo (cenário crítico).
class _AlertMaximumCard extends StatelessWidget {
  const _AlertMaximumCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB91C1C), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ALERTA MÁXIMO',
                      style: AppTypography.inter(
                        Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.circle, size: 6, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Zona de maior risco nas próximas 24h',
                  style: AppTypography.inter(
                    Colors.white.withValues(alpha: 0.92),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_right_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

/// Resumo das condições meteorológicas com gráfico de temperatura.
class _WeatherSummaryCard extends StatelessWidget {
  const _WeatherSummaryCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hours = DemoSettings.nextHours;

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
              const Icon(Icons.cloud_outlined, size: 20, color: AppColors.orange),
              const SizedBox(width: 8),
              Text(
                'Resumo das condições',
                style: AppTypography.sora(
                  scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Céu com sol forte e ar seco em Franca, SP. Temperatura em elevação e '
            'umidade em queda ao longo da tarde. Sem previsão de chuva.',
            style: AppTypography.inter(
              scheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 90,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SummarySparkPainter(
                color: AppColors.orange,
                values: [for (final h in hours) h.weather.temperature],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Agora',
                style: AppTypography.inter(
                  scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              Text(
                '12h',
                style: AppTypography.inter(
                  scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pequeno gráfico de linha (temperatura ao longo das horas).
class _SummarySparkPainter extends CustomPainter {
  _SummarySparkPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).clamp(0.1, double.infinity);

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final dx = size.width * i / (values.length - 1);
      final dy = size.height - (values[i] - minV) / range * (size.height - 16) - 8;
      points.add(Offset(dx, dy));
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }

    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SummarySparkPainter old) =>
      old.values != values || old.color != color;
}