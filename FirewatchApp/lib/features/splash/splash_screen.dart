import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/flame_mark.dart';

/// Tela inicial (splash) do Firewatch.
///
/// Marca na região superior, botão "Começar" na região inferior e a
/// identificação do projeto próxima à borda. Ao tocar em "Começar" navega para
/// a tela principal existente.
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
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.55, end: 1).animate(
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

  void _continue() {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final logoSize = (media.width * 0.30).clamp(96.0, 150.0);
    final nameSize = (media.width * 0.062).clamp(22.0, 26.0);
    final phraseSize = (media.width * 0.028).clamp(10.0, 11.0);
    final buttonWidth = (media.width * 0.75).clamp(200.0, 320.0);
    final buttonHeight = (media.height * 0.058).clamp(42.0, 46.0);

    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.splashBorder.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  SizedBox(height: media.height * 0.10),
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
                  const Spacer(),
                  _StartButton(
                    width: buttonWidth,
                    height: buttonHeight,
                    label: AppConstants.splashStartLabel,
                    onPressed: _continue,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppConstants.splashProjectLabel,
                    textAlign: TextAlign.center,
                    style: AppTypography.mono(
                      AppColors.splashTextMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chama com brilho, nome e frase de apresentação.
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
          height: logoSize * 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: glow,
                builder: (context, child) {
                  return Container(
                    width: logoSize * (1.6 + 0.25 * glow.value),
                    height: logoSize * (1.6 + 0.25 * glow.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.orange.withValues(
                            alpha: 0.32 * glow.value,
                          ),
                          AppColors.orange.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  );
                },
              ),
              FadeTransition(
                opacity: logoFade,
                child: ScaleTransition(
                  scale: logoScale,
                  child: FlameMark(size: logoSize),
                ),
              ),
            ],
          ),
        ),
        Text(
          AppConstants.appName.toLowerCase(),
          textAlign: TextAlign.center,
          style: AppTypography.inter(
            AppColors.splashTextPrimary,
            fontSize: nameSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
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
    required this.width,
    required this.height,
    required this.label,
    required this.onPressed,
  });

  final double width;
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
    final radius = BorderRadius.circular(widget.height / 2);

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: SizedBox(
        width: widget.width,
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
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
