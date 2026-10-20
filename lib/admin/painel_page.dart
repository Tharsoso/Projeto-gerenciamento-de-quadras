import 'package:flutter/material.dart';

import '../auth/autenticacao.dart';

/// Painel do proprietário. A agenda do dia entra aqui nas próximas atividades (5.x).
class PainelPage extends StatelessWidget {
  const PainelPage({super.key, required this.auth});

  final Autenticacao auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do proprietário'),
        actions: [
          TextButton.icon(
            key: const Key('painel-sair'),
            onPressed: auth.sair,
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
        ],
      ),
      body: const Center(child: Text('Agenda do dia (em construção)')),
    );
  }
}
