import 'risk_level.dart';

/// Alerta de queimada / risco.
class RiskAlert {
  const RiskAlert({
    required this.id,
    required this.severity,
    required this.title,
    required this.description,
    required this.location,
    required this.time,
    required this.isRead,
    this.extra = false,
  });

  final String id;
  final RiskLevel severity;
  final String title;
  final String description;
  final String location;
  final DateTime time;
  final bool isRead;

  /// Marca alertas demonstrativos criados como exemplos da interface.
  final bool extra;

  RiskAlert copyWith({
    bool? isRead,
    RiskLevel? severity,
    String? title,
    String? description,
    String? location,
    DateTime? time,
    bool? extra,
  }) {
    return RiskAlert(
      id: id,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      time: time ?? this.time,
      isRead: isRead ?? this.isRead,
      extra: extra ?? this.extra,
    );
  }
}