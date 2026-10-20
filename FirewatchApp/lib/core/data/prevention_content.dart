import 'package:flutter/material.dart';
import '../models/prevention_tip.dart';

/// Orientações educativas; não representam detecções ou previsões.
abstract final class PreventionContent {
  static const List<PreventionTip> tips = [
    PreventionTip(
      icon: Icons.local_fire_department_outlined,
      title: 'Prevenção de queimadas',
      description:
          'Não queime lixo, entulho ou vegetação. Denuncie queimadas irregulares à Defesa Civil pelo 199.',
      emphasis: true,
    ),
    PreventionTip(
      icon: Icons.water_drop_outlined,
      title: 'Cuidados na baixa umidade',
      description:
          'Com umidade abaixo de 30%, evite atividades que gerem faísca e mantenha recipientes com água em áreas secas.',
    ),
    PreventionTip(
      icon: Icons.yard_outlined,
      title: 'Riscos em áreas de vegetação',
      description:
          'Descartar bitucas de cigarro e garrafas de vidro em áreas verdes é uma das principais causas de incêndio.',
    ),
    PreventionTip(
      icon: Icons.smoke_free_outlined,
      title: 'Ao identificar fumaça',
      description:
          'Identifique a direção do vento, mantenha distância e nunca tente combater o fogo sozinho.',
    ),
    PreventionTip(
      icon: Icons.support_agent_outlined,
      title: 'Como comunicar às autoridades',
      description:
          'Ligue para o Corpo de Bombeiros (193) ou a Defesa Civil (199) informando endereço, ponto de referência e intensidade.',
    ),
  ];
}
