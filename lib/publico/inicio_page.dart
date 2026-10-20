import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Página pública. Provisória: a consulta de horários (4.1) substitui o conteúdo.
class InicioPage extends StatelessWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quadras de Tênis')),
      body: const Center(child: Text('Consulta de horários (em construção)')),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8),
        child: TextButton(
          onPressed: () => context.go('/admin'),
          child: const Text('Área do proprietário'),
        ),
      ),
    );
  }
}
