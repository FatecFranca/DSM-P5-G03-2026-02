import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Logotipo do Firewatch: uma chama combinada com um olho.
///
/// Desenho vetorial próprio baseado na referência visual, sem depender de
/// arquivos de imagem externos.
class FlameLogo extends StatelessWidget {
  const FlameLogo({
    super.key,
    this.size = 84,
    this.color = AppColors.orange,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: FlameEyePainter(color: color),
    );
  }
}

/// Logo com nome e slogan, usado no Splash e no cabeçalho.
class FirewatchWordmark extends StatelessWidget {
  const FirewatchWordmark({
    super.key,
    this.logoSize = 40,
    this.light = false,
    this.compact = false,
  });

  final double logoSize;
  final bool light;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = light ? AppColors.white : AppColors.charcoal;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FlameLogo(size: logoSize),
        const SizedBox(width: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appName,
              style: AppTypography.sora(
                color,
                fontSize: compact ? 18 : 20,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
            if (!compact)
              Text(
                AppConstants.slogan,
                style: AppTypography.inter(
                  light ? AppColors.white.withValues(alpha: 0.72) : AppColors.gray,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class FlameEyePainter extends CustomPainter {
  FlameEyePainter({this.color = AppColors.orange});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Forma principal da chama (teardrop com base ondulada).
    final flame = Path()
      ..moveTo(w * 0.5, h * 0.04)
      ..cubicTo(w * 0.88, h * 0.30, w * 0.96, h * 0.62, w * 0.66, h * 0.92)
      ..cubicTo(w * 0.58, h * 0.99, w * 0.42, h * 0.99, w * 0.34, h * 0.92)
      ..cubicTo(w * 0.04, h * 0.62, w * 0.12, h * 0.30, w * 0.5, h * 0.04)
      ..close();

    canvas.drawPath(flame, Paint()..color = color);

    // Brilho interno.
    final inner = Path()
      ..moveTo(w * 0.5, h * 0.24)
      ..cubicTo(w * 0.70, h * 0.40, w * 0.74, h * 0.56, w * 0.59, h * 0.72)
      ..cubicTo(w * 0.54, h * 0.77, w * 0.46, h * 0.77, w * 0.41, h * 0.72)
      ..cubicTo(w * 0.26, h * 0.56, w * 0.30, h * 0.40, w * 0.5, h * 0.24)
      ..close();

    canvas.drawPath(
      inner,
      Paint()..color = AppColors.amber.withValues(alpha: 0.85),
    );

    // Olho (esclera + íris + brilho).
    final center = Offset(w * 0.5, h * 0.5);
    final r = w * 0.17;

    canvas.drawCircle(center, r, Paint()..color = AppColors.white);
    canvas.drawCircle(center, r * 0.58, Paint()..color = AppColors.charcoal);
    canvas.drawCircle(
      Offset(center.dx - r * 0.2, center.dy - r * 0.2),
      r * 0.2,
      Paint()..color = AppColors.white,
    );
  }

  @override
  bool shouldRepaint(FlameEyePainter oldDelegate) =>
      oldDelegate.color != color;
}