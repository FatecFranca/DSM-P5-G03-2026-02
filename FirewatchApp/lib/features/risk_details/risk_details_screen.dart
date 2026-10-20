import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../shared/widgets/risk_result_sheet.dart';

class RiskDetailsScreen extends ConsumerWidget {
  const RiskDetailsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prediction = ref.watch(riskPredictionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Análise do local')),
      body: prediction == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Consulte um local no mapa para ver a análise.'),
              ),
            )
          : RiskResultSheet(
              prediction: prediction,
              locationName: ref.watch(locationProvider),
            ),
    );
  }
}
