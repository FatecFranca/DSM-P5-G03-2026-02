import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/location_service.dart';
import '../models/geo_coordinates.dart';
import '../models/risk_prediction.dart';

/// Modo de tema selecionado (claro/escuro). Controlado pela tela de configurações.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

/// Localização selecionada na configuração.
final locationProvider = StateProvider<String>((ref) => 'Local selecionado');

/// Serviço de localização do dispositivo (permissão + GPS).
final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);

/// Coordenadas obtidas via GPS ou digitadas manualmente no onboarding.
final coordinatesProvider = StateProvider<GeoCoordinates?>((ref) => null);

/// Último resultado real de previsão de risco retornado pela API.
///
/// Compartilhado entre o formulário de coordenadas e a tela de monitoramento
/// para evitar consultas duplicadas.
final riskPredictionProvider = StateProvider<RiskPrediction?>((ref) => null);

/// Cliente da API de risco/clima do FireWatch.
final apiServiceProvider = Provider<ApiService>((ref) {
  final service = ApiService();
  ref.onDispose(service.close);
  return service;
});

/// Serviço de geocodificação reversa (coordenadas -> cidade/estado).
final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  final service = GeocodingService();
  ref.onDispose(service.close);
  return service;
});

/// Horário da consulta HTTP concluída, não da observação meteorológica.
final riskQueryTimeProvider = StateProvider<DateTime?>((ref) => null);
