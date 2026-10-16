import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/location_service.dart';
import '../data/demo_data.dart';
import '../models/geo_coordinates.dart';
import '../models/risk_alert.dart';
import '../models/risk_level.dart';

/// Modo de tema selecionado (claro/escuro). Controlado pela tela de configurações.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

/// Localização selecionada na configuração.
final locationProvider = StateProvider<String>((ref) => 'Franca, SP');

/// Serviço de localização do dispositivo (permissão + GPS).
final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());

/// Coordenadas obtidas via GPS ou digitadas manualmente no onboarding.
final coordinatesProvider = StateProvider<GeoCoordinates?>((ref) => null);

/// Filtro de severidade na tela de alertas (null = todos).
final alertSeverityFilterProvider =
    StateProvider<RiskLevel?>((ref) => null);

/// Lista de alertas demonstrativos com estado de leitura mutável.
final alertsProvider =
    StateNotifierProvider<AlertsNotifier, List<RiskAlert>>(
  (ref) => AlertsNotifier(),
);

class AlertsNotifier extends StateNotifier<List<RiskAlert>> {
  AlertsNotifier() : super(DemoSettings.makeAlerts());

  void toggleRead(String id) {
    state = [
      for (final alert in state)
        if (alert.id == id) alert.copyWith(isRead: !alert.isRead) else alert,
    ];
  }

  void markAllRead() {
    state = [
      for (final alert in state) alert.copyWith(isRead: true),
    ];
  }
}

/// Preferências demonstrativas de notificação.
final notificationsProvider =
    StateProvider<Map<String, bool>>((ref) => const {
          'riskAlerts': true,
          'weatherUpdates': true,
          'preventionTips': false,
          'email': false,
        });