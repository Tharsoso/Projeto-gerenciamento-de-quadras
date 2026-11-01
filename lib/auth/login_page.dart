import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_theme.dart';
import 'autenticacao.dart';

/// Tela de login do proprietário (H7). Quem redireciona para `/admin` depois de
/// entrar é o roteador, ao ser notificado pela [Autenticacao]. Visual do protótipo
/// Ace Saibro (docs/referencia/ace-saibro-reservas.html).
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
  bool _mostrarSenha = false;
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
      backgroundColor: AppColors.green,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: Padding(
                padding: const EdgeInsets.all(80),
                child: Text(
                  'ACE',
                  style: AppTheme.display(size: 400, color: Colors.transparent, letterSpacing: 4)
                      .copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 3
                      ..color = Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(26, 50, 26, 26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        offset: const Offset(0, 30),
                        blurRadius: 70,
                      ),
                    ],
                  ),
                  child: Form(
                    key: _form,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Transform.rotate(
                              angle: -0.1,
                              child: Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: AppColors.ball,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      offset: const Offset(0, 12),
                                      blurRadius: 26,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppColors.greenDark,
                                  size: 34,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Área do proprietário',
                            textAlign: TextAlign.center,
                            style: AppTheme.display(
                              size: 36,
                              color: AppColors.ink,
                              letterSpacing: 1.5,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (aviso != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.redTint,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                aviso,
                                key: const Key('login-aviso'),
                                style: const TextStyle(color: Color(0xFF8E1B1B)),
                                textAlign: TextAlign.center,
                              ),
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
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              suffixIcon: IconButton(
                                tooltip: _mostrarSenha ? 'Ocultar senha' : 'Mostrar senha',
                                icon: Icon(
                                  _mostrarSenha ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.green,
                                ),
                                onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                              ),
                            ),
                            obscureText: !_mostrarSenha,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _entrar(),
                            validator: _obrigatorio,
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            key: const Key('login-entrar'),
                            onPressed: _enviando ? null : _entrar,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              textStyle: AppTheme.display(
                                size: 24,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                            child: _enviando
                                ? const SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(strokeWidth: 3),
                                  )
                                : const Text('ENTRAR'),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: () => context.go('/'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.green),
                              child: const Text('← Voltar à área pública'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
