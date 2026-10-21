import 'package:latlong2/latlong.dart';

import 'risk_prediction.dart';

/// Anéis GeoJSON: primeiro contorno, demais lacunas; coordenadas em WGS84.
class RiskZone {
  const RiskZone({
    required this.id,
    required this.polygons,
    required this.sample,
    this.prediction,
    this.queriedAt,
    this.expiresAt,
    this.weatherTime,
  });

  final String id;
  final List<List<List<LatLng>>> polygons;
  final LatLng sample;
  final RiskPrediction? prediction;
  final DateTime? queriedAt;
  final DateTime? expiresAt;
  final DateTime? weatherTime;

  bool isFresh(DateTime now) =>
      prediction != null && expiresAt != null && expiresAt!.isAfter(now);

  bool contains(LatLng point) => polygons.any(
    (rings) =>
        _inside(point, rings.first) &&
        !rings.skip(1).any((hole) => _inside(point, hole)),
  );

  static bool _inside(LatLng point, List<LatLng> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i];
      final b = ring[j];
      if ((a.latitude > point.latitude) != (b.latitude > point.latitude) &&
          point.longitude <
              (b.longitude - a.longitude) *
                      (point.latitude - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }

  factory RiskZone.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List;
    final List rawPolygons = switch (geometry['type']) {
      'Polygon' => [coordinates],
      'MultiPolygon' => coordinates,
      _ => throw const FormatException('Geometria regional inválida.'),
    };
    final polygons = <List<List<LatLng>>>[];
    for (final rawPolygon in rawPolygons) {
      final rings = <List<LatLng>>[];
      for (final rawRing in rawPolygon as List) {
        final ring = <LatLng>[];
        for (final rawPoint in rawRing as List) {
          ring.add(_point((rawPoint as List)[1], rawPoint[0]));
        }
        if (ring.length < 4 || ring.first != ring.last) {
          throw const FormatException('Contorno regional inválido.');
        }
        rings.add(ring);
      }
      if (rings.isEmpty) throw const FormatException('Zona sem contorno.');
      polygons.add(rings);
    }
    if (polygons.isEmpty) throw const FormatException('Zona vazia.');
    final properties = json['properties'] as Map<String, dynamic>;
    final sample = properties['amostra'] as Map<String, dynamic>;
    final samplePoint = _point(sample['latitude'], sample['longitude']);
    final status = properties['estado'];
    if (status != 'ok' && status != 'sem_dados') {
      throw const FormatException('Estado regional desconhecido.');
    }
    final prediction = status == 'ok'
        ? RiskPrediction.fromJson(
            properties['resultado'] as Map<String, dynamic>,
          )
        : null;
    final queriedAt = _date(properties['consultado_em']);
    final expiresAt = _date(properties['expira_em']);
    if (prediction != null) {
      final values = [
        prediction.latitude,
        prediction.longitude,
        prediction.probability,
        prediction.weather.temperature,
        prediction.weather.humidity,
        prediction.weather.precipitation,
        prediction.weather.windSpeed,
      ];
      if (values.any((value) => !value.isFinite) ||
          (prediction.latitude - samplePoint.latitude).abs() > 0.0001 ||
          (prediction.longitude - samplePoint.longitude).abs() > 0.0001 ||
          queriedAt == null ||
          expiresAt == null ||
          !expiresAt.isAfter(queriedAt)) {
        throw const FormatException('Previsão regional inconsistente.');
      }
    }
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Zona sem identificação.');
    }
    return RiskZone(
      id: id,
      polygons: polygons,
      sample: samplePoint,
      prediction: prediction,
      queriedAt: queriedAt,
      expiresAt: expiresAt,
      weatherTime: _date(properties['horario_meteorologico']),
    );
  }
}

class RegionalRisk {
  const RegionalRisk({
    required this.zones,
    required this.center,
    required this.bbox,
    required this.resolution,
    required this.modelVersion,
  });

  final List<RiskZone> zones;
  final LatLng center;
  final List<double> bbox;
  final double resolution;
  final String modelVersion;

  DateTime? get nextExpiry {
    final dates =
        zones.map((zone) => zone.expiresAt).whereType<DateTime>().toList()
          ..sort();
    return dates.firstOrNull;
  }

  factory RegionalRisk.fromJson(Map<String, dynamic> json) {
    if (json['type'] != 'FeatureCollection') {
      throw const FormatException('Camada inválida.');
    }
    final features = json['features'] as List;
    if (features.isEmpty || features.length > 9) {
      throw const FormatException('Quantidade de zonas inválida.');
    }
    final zones = features
        .map((feature) => RiskZone.fromJson(feature as Map<String, dynamic>))
        .toList();
    if (zones.map((zone) => zone.id).toSet().length != zones.length) {
      throw const FormatException('Zonas duplicadas.');
    }
    final center = json['centro'] as Map<String, dynamic>;
    final bbox = (json['bbox'] as List)
        .map((value) => (value as num).toDouble())
        .toList();
    final resolution = (json['resolucao_graus'] as num).toDouble();
    final version = json['versao_modelo'];
    if (bbox.length != 4 ||
        bbox.any((n) => !n.isFinite) ||
        bbox[0] >= bbox[2] ||
        bbox[1] >= bbox[3] ||
        bbox[0] < -180 ||
        bbox[2] > 180 ||
        bbox[1] < -90 ||
        bbox[3] > 90 ||
        !resolution.isFinite ||
        resolution <= 0 ||
        resolution > 1 ||
        version is! String ||
        version.isEmpty) {
      throw const FormatException('Metadados regionais inválidos.');
    }
    return RegionalRisk(
      zones: zones,
      center: _point(center['latitude'], center['longitude']),
      bbox: bbox,
      resolution: resolution,
      modelVersion: version,
    );
  }
}

LatLng _point(Object? latitude, Object? longitude) {
  if (latitude is! num ||
      longitude is! num ||
      !latitude.isFinite ||
      !longitude.isFinite ||
      latitude.abs() > 90 ||
      longitude.abs() > 180) {
    throw const FormatException('Coordenada regional inválida.');
  }
  return LatLng(latitude.toDouble(), longitude.toDouble());
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw const FormatException('Horário regional sem fuso.');
  }
  return DateTime.parse(value);
}
