import 'package:flutter/material.dart';

/// Espaçamentos, raios de borda e sombras padronizados.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double page = 20;
}

abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;
}

class AppShadows {
  const AppShadows._();

  static List<BoxShadow> card(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> soft(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}