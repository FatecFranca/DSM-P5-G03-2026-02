/// Par de coordenadas geográficas (latitude/longitude).
///
/// Usado tanto para a posição obtida do GPS quanto para a entrada manual.
class GeoCoordinates {
  const GeoCoordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  /// Rótulo curto e legível das coordenadas.
  String get label =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

  @override
  String toString() => label;
}
