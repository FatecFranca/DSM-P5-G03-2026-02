import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../services/location_service.dart';

/// Onboarding de localização.
///
/// Explica por que o Firewatch precisa das coordenadas e oferece duas saídas:
/// solicitar a localização do aparelho ou digitar as coordenadas manualmente.
class LocationOnboardingScreen extends ConsumerStatefulWidget {
  const LocationOnboardingScreen({super.key});

  @override
  ConsumerState<LocationOnboardingScreen> createState() =>
      _LocationOnboardingScreenState();
}

class _LocationOnboardingScreenState
    extends ConsumerState<LocationOnboardingScreen> {
  bool _requesting = false;

  Future<void> _requestLocation() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final coordinates = await ref
          .read(locationServiceProvider)
          .getCurrentLocation();
      ref.read(coordinatesProvider.notifier).state = coordinates;
      if (!mounted) return;
      context.go('/');
    } on LocationException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Não foi possível obter sua localização.');
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openManualEntry() {
    context.push('/onboarding/coordinates');
  }

  void _skip() => context.go('/');

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final illustrationSize = (media.width * 0.62).clamp(200.0, 300.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const _StepIndicator(step: 1, total: 3),
                            const Spacer(),
                            TextButton(
                              onPressed: _skip,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.grayDark,
                                textStyle: AppTypography.inter(
                                  AppColors.grayDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Pular'),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Center(
                          child: _LocationIllustration(size: illustrationSize),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          'Onde você está?',
                          textAlign: TextAlign.center,
                          style: AppTypography.sora(
                            AppColors.charcoal,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'O Firewatch usa sua latitude e longitude para buscar o clima do '
                          'local e calcular o risco de queimada.',
                          textAlign: TextAlign.center,
                          style: AppTypography.inter(
                            AppColors.gray,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        FilledButton(
                          onPressed: _requesting ? null : _requestLocation,
                          child: _requesting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Text('Permitir localização'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
                          onPressed: _requesting ? null : _openManualEntry,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.white,
                            foregroundColor: AppColors.charcoal,
                            side: const BorderSide(
                              color: AppColors.charcoal,
                              width: 1.2,
                            ),
                            textStyle: AppTypography.inter(
                              AppColors.charcoal,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Digitar coordenadas'),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Indicador de progresso segmentado exibido no topo da etapa.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: i == step - 1 ? 22 : 10,
            height: 6,
            decoration: BoxDecoration(
              color: i < step ? AppColors.orange : AppColors.border,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ],
      ],
    );
  }
}

/// Ilustração central: círculos concêntricos em creme/laranja com um pino.
class _LocationIllustration extends StatelessWidget {
  const _LocationIllustration({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _ConcentricRingsPainter(),
          ),
          Container(
            width: size * 0.34,
            height: size * 0.34,
            decoration: const BoxDecoration(
              color: AppColors.orange,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: AppColors.white,
              size: size * 0.18,
            ),
          ),
        ],
      ),
    );
  }
}

/// Desenha os anéis concêntricos em tons de creme e laranja.
class _ConcentricRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    const rings = <(double, Color)>[
      (0.98, Color(0x33FFB347)),
      (0.80, Color(0x2EFF6B1A)),
      (0.62, Color(0x3DFFB347)),
      (0.46, Color(0x40FF6B1A)),
    ];

    for (final (scale, color) in rings) {
      canvas.drawCircle(center, maxRadius * scale, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
