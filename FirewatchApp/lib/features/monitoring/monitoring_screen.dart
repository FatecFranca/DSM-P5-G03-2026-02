import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models/geo_coordinates.dart';
import '../../core/models/risk_prediction.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/risk_result_sheet.dart';
import '../../shared/widgets/weather_metric_card.dart';

final mapTileProviderProvider = Provider<TileProvider>(
  (ref) => NetworkTileProvider(),
);

/// Mapa real com seleção explícita e análise pontual devolvida pela API.
class MonitoringScreen extends ConsumerStatefulWidget {
  const MonitoringScreen({super.key});
  @override
  ConsumerState<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends ConsumerState<MonitoringScreen> {
  static const _defaultCenter = LatLng(-20.5386, -47.4008);
  final _mapController = MapController();
  bool _mapReady = false;
  bool _loading = false;
  bool _locating = false;
  String? _error;
  int _requestVersion = 0;

  bool _same(GeoCoordinates? a, GeoCoordinates? b) =>
      a?.latitude == b?.latitude && a?.longitude == b?.longitude;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final point = ref.read(coordinatesProvider);
      if (point != null) {
        _resolveName(point);
        if (ref.read(riskPredictionProvider) == null) _loadPrediction();
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _resolveName(GeoCoordinates point) async {
    try {
      final name = await ref.read(geocodingServiceProvider).reverse(point);
      if (!mounted || !_same(point, ref.read(coordinatesProvider))) return;
      if (name != null && name.isNotEmpty) {
        ref.read(locationProvider.notifier).state = name;
      }
    } catch (_) {
      // As coordenadas continuam disponíveis quando o nome não é resolvido.
    }
  }

  void _select(GeoCoordinates point) {
    if (_same(point, ref.read(coordinatesProvider))) return;
    ref.read(locationProvider.notifier).state = point.label;
    ref.read(coordinatesProvider.notifier).state = point;
  }

  Future<void> _loadPrediction() async {
    final point = ref.read(coordinatesProvider);
    if (point == null) return;
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await ref
          .read(apiServiceProvider)
          .preverRisco(point.latitude, point.longitude);
      final prediction = RiskPrediction.fromJson(json);
      if (!mounted ||
          version != _requestVersion ||
          !_same(point, ref.read(coordinatesProvider))) {
        return;
      }
      if ((prediction.latitude - point.latitude).abs() > 0.0001 ||
          (prediction.longitude - point.longitude).abs() > 0.0001) {
        throw const FormatException(
          'A resposta não corresponde ao local selecionado.',
        );
      }
      ref.read(riskPredictionProvider.notifier).state = prediction;
      ref.read(riskQueryTimeProvider.notifier).state = DateTime.now();
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(
        () => _error = error is ApiException
            ? error.message
            : 'Não foi possível consultar este local. Tente novamente.',
      );
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final point = await ref
          .read(locationServiceProvider)
          .getCurrentLocation();
      if (!mounted) return;
      _select(point);
      if (_mapReady) {
        _mapController.move(LatLng(point.latitude, point.longitude), 13);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível obter sua localização. Busque uma cidade ou toque no mapa.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showResult(RiskPrediction prediction) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => RiskResultSheet(
      prediction: prediction,
      locationName: ref.read(locationProvider),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen<GeoCoordinates?>(coordinatesProvider, (previous, next) {
      if (identical(previous, next)) return;
      ++_requestVersion;
      ref.read(riskPredictionProvider.notifier).state = null;
      ref.read(riskQueryTimeProvider.notifier).state = null;
      setState(() {
        _loading = false;
        _error = null;
      });
      if (next != null) {
        if (_mapReady) {
          _mapController.move(LatLng(next.latitude, next.longitude), 13);
        }
        _resolveName(next);
        _loadPrediction();
      }
    });
    final point = ref.watch(coordinatesProvider);
    final prediction = ref.watch(riskPredictionProvider);
    final name = ref.watch(locationProvider);
    final queryTime = ref.watch(riskQueryTimeProvider);
    final scheme = Theme.of(context).colorScheme;
    final center = point == null
        ? _defaultCenter
        : LatLng(point.latitude, point.longitude);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 12,
                      minZoom: 3,
                      maxZoom: 18,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onMapReady: () => _mapReady = true,
                      onTap: (_, location) => _select(
                        GeoCoordinates(
                          latitude: location.latitude,
                          longitude: location.longitude,
                        ),
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.firewatch',
                        tileProvider: ref.watch(mapTileProviderProvider),
                      ),
                      if (point != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: center,
                              width: 48,
                              height: 48,
                              child: Semantics(
                                label: 'Local selecionado para consulta',
                                child: const Icon(
                                  Icons.location_on,
                                  color: AppColors.orangeText,
                                  size: 40,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const Align(
                        alignment: Alignment.bottomLeft,
                        child: ColoredBox(
                          color: AppColors.background,
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Text(
                              '© OpenStreetMap contributors',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.charcoal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Material(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              elevation: 3,
                              child: ListTile(
                                leading: const Icon(Icons.search),
                                title: Text(
                                  point == null ? 'Escolher localização' : name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  point?.label ??
                                      'Busque uma cidade ou toque no mapa',
                                  maxLines: 2,
                                ),
                                onTap: () =>
                                    context.push('/onboarding/coordinates'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: scheme.surface,
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: IconButton(
                              tooltip: 'Configurações',
                              onPressed: () => context.push('/settings'),
                              icon: const Icon(Icons.settings_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 32,
                    child: Material(
                      color: scheme.surface,
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: IconButton(
                        tooltip: 'Usar minha localização',
                        onPressed: _locating ? null : _locate,
                        icon: _locating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.52,
              ),
              child: Material(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Risco no local',
                              style: AppTypography.sora(
                                scheme.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (point != null)
                            IconButton(
                              tooltip: 'Atualizar consulta',
                              onPressed: _loading ? null : _loadPrediction,
                              icon: const Icon(Icons.refresh),
                            ),
                        ],
                      ),
                      if (point == null)
                        const Text(
                          'Selecione um ponto para consultar o clima e a classificação de risco.',
                        )
                      else if (_loading) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        const Text('Consultando o local selecionado…'),
                      ] else if (_error != null) ...[
                        Text(_error!, style: TextStyle(color: scheme.error)),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loadPrediction,
                          child: const Text('Tentar novamente'),
                        ),
                      ] else if (prediction != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: prediction.level.softColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Risco ${prediction.level.label.toLowerCase()}',
                            style: AppTypography.sora(
                              prediction.level.textColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (queryTime != null)
                          Text(
                            'Consultado às ${queryTime.hour.toString().padLeft(2, '0')}:${queryTime.minute.toString().padLeft(2, '0')} · API FireWatch',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => _showResult(prediction),
                          child: const Text('Ver análise do local'),
                        ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Condições meteorológicas'),
                          children: [
                            LayoutBuilder(
                              builder: (context, box) => Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final metric in [
                                    (
                                      Icons.thermostat_outlined,
                                      'Temperatura',
                                      prediction.weather.temperature,
                                      '°C',
                                    ),
                                    (
                                      Icons.water_drop_outlined,
                                      'Umidade do ar',
                                      prediction.weather.humidity,
                                      '%',
                                    ),
                                    (
                                      Icons.grain,
                                      'Precipitação',
                                      prediction.weather.precipitation,
                                      'mm',
                                    ),
                                    (
                                      Icons.air,
                                      'Vento',
                                      prediction.weather.windSpeed,
                                      'km/h',
                                    ),
                                  ])
                                    SizedBox(
                                      width: box.maxWidth < 270
                                          ? box.maxWidth
                                          : (box.maxWidth - 12) / 2,
                                      child: WeatherMetricCard(
                                        icon: metric.$1,
                                        label: metric.$2,
                                        value: metric.$3.toStringAsFixed(1),
                                        unit: metric.$4,
                                        iconColor:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppColors.amber
                                            : AppColors.orangeText,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Consulta pontual. Toque no mapa para escolher outro local.',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
