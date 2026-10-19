import 'package:firewatch/core/constants/brand_assets.dart';
import 'package:firewatch/core/models/risk_level.dart';
import 'package:firewatch/core/models/risk_prediction.dart';
import 'package:firewatch/core/theme/app_colors.dart';
import 'package:firewatch/core/theme/app_theme.dart';
import 'package:firewatch/shared/widgets/flame_logo.dart';
import 'package:firewatch/shared/widgets/risk_result_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assets = [
    BrandAssets.symbolEmber,
    BrandAssets.symbolCharcoal,
    BrandAssets.symbolHero,
    BrandAssets.wordmarkCharcoal,
    BrandAssets.wordmarkAsh,
    BrandAssets.logoPrimary,
    BrandAssets.logoOnDark,
    BrandAssets.logoOnEmber,
    BrandAssets.appIconEmber,
    BrandAssets.appIconCharcoal,
    BrandAssets.appIconAsh,
  ];
  for (final asset in assets) {
    testWidgets('carrega o vetor oficial $asset', (tester) async {
      await tester.pumpWidget(MaterialApp(home: SvgPicture.asset(asset)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('assinatura troca para o wordmark claro em fundo escuro', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          home: const Scaffold(body: FirewatchWordmark(compact: true)),
        ),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        (image.bytesLoader as SvgAssetLoader).assetName,
        dark ? BrandAssets.logoOnDark : BrandAssets.logoPrimary,
      );
      expect(tester.takeException(), isNull);
    }
  });

  for (final level in RiskLevel.values) {
    testWidgets('resultado ${level.label} cabe em celular com texto ampliado', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prediction = RiskPrediction(
        latitude: -20.5386,
        longitude: -47.4008,
        weather: const WeatherReadings(
          temperature: 33.5,
          humidity: 19,
          precipitation: 0,
          windSpeed: 16.2,
        ),
        level: level,
        probability: 0.864,
        percentageLabel: '86.4%',
        recommendation: 'Acompanhe os avisos oficiais.',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: Scaffold(
            body: RiskResultSheet(
              prediction: prediction,
              locationName: 'Franca, SP',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('86.4%'), findsOneWidget);
      expect(find.text(level.label), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('cores de texto da marca mantêm contraste AA', () {
    double contrast(Color a, Color b) {
      final values = [a.computeLuminance(), b.computeLuminance()]..sort();
      return (values.last + 0.05) / (values.first + 0.05);
    }

    expect(
      contrast(AppColors.charcoal, AppColors.orange),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(AppColors.orangeText, AppColors.background),
      greaterThanOrEqualTo(4.5),
    );
    for (final level in RiskLevel.values) {
      expect(
        contrast(level.textColor, level.softColor),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('cores das telas demonstrativas seguem os cortes 30 e 70', () {
    expect(RiskLevel.fromPercent(29.9), RiskLevel.low);
    expect(RiskLevel.fromPercent(30), RiskLevel.moderate);
    expect(RiskLevel.fromPercent(69.9), RiskLevel.moderate);
    expect(RiskLevel.fromPercent(70), RiskLevel.critical);
  });
}
