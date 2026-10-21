import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models/geo_coordinates.dart';
import '../../core/models/regional_risk.dart';
import '../../core/providers/app_providers.dart';
import '../../services/api_service.dart';

class RegionalRiskState {
  const RegionalRiskState({
    this.region,
    this.loading = false,
    this.error,
    this.expired = false,
  });
  final RegionalRisk? region;
  final bool loading;
  final String? error;
  final bool expired;
}

final regionalRiskProvider =
    StateNotifierProvider<RegionalRiskController, RegionalRiskState>((ref) {
      final controller = RegionalRiskController(ref.watch(apiServiceProvider));
      ref.listen<GeoCoordinates?>(coordinatesProvider, (previous, next) {
        if (previous?.latitude != next?.latitude ||
            previous?.longitude != next?.longitude) {
          controller.clear();
        }
      });
      return controller;
    });

class RegionalRiskController extends StateNotifier<RegionalRiskState> {
  RegionalRiskController(this._api) : super(const RegionalRiskState());
  final ApiService _api;
  int _request = 0;
  Timer? _expiry;

  void clear() {
    ++_request;
    _expiry?.cancel();
    state = const RegionalRiskState();
  }

  Future<void> analyze(LatLng center) async {
    final request = ++_request;
    _expiry?.cancel();
    state = const RegionalRiskState(loading: true);
    try {
      final json = await _api.preverRegiao(center.latitude, center.longitude);
      if (!mounted || request != _request) return;
      final region = RegionalRisk.fromJson(json);
      if ((region.center.latitude - center.latitude).abs() > 0.0001 ||
          (region.center.longitude - center.longitude).abs() > 0.0001) {
        throw const FormatException('A região não corresponde à solicitação.');
      }
      final expiresAt = region.nextExpiry;
      final expired = expiresAt != null && !expiresAt.isAfter(DateTime.now());
      state = RegionalRiskState(region: region, expired: expired);
      if (expiresAt != null && !expired) {
        _expiry = Timer(expiresAt.difference(DateTime.now()), () {
          if (mounted && request == _request) {
            state = RegionalRiskState(region: region, expired: true);
          }
        });
      }
    } catch (error) {
      if (!mounted || request != _request) return;
      state = RegionalRiskState(
        error: error is ApiException
            ? error.statusCode == 404
                  ? 'As zonas de risco ainda não estão disponíveis. Tente novamente mais tarde.'
                  : error.message
            : 'Não foi possível ler a análise regional. Tente novamente.',
      );
    }
  }

  @override
  void dispose() {
    ++_request;
    _expiry?.cancel();
    super.dispose();
  }
}
