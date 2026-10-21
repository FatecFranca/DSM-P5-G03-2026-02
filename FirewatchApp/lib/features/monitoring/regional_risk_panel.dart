import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/regional_risk.dart';
import '../../core/models/risk_level.dart';
import 'regional_risk_controller.dart';

class RegionalRiskPanel extends StatelessWidget {
  const RegionalRiskPanel({
    super.key,
    required this.state,
    required this.onZone,
  });
  final RegionalRiskState state;
  final ValueChanged<RiskZone> onZone;

  @override
  Widget build(BuildContext context) {
    final region = state.region;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Risco estimado na região',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (state.loading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text(
            'Analisando até nove zonas. Isso pode levar alguns segundos…',
          ),
        ] else if (state.error != null)
          Text(state.error!, style: TextStyle(color: scheme.error))
        else if (region != null) ...[
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final level in RiskLevel.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.square_rounded, size: 14, color: level.color),
                    const SizedBox(width: 4),
                    Text(level.label),
                  ],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_4x4, size: 16, color: scheme.outline),
                  const SizedBox(width: 4),
                  const Text('Sem dados'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.expired)
            const Text(
              'Dados vencidos. Analise a região novamente para atualizar.',
            )
          else
            Text(
              '${region.zones.where((zone) => zone.prediction != null).length} de ${region.zones.length} zonas com dados · API FireWatch',
            ),
          Text(
            'Centro analisado: ${region.center.latitude.toStringAsFixed(3)}, ${region.center.longitude.toStringAsFixed(3)}',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Passo da grade: ${region.resolution}° · escala regional experimental.',
            style: const TextStyle(fontSize: 12),
          ),
          const Text(
            'Amostragem regional experimental. Cada zona usa uma previsão pontual; não indica fogo detectado nem precisão por rua.',
            style: TextStyle(fontSize: 12),
          ),
          TextButton.icon(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (sheetContext) => Consumer(
                builder: (context, ref, child) {
                  final current = ref.watch(regionalRiskProvider);
                  final unavailable =
                      current.expired || !identical(current.region, region);
                  return SafeArea(
                    child: SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.65,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            'Zonas avaliadas',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          for (
                            var index = 0;
                            index < region.zones.length;
                            index++
                          )
                            ListTile(
                              leading: Icon(
                                Icons.layers_outlined,
                                color: unavailable
                                    ? scheme.outline
                                    : region
                                              .zones[index]
                                              .prediction
                                              ?.level
                                              .color ??
                                          scheme.outline,
                              ),
                              title: Text(
                                'Zona ${index + 1} · ${unavailable ? 'Dados vencidos ou indisponíveis' : region.zones[index].prediction?.level.label ?? 'Sem dados'}',
                              ),
                              subtitle: Text(
                                '${region.zones[index].sample.latitude.toStringAsFixed(3)}, ${region.zones[index].sample.longitude.toStringAsFixed(3)}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                onZone(region.zones[index]);
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            icon: const Icon(Icons.list_alt),
            label: Text('Ver ${region.zones.length} zonas'),
          ),
        ],
        const Divider(height: 24),
      ],
    );
  }
}
