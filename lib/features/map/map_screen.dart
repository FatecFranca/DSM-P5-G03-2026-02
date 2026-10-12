import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/risk_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/section_badge.dart';

/// Ponto ilustrativo exibido no mapa.
class MapPoint {
  const MapPoint({
    required this.name,
    required this.lat,
    required this.lng,
    required this.level,
    required this.risk,
    required this.posX,
    required this.posY,
  });

  final String name;
  final double lat;
  final double lng;
  final RiskLevel level;
  final int risk;

  /// Posição 0–1 normalizada dentro da área do mapa.
  final double posX;
  final double posY;
}

/// Tela de mapa centrado em Franca-SP.
///
/// Sem serviço de mapas integrado, exibe uma área visual provisória,
/// claramente identificada, com controles e legenda funcionais.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _points = [
    MapPoint(
      name: 'Parque Dom Pedro',
      lat: -20.5352,
      lng: -47.4039,
      level: RiskLevel.critical,
      risk: 91,
      posX: 0.30,
      posY: 0.42,
    ),
    MapPoint(
      name: 'Vila Aparecida',
      lat: -20.5234,
      lng: -47.4125,
      level: RiskLevel.moderate,
      risk: 62,
      posX: 0.48,
      posY: 0.30,
    ),
    MapPoint(
      name: 'Jardim do Éden',
      lat: -20.5441,
      lng: -47.3898,
      level: RiskLevel.critical,
      risk: 84,
      posX: 0.63,
      posY: 0.56,
    ),
    MapPoint(
      name: 'Parque dos Pinhais',
      lat: -20.5102,
      lng: -47.4231,
      level: RiskLevel.low,
      risk: 28,
      posX: 0.40,
      posY: 0.70,
    ),
  ];

  double _scale = 1;
  Offset _drag = Offset.zero;
  bool _showLegend = true;
  RiskLevel? _filter;
  int _selectedPoint = 2;

  void _zoom(double factor) {
    setState(() => _scale = (_scale * factor).clamp(0.8, 2.6));
  }

  void _center() {
    setState(() {
      _scale = 1;
      _drag = Offset.zero;
    });
  }

  List<MapPoint> get _visiblePoints {
    if (_filter == null) return _points;
    return _points.where((p) => p.level == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _points[_selectedPoint];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              onNotifications: () => context.go('/alerts'),
              onSettings: () => context.go('/settings'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mapa de risco',
                      style: AppTypography.sora(
                        scheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const DemoBadge(compact: true),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Filtros de visualização.
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                children: [
                  _FilterChip(
                    label: 'Todos',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Risco Baixo',
                    color: AppColors.riskLow,
                    selected: _filter == RiskLevel.low,
                    onTap: () => setState(() => _filter = RiskLevel.low),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Risco Moderado',
                    color: AppColors.riskModerate,
                    selected: _filter == RiskLevel.moderate,
                    onTap: () => setState(() => _filter = RiskLevel.moderate),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Risco Crítico',
                    color: AppColors.riskCritical,
                    selected: _filter == RiskLevel.critical,
                    onTap: () => setState(() => _filter = RiskLevel.critical),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Área do mapa.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onPanUpdate: (details) {
                          setState(() => _drag += details.delta);
                        },
                        onTapUp: (details) {
                          // Seleção aproximada do marcador mais próximo.
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            final h = constraints.maxHeight;
                            return Transform.translate(
                              offset: _drag,
                              child: Transform.scale(
                                scale: _scale,
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: w,
                                  height: h,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _CityPainter(
                                            background: Theme.of(context)
                                                        .brightness ==
                                                    Brightness.dark
                                                ? const Color(0xFF1E1916)
                                                : const Color(0xFFEDE9E3),
                                            street: Theme.of(context)
                                                        .brightness ==
                                                    Brightness.dark
                                                ? const Color(0xFF342C27)
                                                : const Color(0xFFDCD5CC),
                                          ),
                                        ),
                                      ),
                                      for (final point in _visiblePoints)
                                        Positioned(
                                          left: point.posX * w - 22,
                                          top: point.posY * h - 44,
                                          child: _MarkerPin(
                                            point: point,
                                            emphasized:
                                                point.name == selected.name,
                                            onTap: () => setState(() {
                                              _selectedPoint = _points
                                                  .indexWhere(
                                                      (p) => p.name == point.name);
                                            }),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs + 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.charcoal.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            'Mapa ilustrativo · Franca, SP',
                            style: AppTypography.inter(
                              AppColors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      // Controles de zoom e centralização.
                      Positioned(
                        right: 12,
                        bottom: 24,
                        child: Column(
                          children: [
                            _RoundIconButton(
                              icon: Icons.add_rounded,
                              onTap: () => _zoom(1.25),
                            ),
                            const SizedBox(height: 8),
                            _RoundIconButton(
                              icon: Icons.remove_rounded,
                              onTap: () => _zoom(0.8),
                            ),
                            const SizedBox(height: 8),
                            _RoundIconButton(
                              icon: Icons.my_location_rounded,
                              onTap: _center,
                              highlighted: true,
                            ),
                          ],
                        ),
                      ),
                      // Legenda.
                      Positioned(
                        left: 12,
                        top: 12,
                        child: _LegendPanel(
                          show: _showLegend,
                          onToggle: () => setState(() => _showLegend = !_showLegend),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Card informativo do ponto selecionado.
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: _PointInfoCard(point: selected),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

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
          color: selected ? AppColors.orange : scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.orange : scheme.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

class _MarkerPin extends StatelessWidget {
  const _MarkerPin({
    required this.point,
    required this.onTap,
    this.emphasized = false,
  });

  final MapPoint point;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_rounded,
            size: emphasized ? 46 : 38,
            color: emphasized ? AppColors.charcoal : point.level.color,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
              ),
            ],
          ),
          if (emphasized)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: point.level.softColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${point.risk}%',
                style: AppTypography.mono(
                  point.level.textColor,
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

class _LegendPanel extends StatelessWidget {
  const _LegendPanel({required this.show, required this.onToggle});

  final bool show;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Ink(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: isDark ? 0.92 : 0.95),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Legenda',
                  style: AppTypography.inter(
                    scheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  show
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            if (show) ...[
              const SizedBox(height: 6),
              for (final level in RiskLevel.values)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: level.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        level.label,
                        style: AppTypography.inter(
                          scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: highlighted ? AppColors.orange : scheme.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: 22,
            color: highlighted ? AppColors.white : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _PointInfoCard extends StatelessWidget {
  const _PointInfoCard({required this.point});

  final MapPoint point;

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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: point.level.softColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: point.level.textColor,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.name,
                  style: AppTypography.inter(
                    scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${point.lat.toStringAsFixed(4)}, ${point.lng.toStringAsFixed(4)}',
                  style: AppTypography.mono(
                    scheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${point.risk}%',
                style: AppTypography.mono(
                  point.level.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                point.level.label.toLowerCase(),
                style: AppTypography.inter(
                  point.level.textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Desenha quarteirões e ruas de forma ilustrativa.
class _CityPainter extends CustomPainter {
  _CityPainter({required this.background, required this.street});

  final Color background;
  final Color street;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final block = Paint()..color = street;
    final park = Paint()..color = const Color(0xFF9CCB8E).withValues(alpha: 0.55);
    final rng = math.Random(7);

    for (var row = 0; row < 6; row++) {
      for (var col = 0; col < 6; col++) {
        final x = col * size.width / 6 + 8;
        final y = row * size.height / 6 + 8;
        final w = size.width / 6 - 16;
        final h = size.height / 6 - 16;
        final rr = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          const Radius.circular(6),
        );
        canvas.drawRRect(rr, block);
        if (rng.nextInt(3) == 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x + w * 0.3, y + h * 0.3, w * 0.4, h * 0.4),
              const Radius.circular(8),
            ),
            park,
          );
        }
      }
    }

    // Rio/perímetro ilustrativo.
    final riverRect = Path()
      ..moveTo(0, size.height * 0.22)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.05,
        size.width,
        size.height * 0.3,
      );
    canvas.drawPath(
      riverRect,
      Paint()
        ..color = const Color(0xFF7EB6D8).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CityPainter old) =>
      old.background != background || old.street != street;
}