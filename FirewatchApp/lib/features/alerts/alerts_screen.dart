import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/risk_level.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/app_header.dart';

/// Orientação da última consulta real, sem gerar ocorrências ou avisos fictícios.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prediction = ref.watch(riskPredictionProvider);
    final time = ref.watch(riskQueryTimeProvider);
    final elevated = prediction != null && prediction.level != RiskLevel.low;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          children: [
            const AppHeader(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Alertas',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Orientações de risco da última consulta. Não são notificações automáticas nem confirmação de incêndio.',
                  ),
                  const SizedBox(height: 24),
                  if (prediction == null) ...[
                    const Icon(Icons.notifications_none, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhuma consulta disponível.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Consultar um local'),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: prediction.level.softColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            elevated
                                ? Icons.warning_amber
                                : Icons.check_circle_outline,
                            color: prediction.level.textColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            elevated
                                ? 'Risco ${prediction.level.label.toLowerCase()}'
                                : 'Nenhum alerta de risco elevado nesta consulta',
                            style: TextStyle(
                              color: prediction.level.textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ref.watch(locationProvider),
                            style: TextStyle(color: prediction.level.textColor),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            prediction.recommendation,
                            style: TextStyle(
                              color: prediction.level.textColor,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (time != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Consulta em ${time.day}/${time.month} às ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => context.push('/risk-details'),
                      child: const Text('Ver análise do local'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
