import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/geo_coordinates.dart';
import '../../core/providers/app_providers.dart';
import '../../services/geocoding_service.dart';

/// Escolha geográfica independente da disponibilidade da API de risco.
class CoordinatesScreen extends ConsumerStatefulWidget {
  const CoordinatesScreen({super.key});
  @override
  ConsumerState<CoordinatesScreen> createState() => _CoordinatesScreenState();
}

class _CoordinatesScreenState extends ConsumerState<CoordinatesScreen> {
  final _form = GlobalKey<FormState>();
  final _city = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  List<PlaceResult> _places = [];
  bool _searching = false;
  String? _searchMessage;
  int _searchVersion = 0;

  @override
  void initState() {
    super.initState();
    final point = ref.read(coordinatesProvider);
    if (point != null) {
      _latitude.text = point.latitude.toStringAsFixed(4);
      _longitude.text = point.longitude.toStringAsFixed(4);
    }
  }

  @override
  void dispose() {
    _city.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  double? _number(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  String? _validate(String? raw, double limit, String label) {
    final value = _number(raw ?? '');
    if (value == null || !value.isFinite || value < -limit || value > limit) {
      return 'Informe $label entre -$limit e $limit.';
    }
    return null;
  }

  void _select(GeoCoordinates point, String label) {
    ref.read(riskPredictionProvider.notifier).state = null;
    ref.read(riskQueryTimeProvider.notifier).state = null;
    ref.read(locationProvider.notifier).state = label;
    ref.read(coordinatesProvider.notifier).state = point;
    context.go('/');
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final point = GeoCoordinates(
      latitude: _number(_latitude.text)!,
      longitude: _number(_longitude.text)!,
    );
    _select(point, point.label);
  }

  Future<void> _search() async {
    final name = _city.text.trim();
    if (name.length < 2) {
      setState(
        () => _searchMessage = 'Digite pelo menos duas letras da cidade.',
      );
      return;
    }
    final version = ++_searchVersion;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchMessage = null;
      _places = [];
    });
    try {
      final places = await ref.read(geocodingServiceProvider).search(name);
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _places = places;
        _searchMessage = places.isEmpty
            ? 'Nenhuma cidade encontrada. Tente incluir o estado.'
            : null;
      });
    } catch (_) {
      if (!mounted || version != _searchVersion) return;
      setState(
        () => _searchMessage =
            'Não foi possível buscar cidades. Tente novamente ou use as coordenadas.',
      );
    } finally {
      if (mounted && version == _searchVersion) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escolher localização')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Buscar uma cidade',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            decoration: const InputDecoration(
              labelText: 'Cidade e estado',
              hintText: 'Ex.: Franca, SP',
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _searching ? null : _search,
            icon: _searching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(_searching ? 'Buscando…' : 'Buscar cidade'),
          ),
          if (_searchMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_searchMessage!),
            ),
          for (final place in _places)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(place.label),
              subtitle: Text(place.coordinates.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _select(place.coordinates, place.label),
            ),
          const SizedBox(height: 24),
          const Text(
            'Busca: Open-Meteo / GeoNames.',
            style: TextStyle(fontSize: 12),
          ),
          const Divider(height: 40),
          Text(
            'Ou informe coordenadas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Você também pode escolher um ponto tocando no mapa.'),
          const SizedBox(height: 20),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _latitude,
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    hintText: 'Ex.: -20.5386',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (value) => _validate(value, 90, 'uma latitude'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _longitude,
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    hintText: 'Ex.: -47.4008',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (value) => _validate(value, 180, 'uma longitude'),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: _submit,
                  child: const Text('Confirmar coordenadas'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
