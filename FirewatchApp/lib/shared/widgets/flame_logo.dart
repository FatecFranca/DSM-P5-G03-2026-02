import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/brand_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Símbolo oficial, com proporções e cores preservadas do arquivo vetorial.
class FlameLogo extends StatelessWidget {
  const FlameLogo({super.key, this.size = 84, this.hero = false});

  final double size;
  final bool hero;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    hero ? BrandAssets.symbolHero : BrandAssets.symbolEmber,
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticsLabel: 'Símbolo Firewatch',
  );
}

/// Wordmark em curvas, sem depender da fonte instalada no dispositivo.
class FirewatchWordmarkText extends StatelessWidget {
  const FirewatchWordmarkText({
    super.key,
    this.light = false,
    this.width = 214,
  });

  final bool light;
  final double width;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    light ? BrandAssets.wordmarkAsh : BrandAssets.wordmarkCharcoal,
    width: width,
    height: width * 35 / 214,
    fit: BoxFit.contain,
    semanticsLabel: 'firewatch',
  );
}

/// Assinatura horizontal oficial, com variante adequada à superfície.
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
    final onDark = light || Theme.of(context).brightness == Brightness.dark;
    final height = compact ? 32.0 : logoSize;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          onDark ? BrandAssets.logoOnDark : BrandAssets.logoPrimary,
          width: height * 268 / 58,
          height: height,
          fit: BoxFit.contain,
          semanticsLabel: 'firewatch',
        ),
        if (!compact) ...[
          const SizedBox(height: 8),
          Text(
            'Veja o risco antes do fogo.',
            style: AppTypography.inter(
              onDark ? AppColors.grayLight : AppColors.grayDark,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
