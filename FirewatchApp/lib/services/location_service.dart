import 'package:geolocator/geolocator.dart';

import '../core/models/geo_coordinates.dart';

/// Erro de localização com mensagem amigável para exibição na interface.
class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Serviço responsável por solicitar permissão e obter a posição do aparelho.
class LocationService {
  const LocationService();

  /// Verifica a permissão, solicita quando necessário e retorna a posição
  /// atual do aparelho.
  ///
  /// Lança [LocationException] com uma mensagem amigável em caso de falha.
  Future<GeoCoordinates> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'Ative o serviço de localização do aparelho para continuar.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'Permissão de localização negada. Você pode buscar uma cidade ou escolher um ponto no mapa.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Permissão de localização bloqueada. Busque uma cidade ou habilite o GPS nas configurações do aparelho.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    return GeoCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
