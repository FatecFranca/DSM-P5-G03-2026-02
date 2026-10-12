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

  RiskAlert copyWith({bool? isRead}) {
    return RiskAlert(
      id: id,
      severity: severity,
      title: title,
      description: description,
      location: location,
      time: time,
      isRead: isRead ?? this.isRead,
      extra: extra,
    );
  }
}