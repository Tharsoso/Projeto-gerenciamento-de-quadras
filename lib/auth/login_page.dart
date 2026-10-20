import 'package:flutter/material.dart';

import 'autenticacao.dart';

/// Tela de login do proprietário (H7). Quem redireciona para `/admin` depois de
/// entrar é o roteador, ao ser notificado pela [Autenticacao].
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth, this.sessaoExpirada = false});

  final Autenticacao auth;
  final bool sessaoExpirada;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await widget.auth.entrar(email: _email.text, senha: _senha.text);
    } on FalhaLogin catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String? _obrigatorio(String? valor) =>
      (valor == null || valor.trim().isEmpty) ? 'Campo obrigatório' : null;

  @override
  Widget build(BuildContext context) {
    final aviso = _erro ??
        (widget.sessaoExpirada ? 'Sessão encerrada por inatividade. Entre novamente.' : null);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Área do proprietário',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (aviso != null) ...[
                      Text(
                        aviso,
                        key: const Key('login-aviso'),
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      key: const Key('login-email'),
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: _obrigatorio,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('login-senha'),
                      controller: _senha,
                      decoration: const InputDecoration(labelText: 'Senha'),
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _entrar(),
                      validator: _obrigatorio,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('login-entrar'),
                      onPressed: _enviando ? null : _entrar,
                      child: _enviando
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Entrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
