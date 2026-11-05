import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app_theme.dart';
import '../../formatos.dart';
import '../../publico/reservas_repositorio.dart';
import '../widgets/ticket_reserva.dart';

/// Reserva sem login (4.2 · H1): nome e telefone. Nome e telefone são validados aqui para
/// responder na hora, mas quem decide é o banco (`criar_reserva`), inclusive o limite
/// de 2 reservas por telefone por dia (4.3).
class ReservaScreen extends StatefulWidget {
  const ReservaScreen({super.key, required this.horario, required this.repositorio});

  final HorarioEscolhido horario;
  final ReservasRepositorio repositorio;

  @override
  State<ReservaScreen> createState() => _ReservaScreenState();
}

class _ReservaScreenState extends State<ReservaScreen> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _tel = TextEditingController();
  bool _enviando = false;
  FalhaReserva? _falha;

  void _voltar() => context.canPop() ? context.pop() : context.go('/');

  @override
  void dispose() {
    _nome.dispose();
    _tel.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _falha = null;
    });
    try {
      final reserva = await widget.repositorio.criar(
        horario: widget.horario,
        nome: _nome.text.trim().replaceAll(RegExp(r'\s+'), ' '),
        telefone: _tel.text.replaceAll(RegExp(r'\D'), ''),
      );
      if (mounted) context.go('/sucesso', extra: reserva);
    } on FalhaReserva catch (f) {
      if (mounted) setState(() => _falha = f);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.horario;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: _voltar,
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
                TicketReserva(quadra: h.quadra, hora: h.hora, data: h.data, valor: h.valor),
                const SizedBox(height: 24),
                if (_falha != null) ...[
                  _Alerta(falha: _falha!),
                  const SizedBox(height: 18),
                ],
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Rotulo('NOME COMPLETO'),
                      TextFormField(
                        key: const Key('reserva-nome'),
                        controller: _nome,
                        decoration: const InputDecoration(
                          hintText: 'Ex.: Maria da Silva',
                          counterText: '',
                        ),
                        maxLength: 80,
                        autofillHints: const [AutofillHints.name],
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().length < 3)
                            ? 'Digite seu nome completo (mínimo de 3 letras).'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      const _Rotulo('TELEFONE (WHATSAPP)'),
                      TextFormField(
                        key: const Key('reserva-telefone'),
                        controller: _tel,
                        decoration: const InputDecoration(
                          hintText: '(31) 99999-0000',
                          helperText: 'DDD + 9 + 8 dígitos. Ex.: 31999990000',
                        ),
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumberNational],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _MascaraTelefone(),
                        ],
                        onFieldSubmitted: (_) => _confirmar(),
                        validator: (v) {
                          final s = (v ?? '').replaceAll(RegExp(r'\D'), '');
                          return RegExp(r'^[1-9]{2}9[0-9]{8}$').hasMatch(s)
                              ? null
                              : 'Telefone inválido. Use DDD + 9 + 8 dígitos, ex.: (31) 99999-0000.';
                        },
                      ),
                      const SizedBox(height: 18),
                      const _Regra('Reserva de 1 hora cheia, sem login.'),
                      const _Regra('Até 2 reservas por dia com o mesmo telefone.'),
                      const _Regra(avisoLgpdReserva, chave: Key('reserva-aviso-lgpd')),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 64,
                        child: FilledButton.icon(
                          key: const Key('reserva-confirmar'),
                          onPressed: _enviando ? null : _confirmar,
                          icon: _enviando
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _enviando ? 'RESERVANDO…' : 'CONFIRMAR RESERVA',
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
                        onPressed: _enviando ? null : _voltar,
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

/// Erro do banco. Limite diário em laranja (é regra, não falha), o resto em vermelho.
class _Alerta extends StatelessWidget {
  const _Alerta({required this.falha});

  final FalhaReserva falha;

  @override
  Widget build(BuildContext context) {
    final (titulo, texto) = switch (falha.codigo) {
      'LIMITE_DIARIO' => (
          'Limite de reservas atingido.',
          '${falha.mensagem} Escolha outra data ou use outro número.',
        ),
      'HORARIO_OCUPADO' => (
          'Ops! Esse horário acabou de ser reservado.',
          'Outra pessoa foi mais rápida. Volte e escolha outro horário livre.',
        ),
      _ => ('Não foi possível reservar.', falha.mensagem),
    };
    final limite = falha.codigo == 'LIMITE_DIARIO';
    final cor = limite ? const Color(0xFF8A3B00) : const Color(0xFF8E1B1B);
    return Container(
      key: const Key('reserva-alerta'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: limite ? AppColors.orangeTint : AppColors.redTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_rounded, color: cor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: TextStyle(color: cor, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(texto, style: TextStyle(color: cor, fontSize: 14.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7, left: 4),
        child: Text(
          texto,
          style: AppTheme.mono(
            size: 12,
            color: AppColors.muted,
            letterSpacing: 1.4,
            weight: FontWeight.w700,
          ),
        ),
      );
}

/// Aviso de finalidade e prazo dos dados pessoais (RNF04, regra L1 da atividade 5.9).
const avisoLgpdReserva = 'Usamos seu nome e telefone só para identificar a reserva e falar '
    'com você sobre ela. Eles são apagados (anonimizados) 12 meses depois da data da '
    'reserva (LGPD).';

class _Regra extends StatelessWidget {
  const _Regra(this.texto, {this.chave});

  final String texto;
  final Key? chave;

  @override
  Widget build(BuildContext context) => Padding(
        key: chave,
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.ballDark, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(texto, style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
            ),
          ],
        ),
      );
}

class _MascaraTelefone extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final texto = mascararTelefone(newValue.text.replaceAll(RegExp(r'\D'), ''));
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
