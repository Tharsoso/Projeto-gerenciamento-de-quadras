import 'dart:async';

import 'package:flutter/material.dart';

import '../formatos.dart';
import '../models/agendamento.dart';
import '../models/bloqueio.dart' show dataBr;
import '../models/quadra.dart';
import '../tema/ace_componentes.dart';
import '../tema/ace_cores.dart';
import 'agendamentos_repositorio.dart';
import 'quadras_repositorio.dart' show FalhaQuadra;

/// Ações extras de cada reserva (ex.: o cancelar da 5.5). [recarregar] atualiza a lista.
typedef AcoesAgendamento = Widget? Function(
    BuildContext context, Agendamento agendamento, VoidCallback recarregar);

/// Consulta de agendamentos realizados (atividade 5.4 · H11 · RF14): filtra por período,
/// quadra e telefone ou nome. Visual da tela "Reservas" do protótipo Ace Saibro.
class AgendamentosPage extends StatefulWidget {
  const AgendamentosPage({
    super.key,
    required this.repositorio,
    this.aoVoltar,
    this.aoSessaoExpirada,
    this.hoje,
    this.acoes,
  });

  final AgendamentosRepositorio repositorio;
  final VoidCallback? aoVoltar;
  final VoidCallback? aoSessaoExpirada;

  /// Data de hoje (para testes). Sem ela, usa o relógio do aparelho.
  final DateTime? hoje;

  /// Ponto de encaixe para o cancelamento (5.5).
  final AcoesAgendamento? acoes;

  @override
  State<AgendamentosPage> createState() => _AgendamentosPageState();
}

class _AgendamentosPageState extends State<AgendamentosPage> {
  late FiltroAgendamentos _filtro;
  final _busca = TextEditingController();
  Timer? _espera;
  List<Quadra> _quadras = const [];
  List<Agendamento>? _lista;
  FalhaQuadra? _falha;
  int _pedido = 0;

  DateTime get _hoje {
    final h = widget.hoje ?? DateTime.now();
    return DateTime(h.year, h.month, h.day);
  }

  bool get _periodoValido => !_filtro.inicio.isAfter(_filtro.fim);

  @override
  void initState() {
    super.initState();
    // Mesmo período inicial do protótipo: uma semana para trás, duas para a frente.
    _filtro = FiltroAgendamentos(
      inicio: _hoje.subtract(const Duration(days: 7)),
      fim: _hoje.add(const Duration(days: 14)),
    );
    _carregarQuadras();
    _carregar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busca.dispose();
    super.dispose();
  }

  void _falhou(FalhaQuadra f) {
    if (f.sessaoExpirada) widget.aoSessaoExpirada?.call();
  }

  Future<void> _carregarQuadras() async {
    try {
      final q = await widget.repositorio.quadras();
      if (mounted) setState(() => _quadras = q);
    } on FalhaQuadra catch (f) {
      _falhou(f);
    }
  }

  Future<void> _carregar() async {
    if (!_periodoValido) {
      setState(() => _lista = const []);
      return;
    }
    // Só a última busca vale: respostas lentas de filtros antigos são descartadas.
    final pedido = ++_pedido;
    setState(() {
      _falha = null;
      _lista = null;
    });
    try {
      final lista = await widget.repositorio.listar(_filtro);
      if (mounted && pedido == _pedido) setState(() => _lista = lista);
    } on FalhaQuadra catch (f) {
      if (!mounted || pedido != _pedido) return;
      setState(() => _falha = f);
      _falhou(f);
    }
  }

  void _mudar(FiltroAgendamentos novo) {
    setState(() => _filtro = novo);
    _carregar();
  }

  void _digitou(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), () => _mudar(_filtro.copiar(busca: texto)));
  }

  Future<void> _escolherData({required bool inicio}) async {
    final atual = inicio ? _filtro.inicio : _filtro.fim;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: _hoje.add(const Duration(days: 366)),
      helpText: inicio ? 'DE' : 'ATÉ',
    );
    if (escolhida == null || !mounted) return;
    _mudar(inicio ? _filtro.copiar(inicio: escolhida) : _filtro.copiar(fim: escolhida));
  }

  @override
  Widget build(BuildContext context) {
    final estreito = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: AceCores.superficie,
      appBar: aceBarraAdmin(context, 'Reservas', aoVoltar: widget.aoVoltar),
      body: RefreshIndicator(
        color: AceCores.verde,
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 60),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('RESERVAS', style: AceEstilo.titulo.copyWith(fontSize: estreito ? 48 : 64)),
                    const SizedBox(height: 10),
                    const Text(
                      'Filtre por período, quadra ou telefone para consultar os agendamentos.',
                      style: TextStyle(color: AceCores.apagado, fontSize: 15),
                    ),
                    const SizedBox(height: 22),
                    _filtros(),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AceCores.verde),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nome e telefone dos clientes são anonimizados após 12 meses (LGPD).',
                            style: TextStyle(color: AceCores.apagado, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._conteudo(estreito),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtros() {
    Widget campoData(String rotulo, DateTime valor, bool inicio, Key chave) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AceRotulo(rotulo),
            InkWell(
              key: chave,
              borderRadius: BorderRadius.circular(16),
              onTap: () => _escolherData(inicio: inicio),
              child: InputDecorator(
                decoration: AceEstilo.campo().copyWith(
                  suffixIcon: const Icon(Icons.calendar_today, size: 18, color: AceCores.verde),
                ),
                child: Text(dataBr(valor), style: const TextStyle(fontSize: 15)),
              ),
            ),
          ],
        );

    final campos = <Widget>[
      campoData('De', _filtro.inicio, true, const Key('agendamentos-de')),
      campoData('Até', _filtro.fim, false, const Key('agendamentos-ate')),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AceRotulo('Quadra'),
          DropdownButtonFormField<int?>(
            key: const Key('agendamentos-quadra'),
            initialValue: _filtro.quadraId,
            isExpanded: true,
            decoration: AceEstilo.campo(),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
              for (final q in _quadras)
                DropdownMenuItem<int?>(
                  value: q.id,
                  child: Text(q.ativa ? q.nome : '${q.nome} (inativa)',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) => _mudar(_filtro.copiar(quadraId: () => id)),
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AceRotulo('Telefone ou nome'),
          TextField(
            key: const Key('agendamentos-busca'),
            controller: _busca,
            decoration: AceEstilo.campo(hint: '(31) 9…').copyWith(
              prefixIcon: const Icon(Icons.search, color: AceCores.apagado),
            ),
            onChanged: _digitou,
            onSubmitted: (t) {
              _espera?.cancel();
              _mudar(_filtro.copiar(busca: t));
            },
          ),
        ],
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AceCores.linha),
        borderRadius: BorderRadius.circular(26),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final colunas = c.maxWidth > 820 ? 4 : c.maxWidth > 420 ? 2 : 1;
          final largura = (c.maxWidth - 12 * (colunas - 1)) / colunas;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [for (final campo in campos) SizedBox(width: largura, child: campo)],
          );
        },
      ),
    );
  }

  List<Widget> _conteudo(bool estreito) {
    if (!_periodoValido) {
      return const [
        AceAlerta(mensagem: 'Período inválido: a data inicial precisa ser anterior ou igual à final.'),
      ];
    }
    final falha = _falha;
    if (falha != null) {
      return [
        AceAlerta(mensagem: falha.mensagem),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _carregar,
            style: AceEstilo.botaoContorno,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar de novo'),
          ),
        ),
      ];
    }
    final lista = _lista;
    if (lista == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: AceCores.verde)),
        ),
      ];
    }
    if (lista.isEmpty) {
      return [
        Container(
          key: const Key('agendamentos-vazio'),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          decoration: BoxDecoration(
            border: Border.all(color: AceCores.linha, width: 1.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Text('NENHUMA RESERVA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: estreito ? 28 : 40,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      color: AceCores.tinta)),
              const SizedBox(height: 6),
              const Text('Ajuste os filtros para ver resultados.',
                  textAlign: TextAlign.center, style: TextStyle(color: AceCores.apagado)),
            ],
          ),
        ),
      ];
    }
    final confirmadas = lista.where((a) => !a.cancelada).length;
    final cortou = lista.length >= AgendamentosRepositorio.limite;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 4),
        child: Text(
          '${lista.length} reserva(s) no período · $confirmadas confirmada(s)'
          '${cortou ? ' · mostrando as ${AgendamentosRepositorio.limite} primeiras, reduza o período' : ''}',
          key: const Key('agendamentos-resumo'),
          style: const TextStyle(color: AceCores.apagado, fontSize: 13),
        ),
      ),
      for (final a in lista)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _LinhaAgendamento(
            agendamento: a,
            estreito: estreito,
            acao: widget.acoes?.call(context, a, _carregar),
          ),
        ),
    ];
  }
}

class _LinhaAgendamento extends StatelessWidget {
  const _LinhaAgendamento({required this.agendamento, required this.estreito, this.acao});

  final Agendamento agendamento;
  final bool estreito;
  final Widget? acao;

  static const _dias = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];

  @override
  Widget build(BuildContext context) {
    final a = agendamento;
    final hora = '${a.hora.toString().padLeft(2, '0')}:00';
    final cliente = a.anonimizada ? 'Anonimizado (LGPD)' : a.nome;
    final telefone = a.anonimizada || a.telefone == null
        ? '(••) •••••-••••'
        : mascararTelefone(a.telefone!);
    final motivo = a.motivoCancelamento;

    final dataHora = Container(
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: a.cancelada ? AceCores.cinzaClaro : AceCores.verdeClaro,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(_dias[a.data.weekday % 7],
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: AceCores.apagado)),
          Text(dataBr(a.data).substring(0, 5),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text(hora,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: a.cancelada ? AceCores.cinza : AceCores.verde)),
        ],
      ),
    );

    final status = a.cancelada
        ? const AceChip(texto: 'Cancelada', fundo: AceCores.vermelhoClaro, cor: AceCores.vermelho)
        : const AceChip(texto: 'Confirmada', fundo: AceCores.verdeClaro, cor: AceCores.verde);

    final detalhes = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(a.quadraNome.toUpperCase(), style: AceEstilo.nomeQuadra),
            status,
            Text(a.codigo,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: AceCores.apagado)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$cliente · $telefone',
          style: TextStyle(
            fontSize: 14,
            color: AceCores.tinta,
            fontStyle: a.anonimizada ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        if (a.cancelada && motivo != null && motivo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Motivo: $motivo',
                style: const TextStyle(fontSize: 13, color: AceCores.apagado)),
          ),
        if (estreito) ...[
          const SizedBox(height: 6),
          _valor(a),
        ],
      ],
    );

    return Opacity(
      opacity: a.cancelada ? .7 : 1,
      child: Container(
        key: Key('agendamento-${a.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AceCores.linha),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            dataHora,
            const SizedBox(width: 14),
            Expanded(child: detalhes),
            if (!estreito) ...[const SizedBox(width: 12), _valor(a)],
            if (acao != null) ...[const SizedBox(width: 12), acao!],
          ],
        ),
      ),
    );
  }

  Widget _valor(Agendamento a) => Text(
        formatarReal(a.valor),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: a.cancelada ? AceCores.cinza : AceCores.tinta,
          decoration: a.cancelada ? TextDecoration.lineThrough : null,
        ),
      );
}
