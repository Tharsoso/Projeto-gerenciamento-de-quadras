import 'package:flutter/material.dart';
import '../../app_theme.dart';

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
                  style: AppTheme.display(
                    size: 400,
                    color: Colors.transparent,
                    letterSpacing: 4,
                  ).copyWith(
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
                                    color:
                                        Colors.black.withValues(alpha: 0.45),
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
                        Center(
                          child: Text(
                            'ENTRAR',
                            style: AppTheme.display(
                              size: 50,
                              color: AppColors.ink,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(labelText: 'E-mail'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Informe um e-mail válido.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _senha,
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _mostrarSenha
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppColors.green,
                              ),
                              onPressed: () => setState(
                                  () => _mostrarSenha = !_mostrarSenha),
                            ),
                          ),
                          obscureText: !_mostrarSenha,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Informe a senha.'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () {
                            if (_form.currentState?.validate() ?? false) {
                              Navigator.of(context)
                                  .pushReplacementNamed('/admin');
                            }
                          },
                          style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 20),
                            textStyle: AppTheme.display(
                              size: 24,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          child: const Text('ENTRAR'),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.green,
                            ),
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
        ],
      ),
    );
  }
}
