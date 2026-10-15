import 'package:flutter/material.dart';

class DatabaseConnectionScreen extends StatelessWidget {
  const DatabaseConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conexão com Banco de Dados')),
      body: const Center(
        child: Text('Tela de configuração de conexão DB - Azure VM'),
      ),
    );
  }
}
