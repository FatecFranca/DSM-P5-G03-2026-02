import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/flame_logo.dart';

/// Apenas preferências com efeito no aplicativo e informações de origem.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final point = ref.watch(coordinatesProvider);
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Aparência', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Claro'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Escuro'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (values) =>
                ref.read(themeModeProvider.notifier).state = values.first,
          ),
          const SizedBox(height: 8),
          const Text('O tema escolhido vale durante esta sessão.'),
          const SizedBox(height: 32),
          Text('Localização', style: Theme.of(context).textTheme.titleLarge),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_on_outlined),
            title: Text(
              point == null
                  ? 'Escolher localização'
                  : ref.watch(locationProvider),
            ),
            subtitle: Text(
              point?.label ?? 'Cidade, coordenadas ou um ponto no mapa',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/onboarding/coordinates'),
          ),
          const SizedBox(height: 24),
          Text('Sobre os dados', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Text(
            'Clima e classificação: API FireWatch. O servidor consulta a Open-Meteo e executa o modelo de risco.\n\nMapa: © OpenStreetMap contributors. Busca de cidades: Open-Meteo / GeoNames. Nome do local no mapa: Nominatim / OpenStreetMap.\n\nA classificação é uma estimativa do modelo. Ela não confirma a existência de incêndio.',
          ),
          const SizedBox(height: 32),
          const Center(child: FirewatchWordmark(compact: true)),
          const SizedBox(height: 16),
          Center(child: Text('Versão ${AppConstants.version}')),
        ],
      ),
    );
  }
}
