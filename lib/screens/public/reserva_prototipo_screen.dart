import 'package:flutter/material.dart';

class ReservaPrototipoScreen extends StatefulWidget {
  const ReservaPrototipoScreen({super.key});

  @override
  State<ReservaPrototipoScreen> createState() => _ReservaPrototipoScreenState();
}

class _ReservaPrototipoScreenState extends State<ReservaPrototipoScreen> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _telefone = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? const {};
    final quadra = args['quadra'] as String? ?? 'Quadra';
    final hora = args['hora'] as String? ?? '--:--';
    final data = args['data'] as DateTime? ?? DateTime.now();
    final valor = args['valor'] as double?;

    return Scaffold(
      appBar: AppBar(title: const Text('Reservar horário')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(quadra, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('${_fmtData(data)}  ·  $hora  ·  ${valor != null ? "R\$ ${valor.toStringAsFixed(2)}" : "—"}'),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nome,
                        decoration: const InputDecoration(labelText: 'Nome completo'),
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().length < 3) ? 'Informe o nome completo.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _telefone,
                        decoration: const InputDecoration(
                          labelText: 'Telefone (DDD + 9XXXXXXXX)',
                          hintText: '31999990000',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          final s = (v ?? '').replaceAll(RegExp(r'\D'), '');
                          if (!RegExp(r'^[1-9]{2}9[0-9]{8}$').hasMatch(s)) {
                            return 'Formato: DDD + 9 e mais 8 dígitos.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () {
                          if (_form.currentState?.validate() ?? false) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Protótipo: envio real na atividade 4.2.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Confirmar reserva'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Voltar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fmtData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
