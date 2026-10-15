import 'package:flutter/material.dart';

class RiskDisplayScreen extends StatelessWidget {
  final String nivelRisco;
  final String recomendacao;

  const RiskDisplayScreen({
    required this.nivelRisco,
    required this.recomendacao,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Color? corAlert;
    String? titulo;

    if (nivelRisco == 'CRÍTICO') {
      corAlert = Color(0xFFDC2626);
      titulo = 'Alerta Máximo';
    } else if (nivelRisco == 'MODERADO') {
      corAlert = Color(0xFFFACC15);
      titulo = 'Atenção';
    } else {
      corAlert = Color(0xFF22C55E);
      titulo = 'Baixo Risco';
    }

    return Scaffold(
      appBar: AppBar(backgroundColor: corAlert, title: Text(titulo)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: corAlert,
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 50,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nível de Risco: $nivelRisco',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Recomendação: $recomendacao',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
