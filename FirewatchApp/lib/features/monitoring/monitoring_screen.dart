import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/geo_coordinates.dart';
import '../../core/models/risk_level.dart';
import '../../core/models/risk_prediction.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/shell/app_shell.dart';
import '../../services/api_service.dart';

/// Fonte dos tiles do mapa. Substituível em testes para evitar rede.
final mapTileProviderProvider = Provider<TileProvider>(
  (ref) => NetworkTileProvider(),
);

/// Tela de mapa e monitoramento do FireWatch.
///
/// Exibe um mapa interativo centrado nas coordenadas informadas pelo usuário,
/// cartão de localização, legenda de risco e um painel inferior com as
/// condições atuais (dados reais da API) e o botão "Verificar risco aqui".
class MonitoringScreen extends ConsumerStatefulWidget {
  const MonitoringScreen({super.key});

  @override
  ConsumerState<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends ConsumerState<MonitoringScreen> {
  static const double _initialZoom = 13;

  final MapController _mapController = MapController();

  GeoCoordinates? _coordinates;
  RiskPrediction? _prediction;
  String? _locationName;

  bool _loadingConditions = false;
  bool _loadingLocation = false;
  bool _verifying = false;
  String? _conditionsError;

  DateTime? _lastUpdated;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _coordinates = ref.read(coordinatesProvider);
    if (_coordinates != null) {
      final cached = ref.read(riskPredictionProvider);
      if (cached != null && _matchesCoordinates(cached, _coordinates!)) {
        _prediction = cached;
        _lastUpdated = DateTime.now();
      } else {
        _loadConditions();
      }
      _resolveLocationName();
    }
    _clock = Timer.periodic(
      const Duration(seconds: 30),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  LatLng get _center =>
      LatLng(_coordinates!.latitude, _coordinates!.longitude);

  /// Verifica se uma previsão corresponde às coordenadas atuais.
  bool _matchesCoordinates(RiskPrediction prediction, GeoCoordinates coordinates) {
    const tolerance = 0.0001;
    return (prediction.latitude - coordinates.latitude).abs() < tolerance &&
        (prediction.longitude - coordinates.longitude).abs() < tolerance;
  }

  /// Mensagem amigável para falhas de consulta à API.
  String _errorMessage(Object error) {
    if (error is ApiException) {
      return switch (error.statusCode) {
        422 => 'As coordenadas informadas são inválidas.',
        503 =>
          'Serviço de previsão indisponível no momento. Tente novamente mais tarde.',
        _ => error.message,
      };
    }
    if (error is FormatException) {
      return 'Resposta inesperada do serviço. Tente novamente.';
    }
    return 'Não foi possível consultar o risco agora. Tente novamente.';
  }

  Future<void> _loadConditions() async {
    final coordinates = _coordinates;
    if (coordinates == null) return;
    setState(() {
      _loadingConditions = true;
      _conditionsError = null;
    });
    try {
      final json = await ref
          .read(apiServiceProvider)
          .preverRisco(coordinates.latitude, coordinates.longitude);
      final prediction = RiskPrediction.fromJson(json);
      if (!mounted) return;
      ref.read(riskPredictionProvider.notifier).state = prediction;
      setState(() {
        _prediction = prediction;
        _lastUpdated = DateTime.now();
        _loadingConditions = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _conditionsError = _errorMessage(error);
        _loadingConditions = false;
      });
    }
  }

  Future<void> _resolveLocationName() async {
    final coordinates = _coordinates;
    if (coordinates == null) return;
    setState(() => _loadingLocation = true);
    try {
      final name = await ref.read(geocodingServiceProvider).reverse(coordinates);
      if (!mounted) return;
      setState(() {
        _locationName = name;
        _loadingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _verifyRisk() async {
    final coordinates = _coordinates;
    if (coordinates == null || _verifying) return;
    setState(() => _verifying = true);
    try {
      final json = await ref
          .read(apiServiceProvider)
          .preverRisco(coordinates.latitude, coordinates.longitude);
      final prediction = RiskPrediction.fromJson(json);
      if (!mounted) return;
      ref.read(riskPredictionProvider.notifier).state = prediction;
      setState(() {
        _prediction = prediction;
        _conditionsError = null;
        _lastUpdated = DateTime.now();
        _verifying = false;
      });
      _showRiskResult(prediction);
    } catch (error) {
      if (!mounted) return;
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_errorMessage(error))),
        );
    }
  }

  void _showRiskResult(RiskPrediction prediction) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panelBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _RiskResultSheet(prediction: prediction),
    );
  }

  void _recenter() {
    if (_coordinates == null) return;
    _mapController.move(_center, _initialZoom);
  }

  String _updatedLabel() {
    final last = _lastUpdated;
    if (last == null) return '';
    final difference = DateTime.now().difference(last);
    if (difference.inSeconds < 60) return 'atualizado agora';
    if (difference.inMinutes < 60) return 'atualizado há ${difference.inMinutes} min';
    return 'atualizado há ${difference.inHours} h';
  }

  @override
  Widget build(BuildContext context) {
    final coordinates = _coordinates;
    if (coordinates == null) {
      return _MissingCoordinatesView();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _MonitoringMap(
                  controller: _mapController,
                  center: _center,
                  initialZoom: _initialZoom,
                  tileProvider: ref.watch(mapTileProviderProvider),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LocationCard(
                            title: _locationName ??
                                (_loadingLocation
                                    ? 'Localizando…'
                                    : 'Localização selecionada'),
                            coordinates: coordinates,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const _RiskLegend(),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                  child: _LocateButton(onTap: _recenter),
                ),
              ],
            ),
          ),
          _ConditionsPanel(
            prediction: _prediction,
            loading: _loadingConditions,
            error: _conditionsError,
            updatedLabel: _updatedLabel(),
            verifying: _verifying,
            onVerify: _verifyRisk,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          final dest = ShellDestination.values[index];
          switch (dest) {
            case ShellDestination.home:
              context.go('/');
              break;
            case ShellDestination.forecast:
              context.go('/forecast');
              break;
            case ShellDestination.map:
              context.go('/map');
              break;
            case ShellDestination.alerts:
              context.go('/alerts');
              break;
            case ShellDestination.prevention:
              context.go('/prevention');
              break;
          }
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final d in ShellDestination.values)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.activeIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

/// Mapa interativo com tiles reais do OpenStreetMap e marcador central.
class _MonitoringMap extends StatelessWidget {
  const _MonitoringMap({
    required this.controller,
    required this.center,
    required this.initialZoom,
    required this.tileProvider,
  });

  final MapController controller;
  final LatLng center;
  final double initialZoom;
  final TileProvider tileProvider;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: initialZoom,
        minZoom: 3,
        maxZoom: 18,
        backgroundColor: AppColors.background,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.firewatch',
          maxZoom: 19,
          tileProvider: tileProvider,
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 64,
              height: 64,
              child: const _CenterMarker(),
            ),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text(
            '© OpenStreetMap',
            style: TextStyle(fontSize: 10, color: AppColors.grayDark),
          ),
        ),
      ],
    );
  }
}

/// Marcador circular laranja no ponto selecionado.
class _CenterMarker extends StatelessWidget {
  const _CenterMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.orange,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withValues(alpha: 0.45),
              blurRadius: 14,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartão branco no topo do mapa com cidade, coordenadas e ícone laranja.
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.title, required this.coordinates});

  final String title;
  final GeoCoordinates coordinates;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppColors.orange,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.inter(
                    AppColors.charcoal,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  coordinates.label,
                  style: AppTypography.mono(
                    AppColors.gray,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Legenda horizontal com os três níveis de risco.
class _RiskLegend extends StatelessWidget {
  const _RiskLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.panelBackground.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final level in RiskLevel.values) ...[
            if (level != RiskLevel.values.first)
              const SizedBox(width: AppSpacing.md),
            _LegendItem(level: level),
          ],
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.level});

  final RiskLevel level;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: level.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          level.label.toUpperCase(),
          style: AppTypography.inter(
            AppColors.grayDark,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

/// Botão flutuante de recentralização à direita do mapa.
class _LocateButton extends StatelessWidget {
  const _LocateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panelBackground,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            Icons.my_location_rounded,
            color: AppColors.orange,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Painel branco fixado na base com as condições atuais e o botão de ação.
class _ConditionsPanel extends StatelessWidget {
  const _ConditionsPanel({
    required this.prediction,
    required this.loading,
    required this.error,
    required this.updatedLabel,
    required this.verifying,
    required this.onVerify,
  });

  final RiskPrediction? prediction;
  final bool loading;
  final String? error;
  final String updatedLabel;
  final bool verifying;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final weather = prediction?.weather;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panelBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      AppConstants.conditionsNowLabel,
                      style: AppTypography.inter(
                        AppColors.charcoal,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  if (updatedLabel.isNotEmpty)
                    Text(
                      updatedLabel,
                      style: AppTypography.inter(
                        AppColors.grayLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.riskCritical,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        error!,
                        style: AppTypography.inter(
                          AppColors.riskCritical,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.thermostat_rounded,
                      label: 'Temperatura',
                      value: _format(weather?.temperature, 1),
                      unit: '°C',
                      loading: loading,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.water_drop_outlined,
                      label: 'Umidade do ar',
                      value: _format(weather?.humidity, 0),
                      unit: '%',
                      loading: loading,
                      iconColor: const Color(0xFF0EA5E9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.umbrella_outlined,
                      label: 'Precipitação',
                      value: _format(weather?.precipitation, 1),
                      unit: 'mm',
                      loading: loading,
                      iconColor: const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.air_rounded,
                      label: 'Vento',
                      value: _format(weather?.windSpeed, 1),
                      unit: 'km/h',
                      loading: loading,
                      iconColor: const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 56,
                child: Material(
                  color: AppColors.splashButton,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: verifying ? null : onVerify,
                    child: Center(
                      child: verifying
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.splashButtonText,
                              ),
                            )
                          : Text(
                              AppConstants.verifyRiskLabel,
                              style: AppTypography.inter(
                                AppColors.splashButtonText,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format(double? value, int decimals) {
    if (value == null) return '—';
    return value.toStringAsFixed(decimals);
  }
}

/// Cartão de métrica em fundo cinza-bege muito claro.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.loading,
    this.iconColor = AppColors.orange,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final bool loading;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.metricCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.metricCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.inter(
                    AppColors.gray,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (loading)
            Container(
              width: 54,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.metricCardBorder,
                borderRadius: BorderRadius.circular(6),
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: AppTypography.mono(
                      AppColors.charcoal,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    unit,
                    style: AppTypography.inter(
                      AppColors.gray,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Painel com o resultado real da verificação de risco.
class _RiskResultSheet extends StatelessWidget {
  const _RiskResultSheet({required this.prediction});

  final RiskPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final level = prediction.level;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: level.softColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: level.textColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Risco de queimada',
                        style: AppTypography.inter(
                          AppColors.gray,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        level.label,
                        style: AppTypography.sora(
                          level.textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  prediction.percentageLabel,
                  style: AppTypography.mono(
                    level.textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: prediction.probability,
                minHeight: 8,
                color: level.color,
                backgroundColor: AppColors.metricCard,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              prediction.recommendation.isEmpty
                  ? 'Sem recomendação disponível para estas condições.'
                  : prediction.recommendation,
              style: AppTypography.inter(
                AppColors.charcoal,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: AppColors.gray,
                ),
                const SizedBox(width: 6),
                Text(
                  '${prediction.latitude.toStringAsFixed(4)}, '
                  '${prediction.longitude.toStringAsFixed(4)}',
                  style: AppTypography.mono(
                    AppColors.gray,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Exibida quando nenhuma coordenada foi informada ainda.
class _MissingCoordinatesView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Monitoramento',
          style: AppTypography.sora(
            AppColors.charcoal,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off_rounded,
                size: 48,
                color: AppColors.gray,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Nenhuma coordenada informada.',
                textAlign: TextAlign.center,
                style: AppTypography.inter(
                  AppColors.charcoal,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Informe a latitude e a longitude para monitorar o risco na sua região.',
                textAlign: TextAlign.center,
                style: AppTypography.inter(
                  AppColors.gray,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => context.go('/onboarding/coordinates'),
                child: const Text('Informar coordenadas'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
