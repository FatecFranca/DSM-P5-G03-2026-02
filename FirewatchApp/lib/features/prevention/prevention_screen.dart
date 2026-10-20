import 'package:flutter/material.dart';

import '../../core/data/prevention_content.dart';
import '../../core/models/prevention_tip.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/section_badge.dart';

/// Tela educativa de prevenção de queimadas.
class PreventionScreen extends StatefulWidget {
  const PreventionScreen({super.key});

  @override
  State<PreventionScreen> createState() => _PreventionScreenState();
}

class _PreventionScreenState extends State<PreventionScreen> {
  final Set<String> _expanded = {};

  void _toggle(String id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                  Text(
                    'Prevenção',
                    style: AppTypography.sora(
                      scheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cuidados e orientações para evitar queimadas.',
                    style: AppTypography.inter(
                      scheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Destaque: denúncia de queimadas.
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.emergency_share_outlined,
                          color: AppColors.charcoal,
                          size: 30,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Em caso de emergência',
                                style: AppTypography.inter(
                                  AppColors.charcoal,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Bombeiros 193 · Defesa Civil 199',
                                style: AppTypography.inter(
                                  AppColors.charcoal,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  const SectionTitle(title: 'Como se proteger'),
                  const SizedBox(height: AppSpacing.md),
                  for (final tip in PreventionContent.tips)
                    _PreventionCard(
                      tip: tip,
                      onToggle: () => _toggle(tip.title),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreventionCard extends StatelessWidget {
  const _PreventionCard({required this.tip, required this.onToggle});

  final PreventionTip tip;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: tip.emphasis
            ? scheme.primary.withValues(alpha: isDark ? 0.12 : 0.06)
            : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: tip.emphasis
                ? AppColors.orange.withValues(alpha: 0.35)
                : border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tip.emphasis
                  ? AppColors.orange.withValues(alpha: 0.15)
                  : AppColors.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tip.icon, size: 22, color: AppColors.orangeDark),
          ),
          title: Text(
            tip.title,
            style: AppTypography.inter(
              scheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Toque para saber mais',
              style: AppTypography.inter(scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          iconColor: AppColors.orange,
          onExpansionChanged: (_) => onToggle(),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tip.description,
              style: AppTypography.inter(
                scheme.onSurfaceVariant,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
