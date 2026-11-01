import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../app_theme.dart';

class ReservaPrototipoScreen extends StatefulWidget {
  /// [args]: quadra, data, hora e valor escolhidos na consulta (vêm em `extra` da rota).
  const ReservaPrototipoScreen({super.key, this.args = const {}});

  final Map<String, dynamic> args;

  @override
  State<ReservaPrototipoScreen> createState() => _ReservaPrototipoScreenState();
}

class _ReservaPrototipoScreenState extends State<ReservaPrototipoScreen> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _tel = TextEditingController();

  void _voltar(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/');

  @override
  void dispose() {
    _nome.dispose();
    _tel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final quadra = args['quadra'] as String? ?? 'Quadra';
    final hora = args['hora'] as String? ?? '--:--';
    final data = args['data'] as DateTime? ?? DateTime.now();
    final valor = args['valor'] as double?;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _voltar(context),
        ),
        title: Text(
          'RESERVAR HORÁRIO',
          style: AppTheme.display(
            size: 20,
            color: AppColors.ink,
            letterSpacing: 1.5,
            height: 1,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Ticket(
                  quadra: quadra,
                  hora: hora,
                  data: data,
                  valor: valor,
                ),
                const SizedBox(height: 24),
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Label('NOME COMPLETO'),
                      TextFormField(
                        controller: _nome,
                        decoration: const InputDecoration(
                            hintText: 'Ex.: Maria da Silva'),
                        validator: (v) =>
                            (v == null || v.trim().length < 3)
                                ? 'Informe o nome completo.'
                                : null,
                      ),
                      const SizedBox(height: 18),
                      _Label('TELEFONE (WHATSAPP)'),
                      TextFormField(
                        controller: _tel,
                        decoration: const InputDecoration(
                          hintText: '(31) 99999-0000',
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _PhoneFormatter(),
                        ],
                        validator: (v) {
                          final s = (v ?? '').replaceAll(RegExp(r'\D'), '');
                          if (!RegExp(r'^[1-9]{2}9[0-9]{8}$').hasMatch(s)) {
                            return 'DDD + 9 + 8 dígitos. Ex.: (31) 99999-0000';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'DDD + 9 + 8 dígitos. Ex.: 31999990000',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.muted),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 64,
                        child: FilledButton.icon(
                          onPressed: () {
                            if (_form.currentState?.validate() ?? false) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.ink,
                                  content: Text(
                                    'Protótipo: envio real na atividade 4.2.',
                                    style: AppTheme.mono(
                                      size: 13,
                                      color: Colors.white,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(
                            'CONFIRMAR RESERVA',
                            style: AppTheme.display(
                              size: 22,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => _voltar(context),
                        child: const Text('Voltar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7, left: 4),
        child: Text(
          text,
          style: AppTheme.mono(
            size: 12,
            color: AppColors.muted,
            letterSpacing: 1.4,
            weight: FontWeight.w700,
          ),
        ),
      );
}

class _Ticket extends StatelessWidget {
  final String quadra;
  final String hora;
  final DateTime data;
  final double? valor;
  const _Ticket({
    required this.quadra,
    required this.hora,
    required this.data,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    const dows = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];
    final dSemana = dows[data.weekday % 7];
    final dBr =
        '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.greenDark,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.greenDark.withValues(alpha: 0.3),
            offset: const Offset(0, 18),
            blurRadius: 40,
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 20, 22),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Colors.white.withValues(alpha: 0.28),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HORA',
                    style: AppTheme.mono(
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.65),
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hora,
                    style: AppTheme.display(
                      size: 70,
                      color: AppColors.ball,
                      height: 0.82,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      quadra.toUpperCase(),
                      style: AppTheme.display(
                        size: 32,
                        color: Colors.white,
                        letterSpacing: 1,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _row('DATA', '$dSemana · $dBr'),
                    const SizedBox(height: 8),
                    _row('DURAÇÃO', '1 hora'),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'VALOR',
                          style: AppTheme.mono(
                            size: 10,
                            color: Colors.white.withValues(alpha: 0.65),
                            letterSpacing: 2,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          valor != null
                              ? 'R\$ ${valor!.toStringAsFixed(2)}'
                              : '—',
                          style: AppTheme.display(
                            size: 32,
                            color: AppColors.ball,
                            letterSpacing: 0.5,
                            height: 0.9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              k,
              style: AppTheme.mono(
                size: 10,
                color: Colors.white.withValues(alpha: 0.65),
                letterSpacing: 2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
}

class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    final s = d.substring(0, d.length > 11 ? 11 : d.length);
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i == 0) b.write('(');
      if (i == 2) b.write(') ');
      if (i == 7) b.write('-');
      b.write(s[i]);
    }
    return TextEditingValue(
      text: b.toString(),
      selection: TextSelection.collapsed(offset: b.length),
    );
  }
}
