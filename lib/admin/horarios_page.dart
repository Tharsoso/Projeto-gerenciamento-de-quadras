import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/funcionamento.dart';
import '../models/quadra.dart';
import '../tema/ace_componentes.dart';
import '../tema/ace_cores.dart';
import 'horarios_repositorio.dart';
import 'quadras_repositorio.dart' show FalhaQuadra;

/// Horários de funcionamento por quadra (atividade 5.3 · H9 · RF13). Cada hora aberta vira
/// um bloco reservável de 1 hora. Visual da tela "Horários" do protótipo Ace Saibro.
class HorariosPage extends StatefulWidget {
  const HorariosPage({
    super.key,
    required this.repositorio,
    this.aoVoltar,
    this.aoSessaoExpirada,
  });

  final HorariosRepositorio repositorio;
  final VoidCallback? aoVoltar;
  final VoidCallback? aoSessaoExpirada;

  @override
  State<HorariosPage> createState() => _HorariosPageState();
}

/// Estado editável de um dia. Guarda as horas mesmo fechado, para reabrir com elas.
class _Dia {
  _Dia({required this.aberto, required this.abertura, required this.fechamento});

  bool aberto;
  int abertura;
  int fechamento;

  bool get erro => aberto && fechamento <= abertura;
}

class _HorariosPageState extends State<HorariosPage> {
  List<Quadra>? _quadras;
  Map<int, Semana> _salvo = {};
  final Map<int, Map<int, _Dia>> _edicao = {};
  FalhaQuadra? _falhaCarga;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _falhaCarga = null);
    try {
      final quadras = await widget.repositorio.quadras();
      final funcionamento = await widget.repositorio.funcionamento();
      if (!mounted) return;
      setState(() {
        _quadras = quadras;
        _salvo = {for (final q in quadras) q.id: funcionamento[q.id] ?? {}};
        _edicao
          ..clear()
          ..addAll({for (final q in quadras) q.id: _paraEdicao(_salvo[q.id]!)});
      });
    } on FalhaQuadra catch (f) {
      if (!mounted) return;
      setState(() => _falhaCarga = f);
      if (f.sessaoExpirada) widget.aoSessaoExpirada?.call();
    }
  }

  static Map<int, _Dia> _paraEdicao(Semana semana) => {
        for (var d = 0; d < 7; d++)
          d: _Dia(
            aberto: semana.containsKey(d),
            abertura: semana[d]?.abertura ?? 7,
            fechamento: semana[d]?.fechamento ?? 22,
          ),
      };

  Semana _semanaEditada(int quadraId) => {
        for (final e in _edicao[quadraId]!.entries)
          if (e.value.aberto) e.key: Intervalo(e.value.abertura, e.value.fechamento),
      };

  /// Quadras cuja semana na tela é diferente da gravada.
  Map<int, Semana> get _alteradas => {
        for (final id in _edicao.keys)
          if (!mapEquals(_semanaEditada(id), _salvo[id])) id: _semanaEditada(id),
      };

  bool get _temErro => _edicao.values.any((s) => s.values.any((d) => d.erro));

  Future<void> _salvar() async {
    final alteradas = _alteradas;
    if (alteradas.isEmpty || _temErro) return;
    setState(() => _salvando = true);
    try {
      // H9 alternativo: avisar o impacto antes de reduzir; as reservas continuam valendo.
      final reservas = await widget.repositorio.reservasFuturas(alteradas.keys.toSet());
      final fora = reservasForaDoHorario(reservas, alteradas);
      if (fora.isNotEmpty) {
        if (!mounted) return;
        setState(() => _salvando = false); // sem indicador girando atrás do aviso
        final seguir = await _confirmarImpacto(fora);
        if (seguir != true || !mounted) return;
        setState(() => _salvando = true);
      }
      for (final e in alteradas.entries) {
        await widget.repositorio.salvar(e.key, e.value);
        _salvo[e.key] = e.value;
      }
      if (!mounted) return;
      setState(() => _salvando = false);
      aceAviso(context, 'Horários de funcionamento salvos.');
    } on FalhaQuadra catch (f) {
      if (!mounted) return;
      setState(() => _salvando = false);
      aceAviso(context, f.mensagem, erro: true);
      if (f.sessaoExpirada) widget.aoSessaoExpirada?.call();
    }
  }

  Future<bool?> _confirmarImpacto(List<ReservaFutura> fora) {
    final nomes = {for (final q in _quadras!) q.id: q.nome};
    String dataCurta(DateTime d) =>
        '${siglasDias[diaSemanaDe(d)]} ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    final n = fora.length;
    return showDialog<bool>(
      context: context,
      barrierColor: const Color(0x8C0A180C),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('ATENÇÃO', style: AceEstilo.tituloDialogo),
                const SizedBox(height: 12),
                Text(
                  n == 1
                      ? 'Existe 1 reserva futura fora do novo horário.'
                      : 'Existem $n reservas futuras fora do novo horário.',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Elas continuam valendo e não serão canceladas. Novas reservas só poderão ser '
                  'feitas dentro do novo horário.',
                  style: TextStyle(color: AceCores.apagado),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final r in fora)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${nomes[r.quadraId] ?? 'Quadra'} · ${dataCurta(r.data)} · '
                            '${Intervalo.textoDe(r.hora)} · ${r.nomeCliente}',
                            key: const Key('impacto-reserva'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: AceEstilo.botaoContorno,
                      child: const Text('Voltar'),
                    ),
                    FilledButton(
                      key: const Key('impacto-confirmar'),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: AceEstilo.botaoPrimario,
                      child: const Text('Salvar mesmo assim'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quadras = _quadras;
    final alteradas = quadras == null ? const <int, Semana>{} : _alteradas;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: aceBarraAdmin(context, 'Horários', aoVoltar: widget.aoVoltar),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('HORÁRIOS DE FUNCIONAMENTO',
                      style: AceEstilo.titulo.copyWith(
                          fontSize: MediaQuery.sizeOf(context).width < 600 ? 40 : 64)),
                  const SizedBox(height: 10),
                  const Text(
                    'Defina abertura e fechamento (hora cheia) para cada dia da semana. Cada hora '
                    'aberta vira um horário reservável de 1 hora. Horas novas aparecem como '
                    '"sem preço" até você cadastrar os preços delas.',
                    style: TextStyle(color: AceCores.apagado, fontSize: 15),
                  ),
                  const SizedBox(height: 22),
                  ..._conteudo(quadras),
                  if (quadras != null && quadras.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 64,
                      child: FilledButton(
                        key: const Key('horarios-salvar'),
                        onPressed:
                            (_salvando || alteradas.isEmpty || _temErro) ? null : _salvar,
                        style: AceEstilo.botaoPrimario,
                        child: _salvando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                              )
                            : Text(
                                alteradas.isEmpty
                                    ? 'NADA PARA SALVAR'
                                    : alteradas.length == 1
                                        ? 'SALVAR (1 QUADRA ALTERADA)'
                                        : 'SALVAR (${alteradas.length} QUADRAS ALTERADAS)',
                                style: AceEstilo.fab,
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _conteudo(List<Quadra>? quadras) {
    final falha = _falhaCarga;
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
    if (quadras == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: AceCores.verde)),
        ),
      ];
    }
    if (quadras.isEmpty) {
      return const [
        Text('Nenhuma quadra cadastrada. Cadastre uma em "Quadras" primeiro.',
            style: TextStyle(color: AceCores.apagado)),
      ];
    }
    return [
      for (final q in quadras)
        _CartaoQuadra(
          quadra: q,
          dias: _edicao[q.id]!,
          semHorarioGravado: _salvo[q.id]!.isEmpty,
          habilitado: !_salvando,
          aoMudar: () => setState(() {}),
        ),
    ];
  }
}

class _CartaoQuadra extends StatelessWidget {
  const _CartaoQuadra({
    required this.quadra,
    required this.dias,
    required this.semHorarioGravado,
    required this.habilitado,
    required this.aoMudar,
  });

  final Quadra quadra;
  final Map<int, _Dia> dias;
  final bool semHorarioGravado;
  final bool habilitado;
  final VoidCallback aoMudar;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: quadra.ativa ? 1 : .7,
      child: Container(
        key: Key('horarios-quadra-${quadra.id}'),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AceCores.linha),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(quadra.nome.toUpperCase(), style: AceEstilo.nomeQuadra.copyWith(fontSize: 30)),
                AceChip(
                    texto: quadra.tipoPiso.rotulo,
                    fundo: quadra.tipoPiso.fundo,
                    cor: quadra.tipoPiso.cor),
                if (!quadra.ativa)
                  const AceChip(texto: 'Inativa', fundo: AceCores.cinzaClaro, cor: AceCores.cinza),
              ],
            ),
            if (semHorarioGravado)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Sem horário cadastrado: esta quadra não aparece na consulta pública.',
                  style: TextStyle(color: AceCores.vermelho, fontSize: 13.5),
                ),
              ),
            const SizedBox(height: 14),
            for (final d in ordemDias)
              _LinhaDia(
                quadraId: quadra.id,
                diaSemana: d,
                dia: dias[d]!,
                habilitado: habilitado,
                aoMudar: aoMudar,
              ),
          ],
        ),
      ),
    );
  }
}

class _LinhaDia extends StatelessWidget {
  const _LinhaDia({
    required this.quadraId,
    required this.diaSemana,
    required this.dia,
    required this.habilitado,
    required this.aoMudar,
  });

  final int quadraId;
  final int diaSemana;
  final _Dia dia;
  final bool habilitado;
  final VoidCallback aoMudar;

  @override
  Widget build(BuildContext context) {
    final chave = 'dia-$quadraId-$diaSemana';
    final nome = Text(nomesDias[diaSemana]!.toUpperCase(),
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: .5));
    final interruptor = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          key: Key('$chave-aberto'),
          value: dia.aberto,
          activeTrackColor: AceCores.verde,
          activeThumbColor: AceCores.bola,
          onChanged: habilitado
              ? (v) {
                  dia.aberto = v;
                  aoMudar();
                }
              : null,
        ),
        const SizedBox(width: 8),
        Text(dia.aberto ? 'Aberto' : 'Fechado',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
    Widget horas({required bool expandir}) {
      if (!dia.aberto) {
        return const Text('Fechado o dia todo',
            style: TextStyle(
                color: AceCores.apagado, fontSize: 13.5, fontStyle: FontStyle.italic));
      }
      Widget caixa(Widget w) => expandir ? Expanded(child: w) : w;
      return Row(
        mainAxisSize: expandir ? MainAxisSize.max : MainAxisSize.min,
        children: [
          caixa(_SeletorHora(
            key: Key('$chave-abre'),
            valor: dia.abertura,
            de: 0,
            ate: 23,
            rotulo: 'Abertura',
            expandir: expandir,
            habilitado: habilitado,
            aoMudar: (h) {
              dia.abertura = h;
              aoMudar();
            },
          )),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('às', style: TextStyle(color: AceCores.apagado)),
          ),
          caixa(_SeletorHora(
            key: Key('$chave-fecha'),
            valor: dia.fechamento,
            de: 1,
            ate: 24,
            rotulo: 'Fechamento',
            erro: dia.erro,
            expandir: expandir,
            habilitado: habilitado,
            aoMudar: (h) {
              dia.fechamento = h;
              aoMudar();
            },
          )),
        ],
      );
    }

    final erro = dia.erro
        ? const Padding(
            padding: EdgeInsets.only(left: 4, top: 2),
            child: Text('O fechamento precisa ser depois da abertura.',
                style: TextStyle(color: AceCores.vermelho, fontSize: 12.5)),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Expanded(child: nome), interruptor]),
              const SizedBox(height: 4),
              horas(expandir: true),
              ?erro,
              const Divider(height: 18, color: AceCores.linha),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(width: 130, child: nome),
                SizedBox(width: 170, child: interruptor),
                Flexible(child: horas(expandir: false)),
              ],
            ),
            ?erro,
          ],
        );
      }),
    );
  }
}

class _SeletorHora extends StatelessWidget {
  const _SeletorHora({
    super.key,
    required this.valor,
    required this.de,
    required this.ate,
    required this.rotulo,
    required this.habilitado,
    required this.aoMudar,
    this.erro = false,
    this.expandir = false,
  });

  final int valor;
  final int de;
  final int ate;
  final String rotulo;
  final bool habilitado;
  final bool erro;
  final bool expandir;
  final ValueChanged<int> aoMudar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: rotulo,
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: erro ? AceCores.vermelho : AceCores.linha, width: 1.5),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: valor,
            isExpanded: expandir,
            borderRadius: BorderRadius.circular(14),
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 15, color: AceCores.tinta),
            items: [
              for (var h = de; h <= ate; h++)
                DropdownMenuItem(value: h, child: Text(Intervalo.textoDe(h))),
            ],
            onChanged: habilitado ? (h) => aoMudar(h ?? valor) : null,
          ),
        ),
      ),
    );
  }
}
