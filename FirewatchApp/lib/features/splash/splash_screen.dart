import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/flame_logo.dart';

/// Abertura com a assinatura e o símbolo de destaque do brand board.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
                            onPressed: () => context.go('/onboarding/location'),
                            child: const Text(AppConstants.splashStartLabel),
                          ),
                        ),
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
