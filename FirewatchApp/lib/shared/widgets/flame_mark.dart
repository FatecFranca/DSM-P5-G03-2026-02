import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Chama estilizada do Firewatch.
///
/// Desenho vetorial próprio (sem imagens externas), com camadas de laranja,
/// âmbar e um núcleo claro. Reutilizável em qualquer tela.
class FlameMark extends StatelessWidget {
  const FlameMark({
    super.key,
    this.size = 96,
    this.outerColor = AppColors.orange,
    this.innerColor = AppColors.amber,
    this.coreColor = const Color(0xFFFFE08A),
  });

  final double size;
  final Color outerColor;
  final Color innerColor;
  final Color coreColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: FlameMarkPainter(
        outerColor: outerColor,
        innerColor: innerColor,
        coreColor: coreColor,
      ),
    );
  }
}

/// Pintura do [FlameMark].
class FlameMarkPainter extends CustomPainter {
  FlameMarkPainter({
    required this.outerColor,
    required this.innerColor,
    required this.coreColor,
  });

  final Color outerColor;
  final Color innerColor;
  final Color coreColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Chama externa (teardrop com base ondulada).
    final outer = Path()
      ..moveTo(w * 0.5, h * 0.02)
      ..cubicTo(w * 0.90, h * 0.30, w * 0.97, h * 0.62, w * 0.67, h * 0.93)
      ..cubicTo(w * 0.58, h * 1.00, w * 0.42, h * 1.00, w * 0.33, h * 0.93)
      ..cubicTo(w * 0.03, h * 0.62, w * 0.10, h * 0.30, w * 0.5, h * 0.02)
      ..close();

    canvas.drawPath(
      outer,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.55),
          radius: 1.05,
          colors: [outerColor, Color.lerp(outerColor, Colors.black, 0.22)!],
        ).createShader(Offset.zero & size),
    );

    // Chama interna.
    final inner = Path()
      ..moveTo(w * 0.5, h * 0.28)
      ..cubicTo(w * 0.74, h * 0.46, w * 0.76, h * 0.62, w * 0.60, h * 0.77)
      ..cubicTo(w * 0.55, h * 0.82, w * 0.45, h * 0.82, w * 0.40, h * 0.77)
      ..cubicTo(w * 0.24, h * 0.62, w * 0.26, h * 0.46, w * 0.5, h * 0.28)
      ..close();

    canvas.drawPath(inner, Paint()..color = innerColor);

    // Núcleo claro.
    final core = Path()
      ..moveTo(w * 0.5, h * 0.52)
      ..cubicTo(w * 0.62, h * 0.62, w * 0.63, h * 0.72, w * 0.55, h * 0.80)
      ..cubicTo(w * 0.52, h * 0.83, w * 0.48, h * 0.83, w * 0.45, h * 0.80)
      ..cubicTo(w * 0.37, h * 0.72, w * 0.38, h * 0.62, w * 0.5, h * 0.52)
      ..close();

    canvas.drawPath(
      core,
      Paint()..color = coreColor.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(FlameMarkPainter oldDelegate) {
    return oldDelegate.outerColor != outerColor ||
        oldDelegate.innerColor != innerColor ||
        oldDelegate.coreColor != coreColor;
  }
}
