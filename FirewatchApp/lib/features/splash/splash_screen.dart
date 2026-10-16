import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/flame_logo.dart';

/// Tela inicial (boas-vindas) do Firewatch.
///
/// Fundo quase preto com um brilho radial em tons de marrom/laranja atrás do
/// logotipo, seguido pelo nome, frase de apresentação, o botão "Começar" e a
/// identificação do projeto. O botão leva à tela principal existente
/// (onboarding de localização), preservando a navegação atual.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _glowController;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _glow;

  /// Evita navegação duplicada em toques consecutivos.
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _logoFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.84, end: 1).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0, 0.75, curve: Curves.easeOutBack),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.35, 1, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.28),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
      ),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _introController.forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  /// Segue para a tela principal existente (fluxo de localização).
  void _continue() {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go('/onboarding/location');
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final logoSize = (media.width * 0.30).clamp(112.0, 156.0);
    final nameSize = (media.width * 0.118).clamp(34.0, 42.0);
    final phraseSize = (media.width * 0.044).clamp(14.0, 16.0);

    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        _BrandBlock(
                          logoSize: logoSize,
                          nameSize: nameSize,
                          phraseSize: phraseSize,
                          logoFade: _logoFade,
                          logoScale: _logoScale,
                          textFade: _textFade,
                          textSlide: _textSlide,
                          glow: _glow,
                        ),
                        const Spacer(flex: 4),
                        _StartButton(
                          height: 56,
                          label: AppConstants.splashStartLabel,
                          onPressed: _continue,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          AppConstants.splashProjectLabel,
                          textAlign: TextAlign.center,
                          style: AppTypography.mono(
                            AppColors.splashTextMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 8),
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

/// Chama com olho, brilho radial e a frase de apresentação.
class _BrandBlock extends StatelessWidget {
  const _BrandBlock({
    required this.logoSize,
    required this.nameSize,
    required this.phraseSize,
    required this.logoFade,
    required this.logoScale,
    required this.textFade,
    required this.textSlide,
    required this.glow,
  });

  final double logoSize;
  final double nameSize;
  final double phraseSize;
  final Animation<double> logoFade;
  final Animation<double> logoScale;
  final Animation<double> textFade;
  final Animation<Offset> textSlide;
  final Animation<double> glow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: logoSize * 2,
          height: logoSize * 1.9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Iluminação radial discreta em tons de marrom e laranja escuro.
              AnimatedBuilder(
                animation: glow,
                builder: (context, child) {
                  final reach = 1.35 + 0.22 * glow.value;
                  return Container(
                    width: logoSize * reach,
                    height: logoSize * reach,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.splashGlowOrange.withValues(
                            alpha: 0.30 * glow.value,
                          ),
                          AppColors.splashGlowBrown.withValues(
                            alpha: 0.20 * glow.value,
                          ),
                          AppColors.splashGlowBrown.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  );
                },
              ),
              FadeTransition(
                opacity: logoFade,
                child: ScaleTransition(
                  scale: logoScale,
                  child: FlameLogo(size: logoSize),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          AppConstants.appName.toLowerCase(),
          textAlign: TextAlign.center,
          style: AppTypography.inter(
            AppColors.splashTextPrimary,
            fontSize: nameSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        SlideTransition(
          position: textSlide,
          child: FadeTransition(
            opacity: textFade,
            child: Text(
              AppConstants.splashPhrase,
              textAlign: TextAlign.center,
              style: AppTypography.inter(
                AppColors.splashTextSecondary,
                fontSize: phraseSize,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Botão principal "Começar" com feedback visual de pressão.
class _StartButton extends StatefulWidget {
  const _StartButton({
    required this.height,
    required this.label,
    required this.onPressed,
  });

  final double height;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: Material(
          color: AppColors.splashButton,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            splashColor: AppColors.splashButtonText.withValues(alpha: 0.08),
            highlightColor: AppColors.splashButtonText.withValues(alpha: 0.06),
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.onPressed,
            child: Center(
              child: Text(
                widget.label,
                style: AppTypography.inter(
                  AppColors.splashButtonText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
