import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/flame_logo.dart';

/// Abertura com a assinatura e o símbolo de destaque do brand board.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onEnter});
  final Future<void> Function() onEnter;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _enter() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onEnter();
      if (mounted) context.go('/onboarding/location');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível salvar sua preferência. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.charcoal,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 240,
                              height: 200,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.orange.withValues(alpha: 0.18),
                                    AppColors.orange.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                            const FlameLogo(size: 132, hero: true),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const FirewatchWordmarkText(light: true),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          AppConstants.slogan,
                          textAlign: TextAlign.center,
                          style: AppTypography.inter(
                            AppColors.grayLight,
                            fontSize: 17,
                          ),
                        ),
                        const Spacer(flex: 4),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed: _saving ? null : _enter,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(AppConstants.splashStartLabel),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.grayLight),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          AppConstants.splashProjectLabel,
                          textAlign: TextAlign.center,
                          style: AppTypography.mono(
                            AppColors.grayLight,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
