import 'package:flutter/material.dart';

/// Dica educativa da tela de prevenção.
class PreventionTip {
  const PreventionTip({
    required this.icon,
    required this.title,
    required this.description,
    this.emphasis = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool emphasis;
}