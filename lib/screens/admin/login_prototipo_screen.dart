import 'package:flutter/material.dart';

class LoginPrototipoScreen extends StatefulWidget {
  const LoginPrototipoScreen({super.key});

  @override
  State<LoginPrototipoScreen> createState() => _LoginPrototipoScreenState();
}

class _LoginPrototipoScreenState extends State<LoginPrototipoScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _mostrarSenha = false;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Área do proprietário')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lock_outline, size: 48),
                      const SizedBox(height: 12),
                      const Text('Entrar',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'E-mail'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            (v == null || !v.contains('@')) ? 'Informe um e-mail válido.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _senha,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          suffixIcon: IconButton(
                            icon: Icon(_mostrarSenha ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                          ),
                        ),
                        obscureText: !_mostrarSenha,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Informe a senha.' : null,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () {
                          if (_form.currentState?.validate() ?? false) {
                            Navigator.of(context).pushReplacementNamed('/admin');
                          }
                        },
                        child: const Text('Entrar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Voltar à área pública'),
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
}
