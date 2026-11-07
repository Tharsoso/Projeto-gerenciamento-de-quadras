import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../formatos.dart';
import '../fuso.dart';
import '../models/agendamento.dart';
import '../models/bloqueio.dart' show dataBr;
import '../models/funcionamento.dart' show nomesDias, diaSemanaDe;
import '../tema/ace_componentes.dart';
import '../tema/ace_cores.dart';
import 'agendamentos_page.dart' show AcoesAgendamento;
import 'quadras_repositorio.dart' show FalhaQuadra;

/// Cancelamento de reservas pelo proprietário (atividade 5.5 · H3 · RF15–RF16 · RNF06).
/// Tudo acontece na função `cancelar_reserva` do banco, numa transação: a reserva vira
/// `cancelada` (exclusão lógica), o log vai para `log_cancelamentos` (quem, quando, motivo)
/// e o gatilho libera o horário em `ocupacoes`, que a consulta pública vê em tempo real.
abstract class CancelamentoRepositorio {
  Future<void> cancelar(int reservaId, {String? motivo});
}

class SupabaseCancelamentoRepositorio implements CancelamentoRepositorio {
  /// Sem cliente, usa o `Supabase.instance` só na hora de cancelar: a rota de reservas
  /// monta este repositório mesmo nos testes que não inicializam o Supabase.
  SupabaseCancelamentoRepositorio([this._cliente]);

  final SupabaseClient? _cliente;

  SupabaseClient get _client => _cliente ?? Supabase.instance.client;

  @override
  Future<void> cancelar(int reservaId, {String? motivo}) async {
    final m = motivo?.trim();
    try {
      await _client.rpc('cancelar_reserva', params: {
        'p_reserva_id': reservaId,
        'p_motivo': (m == null || m.isEmpty) ? null : m,
      });
    } on PostgrestException catch (e) {
      throw traduzirErroCancelamento(e);
    } on AuthException {
      throw const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
    } on Exception {
      throw const FalhaQuadra('Não foi possível conectar. Verifique a internet e tente novamente.');
    }
  }
}

/// `hint` do banco: `RESERVA_NAO_ENCONTRADA`, `RESERVA_JA_CANCELADA`, `RESERVA_PASSADA`,
/// `NAO_AUTORIZADO` (mensagens já em pt-BR).
FalhaQuadra traduzirErroCancelamento(PostgrestException e) {
  final hint = e.hint;
  if (hint == 'NAO_AUTORIZADO' || e.code == '42501' || e.code == 'PGRST301') {
    return const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
  }
  if (hint != null && hint.isNotEmpty) return FalhaQuadra(e.message, codigo: hint);
  return const FalhaQuadra('Não foi possível cancelar a reserva. Tente novamente.');
}

/// Mesma regra do banco: só reserva confirmada que ainda não terminou (futura ou em
/// andamento). Reserva que já passou não mostra o botão (H3 alternativo 1).
bool podeCancelar(Agendamento a, DateTime agora) {
  if (a.cancelada) return false;
  final fim = DateTime(a.data.year, a.data.month, a.data.day, a.hora + 1);
  return fim.isAfter(agora);
}

/// Reserva que já começou e ainda não terminou.
bool emAndamento(Agendamento a, DateTime agora) {
  final inicio = DateTime(a.data.year, a.data.month, a.data.day, a.hora);
  return !agora.isBefore(inicio) && podeCancelar(a, agora);
}

/// Encaixe no `acoes` da `AgendamentosPage` (5.4): o botão só aparece onde cancelar é
/// permitido. [agora] serve para os testes; sem ele, usa o horário de Brasília.
AcoesAgendamento acoesCancelamento({
  required CancelamentoRepositorio repositorio,
  VoidCallback? aoSessaoExpirada,
  DateTime Function()? agora,
}) {
  return (context, agendamento, recarregar) {
    final relogio = agora ?? agoraBrasilia;
    if (!podeCancelar(agendamento, relogio())) return null;
    return BotaoCancelarReserva(
      agendamento: agendamento,
      repositorio: repositorio,
      agora: relogio,
      aoCancelar: recarregar,
      aoSessaoExpirada: aoSessaoExpirada,
    );
  };
}

class BotaoCancelarReserva extends StatelessWidget {
  const BotaoCancelarReserva({
    super.key,
    required this.agendamento,
    required this.repositorio,
    required this.agora,
    required this.aoCancelar,
    this.aoSessaoExpirada,
  });

  final Agendamento agendamento;
  final CancelamentoRepositorio repositorio;
  final DateTime Function() agora;
  final VoidCallback aoCancelar;
  final VoidCallback? aoSessaoExpirada;

  Future<void> _abrir(BuildContext context) async {
    // true = cancelou; FalhaQuadra = erro que encerra o diálogo; null = desistiu.
    final resultado = await showDialog<Object>(
      context: context,
      barrierColor: const Color(0x8C0A180C),
      builder: (_) => _DialogoCancelar(
        agendamento: agendamento,
        repositorio: repositorio,
        emAndamento: emAndamento(agendamento, agora()),
      ),
    );
    if (!context.mounted) return;
    if (resultado == true) {
      aceAviso(context, 'Reserva cancelada. O horário voltou a ficar livre para os clientes.');
      aoCancelar();
    } else if (resultado is FalhaQuadra) {
      // Erro que o diálogo não resolve (sessão expirada, reserva já cancelada ou passada):
      // avisa e recarrega a lista para mostrar o estado real.
      aceAviso(context, resultado.mensagem, erro: true);
      if (resultado.sessaoExpirada) {
        aoSessaoExpirada?.call();
      } else {
        aoCancelar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chave = Key('cancelar-${agendamento.id}');
    if (MediaQuery.sizeOf(context).width < 600) {
      return IconButton(
        key: chave,
        tooltip: 'Cancelar reserva',
        onPressed: () => _abrir(context),
        icon: const Icon(Icons.event_busy, color: AceCores.vermelho),
      );
    }
    return OutlinedButton.icon(
      key: chave,
      onPressed: () => _abrir(context),
      style: AceEstilo.botaoContorno.copyWith(
        foregroundColor: const WidgetStatePropertyAll(AceCores.vermelho),
        minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
      ),
      icon: const Icon(Icons.event_busy, size: 18),
      label: const Text('Cancelar'),
    );
  }
}

/// Erros que encerram o diálogo; os demais (ex.: sem internet) ficam nele para tentar de novo.
const _encerram = {'RESERVA_JA_CANCELADA', 'RESERVA_PASSADA', 'RESERVA_NAO_ENCONTRADA'};

class _DialogoCancelar extends StatefulWidget {
  const _DialogoCancelar({
    required this.agendamento,
    required this.repositorio,
    required this.emAndamento,
  });

  final Agendamento agendamento;
  final CancelamentoRepositorio repositorio;
  final bool emAndamento;

  @override
  State<_DialogoCancelar> createState() => _DialogoCancelarState();
}

class _DialogoCancelarState extends State<_DialogoCancelar> {
  final _motivo = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await widget.repositorio.cancelar(widget.agendamento.id, motivo: _motivo.text);
      if (mounted) Navigator.of(context).pop(true);
    } on FalhaQuadra catch (f) {
      if (!mounted) return;
      if (f.sessaoExpirada || _encerram.contains(f.codigo)) {
        Navigator.of(context).pop(f);
        return;
      }
      setState(() {
        _salvando = false;
        _erro = f.mensagem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.agendamento;
    final cliente = a.anonimizada ? 'Anonimizado (LGPD)' : a.nome;
    final hora = '${a.hora.toString().padLeft(2, '0')}:00';
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('CANCELAR RESERVA', style: AceEstilo.tituloDialogo),
              const SizedBox(height: 14),
              if (_erro != null) AceAlerta(mensagem: _erro!),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AceCores.superficie, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${a.quadraNome.toUpperCase()} · ${a.codigo}',
                        style: AceEstilo.nomeQuadra.copyWith(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('${nomesDias[diaSemanaDe(a.data)]}, ${dataBr(a.data)} às $hora',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('$cliente · ${formatarReal(a.valor)}',
                        style: const TextStyle(color: AceCores.apagado)),
                  ],
                ),
              ),
              if (widget.emAndamento)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Esta reserva está em andamento. Cancelar libera o restante do horário.',
                    key: Key('cancelar-em-andamento'),
                    style: TextStyle(color: AceCores.vermelho, fontSize: 13.5),
                  ),
                ),
              const SizedBox(height: 16),
              const AceRotulo('Motivo (opcional)'),
              TextField(
                key: const Key('cancelar-motivo'),
                controller: _motivo,
                enabled: !_salvando,
                maxLength: 120,
                maxLines: 2,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    AceEstilo.campo(hint: 'Ex.: Cliente avisou que não poderá comparecer'),
              ),
              const SizedBox(height: 6),
              const Text(
                'O horário volta a ficar livre para novas reservas. O cancelamento fica '
                'registrado com data, hora e quem cancelou.',
                style: TextStyle(color: AceCores.apagado, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    key: const Key('cancelar-manter'),
                    onPressed: _salvando ? null : () => Navigator.of(context).pop(),
                    style: AceEstilo.botaoContorno,
                    child: const Text('Manter reserva'),
                  ),
                  FilledButton(
                    key: const Key('cancelar-confirmar'),
                    onPressed: _salvando ? null : _confirmar,
                    style: AceEstilo.botaoPrimario.copyWith(
                        backgroundColor: const WidgetStatePropertyAll(AceCores.vermelho)),
                    child: _salvando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Cancelar reserva'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
