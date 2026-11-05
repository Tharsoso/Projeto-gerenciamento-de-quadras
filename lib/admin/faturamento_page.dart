import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../formatos.dart';
import '../fuso.dart';
import '../models/bloqueio.dart' show dataBr;
import '../tema/ace_componentes.dart';
import '../tema/ace_cores.dart';
import 'faturamento_repositorio.dart';
import 'quadras_repositorio.dart' show FalhaQuadra;

/// Relatório de locações por período (atividade 5.8 · H12 · RF22-RF23): locações
/// confirmadas, faturamento e canceladas, mais o faturamento dia a dia. Visual da tela
/// "Faturamento" do protótipo Ace Saibro.
class FaturamentoPage extends StatefulWidget {
  const FaturamentoPage({
    super.key,
    required this.repositorio,
    this.aoVoltar,
    this.aoSessaoExpirada,
    this.hoje,
  });

  final FaturamentoRepositorio repositorio;
  final VoidCallback? aoVoltar;
  final VoidCallback? aoSessaoExpirada;

  /// Data de hoje (para testes). Sem ela, usa o relógio do aparelho.
  final DateTime? hoje;

  /// O gráfico mostra no máximo estes dias (os últimos do período), como no protótipo.
  static const diasNoGrafico = 62;

  @override
  State<FaturamentoPage> createState() => _FaturamentoPageState();
}

class _FaturamentoPageState extends State<FaturamentoPage> {
  late DateTime _inicio;
  late DateTime _fim;
  final _telefone = TextEditingController();
  String? _erroTelefone;
  String? _telefoneAplicado;

  ResumoFaturamento? _resumo;
  Map<DateTime, double> _porDia = const {};
  bool _carregando = true;
  FalhaQuadra? _falha;
  int _pedido = 0;
  bool _tabela = false;

  DateTime get _hoje {
    final h = widget.hoje ?? agoraBrasilia();
    return DateTime(h.year, h.month, h.day);
  }

  bool get _periodoValido => !_inicio.isAfter(_fim);

  @override
  void initState() {
    super.initState();
    // Mesmo período inicial do protótipo: do dia 1º do mês até hoje.
    _inicio = DateTime(_hoje.year, _hoje.month);
    _fim = _hoje;
    _carregar();
  }

  @override
  void dispose() {
    _telefone.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    if (!_periodoValido) {
      setState(() {
        _resumo = null;
        _carregando = false;
      });
      return;
    }
    // Só a última busca vale; enquanto carrega, os números antigos ficam esmaecidos.
    final pedido = ++_pedido;
    setState(() {
      _falha = null;
      _carregando = true;
    });
    try {
      final tel = _telefoneAplicado;
      final resultados = await Future.wait([
        widget.repositorio.resumo(_inicio, _fim, telefone: tel),
        widget.repositorio.porDia(_inicio, _fim, telefone: tel),
      ]);
      if (!mounted || pedido != _pedido) return;
      setState(() {
        _resumo = resultados[0] as ResumoFaturamento;
        _porDia = resultados[1] as Map<DateTime, double>;
        _carregando = false;
      });
    } on FalhaQuadra catch (f) {
      if (!mounted || pedido != _pedido) return;
      setState(() {
        _falha = f;
        _carregando = false;
      });
      if (f.sessaoExpirada) widget.aoSessaoExpirada?.call();
    }
  }

  void _aplicarTelefone(String texto) {
    final d = texto.replaceAll(RegExp(r'\D'), '');
    if (d.isNotEmpty && !RegExp(r'^[1-9]{2}9[0-9]{8}$').hasMatch(d)) {
      setState(() => _erroTelefone = 'Use o telefone completo: DDD + 9 + 8 dígitos.');
      return;
    }
    setState(() {
      _erroTelefone = null;
      _telefoneAplicado = d.isEmpty ? null : d;
    });
    _carregar();
  }

  Future<void> _escolherData({required bool inicio}) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicio ? _inicio : _fim,
      firstDate: DateTime(2020),
      lastDate: _hoje.add(const Duration(days: 366)),
      helpText: inicio ? 'DE' : 'ATÉ',
    );
    if (escolhida == null || !mounted) return;
    setState(() => inicio ? _inicio = escolhida : _fim = escolhida);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final estreito = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: AceCores.superficie,
      appBar: aceBarraAdmin(context, 'Faturamento', aoVoltar: widget.aoVoltar),
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
                    Text('FATURAMENTO',
                        style: AceEstilo.titulo.copyWith(fontSize: estreito ? 44 : 64)),
                    const SizedBox(height: 10),
                    const Text(
                      'Resumo das locações confirmadas e canceladas no período.',
                      style: TextStyle(color: AceCores.apagado, fontSize: 15),
                    ),
                    const SizedBox(height: 22),
                    _filtros(),
                    const SizedBox(height: 18),
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
      campoData('De', _inicio, true, const Key('faturamento-de')),
      campoData('Até', _fim, false, const Key('faturamento-ate')),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AceRotulo('Telefone (opcional)'),
          TextField(
            key: const Key('faturamento-telefone'),
            controller: _telefone,
            keyboardType: TextInputType.phone,
            decoration: AceEstilo.campo(hint: '(31) 99999-0000', erro: _erroTelefone).copyWith(
              suffixIcon: IconButton(
                tooltip: 'Aplicar',
                icon: const Icon(Icons.search, color: AceCores.verde),
                onPressed: () => _aplicarTelefone(_telefone.text),
              ),
            ),
            onSubmitted: _aplicarTelefone,
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
          final colunas = c.maxWidth > 760 ? 3 : 1;
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
    final resumo = _resumo;
    if (resumo == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: AceCores.verde)),
        ),
      ];
    }

    final dias = _diasDoGrafico();
    final cortou = _fim.difference(_inicio).inDays + 1 > FaturamentoPage.diasNoGrafico;
    return [
      AnimatedOpacity(
        opacity: _carregando ? .5 : 1,
        duration: const Duration(milliseconds: 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _indicadores(resumo, estreito),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AceCores.linha),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart, size: 18, color: AceCores.verde),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Faturamento por dia'
                          '${cortou ? ' · últimos ${FaturamentoPage.diasNoGrafico} dias do período' : ''}',
                          key: const Key('faturamento-titulo-grafico'),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: AceCores.apagado),
                        ),
                      ),
                      TextButton(
                        key: const Key('faturamento-alternar-tabela'),
                        onPressed: () => setState(() => _tabela = !_tabela),
                        style: TextButton.styleFrom(foregroundColor: AceCores.verde),
                        child: Text(_tabela ? 'Ver gráfico' : 'Ver como tabela'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_tabela)
                    _TabelaDias(dias: dias, porDia: _porDia)
                  else
                    _GraficoDias(dias: dias, porDia: _porDia),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<DateTime> _diasDoGrafico() {
    final total = _fim.difference(_inicio).inDays + 1;
    final n = math.min(total, FaturamentoPage.diasNoGrafico);
    final primeiro = _fim.subtract(Duration(days: n - 1));
    return [for (var i = 0; i < n; i++) DateTime(primeiro.year, primeiro.month, primeiro.day + i)];
  }

  Widget _indicadores(ResumoFaturamento r, bool estreito) {
    final cards = [
      _Indicador(
        chave: const Key('faturamento-locacoes'),
        rotulo: 'Locações confirmadas',
        valor: '${r.locacoes}',
      ),
      _Indicador(
        chave: const Key('faturamento-total'),
        rotulo: 'Faturamento total',
        valor: formatarReal(r.faturamento),
        destaque: true,
      ),
      _Indicador(
        chave: const Key('faturamento-canceladas'),
        rotulo: 'Canceladas',
        valor: '${r.canceladas}',
        corValor: AceCores.vermelho,
      ),
    ];
    if (estreito) {
      return Column(
        children: [
          for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 10), child: c),
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.chave,
    required this.rotulo,
    required this.valor,
    this.destaque = false,
    this.corValor,
  });

  final Key chave;
  final String rotulo;
  final String valor;
  final bool destaque;
  final Color? corValor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: destaque ? AceCores.verde : Colors.white,
        border: Border.all(color: destaque ? AceCores.verde : AceCores.linha),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: destaque ? Colors.white70 : AceCores.apagado,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              key: chave,
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                height: 1,
                color: destaque ? AceCores.bola : (corValor ?? AceCores.verde),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Colunas do faturamento diário. Uma série só, uma cor só (sem legenda: o título nomeia).
class _GraficoDias extends StatelessWidget {
  const _GraficoDias({required this.dias, required this.porDia});

  final List<DateTime> dias;
  final Map<DateTime, double> porDia;

  static const _altura = 220.0;
  static const _folgaTopo = 14.0; // espaço para o rótulo do maior dia
  static const _rotulos = 22.0; // linha dos dias, embaixo
  static const _total = _folgaTopo + _altura + _rotulos;
  static const _eixo = 64.0;
  static const _cor = AceCores.verdeMedio; // passa no validador de cor do gráfico

  @override
  Widget build(BuildContext context) {
    final valores = [for (final d in dias) porDia[d] ?? 0.0];
    final maior = valores.fold<double>(0, math.max);
    if (maior == 0) {
      return const Padding(
        key: Key('faturamento-grafico-vazio'),
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('Nenhuma locação confirmada no período.',
              style: TextStyle(color: AceCores.apagado)),
        ),
      );
    }
    final topo = _topoRedondo(maior);
    final destaque = valores.indexOf(maior);

    return LayoutBuilder(builder: (context, c) {
      final disponivel = c.maxWidth - _eixo;
      final faixa = math.max(disponivel / dias.length, 18.0);
      final largura = faixa * dias.length;
      // Rótulos de dia a cada N colunas, para não encostarem.
      final passo = (28 / faixa).ceil().clamp(1, 31);

      final grafico = SizedBox(
        width: largura,
        height: _total,
        child: Stack(
          children: [
            for (var i = 0; i <= 4; i++)
              Positioned(
                left: 0,
                right: 0,
                top: _folgaTopo + _altura * (1 - i / 4),
                child: Container(
                    key: Key('faturamento-grade-$i'), height: 1, color: AceCores.linha),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: _folgaTopo,
              height: _altura,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < dias.length; i++)
                    _Coluna(
                      largura: faixa,
                      alturaUtil: _altura,
                      fracao: valores[i] / topo,
                      dia: dias[i],
                      valor: valores[i],
                      cor: _cor,
                      rotuloAcima: i == destaque ? formatarReal(valores[i]) : null,
                    ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: _folgaTopo + _altura + 4,
              height: _rotulos - 4,
              child: Row(
                children: [
                  for (var i = 0; i < dias.length; i++)
                    SizedBox(
                      width: faixa,
                      child: i % passo == 0
                          ? Text(
                              dias[i].day.toString().padLeft(2, '0'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10, color: AceCores.apagado),
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      );

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _eixo,
            height: _total,
            child: Stack(
              children: [
                for (var i = 0; i <= 4; i++)
                  Positioned(
                    left: 0,
                    right: 8,
                    top: _folgaTopo + _altura * (1 - i / 4) - 7,
                    child: Text(
                      _rotuloEixo(topo * i / 4),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 10, color: AceCores.apagado),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true, // abre mostrando os dias mais recentes
              child: grafico,
            ),
          ),
        ],
      );
    });
  }

  /// Topo do eixo em número redondo (1, 2, 2,5 ou 5 × 10ⁿ), com 4 divisões.
  static double _topoRedondo(double maior) {
    final bruto = maior / 4;
    final potencia = math.pow(10, (math.log(bruto) / math.ln10).floor()).toDouble();
    for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (m * potencia >= bruto) return m * potencia * 4;
    }
    return maior;
  }

  static String _rotuloEixo(double v) {
    if (v >= 10000) {
      final mil = v / 1000;
      return 'R\$ ${mil == mil.roundToDouble() ? mil.toInt() : mil.toStringAsFixed(1).replaceAll('.', ',')} mil';
    }
    return formatarReal(v).replaceAll(',00', '');
  }
}

class _Coluna extends StatefulWidget {
  const _Coluna({
    required this.largura,
    required this.alturaUtil,
    required this.fracao,
    required this.dia,
    required this.valor,
    required this.cor,
    this.rotuloAcima,
  });

  final double largura;
  final double alturaUtil;
  final double fracao;
  final DateTime dia;
  final double valor;
  final Color cor;
  final String? rotuloAcima;

  @override
  State<_Coluna> createState() => _ColunaState();
}

class _ColunaState extends State<_Coluna> {
  bool _sobre = false;

  @override
  Widget build(BuildContext context) {
    final texto = '${dataBr(widget.dia)} · ${formatarReal(widget.valor)}';
    final altura = widget.alturaUtil * widget.fracao;
    // Coluna fina (até 24 px), com folga de ar na faixa; a faixa inteira é o alvo do toque.
    final grossura = math.min(24.0, widget.largura - 2);
    return Tooltip(
      message: texto,
      waitDuration: Duration.zero,
      child: MouseRegion(
        onEnter: (_) => setState(() => _sobre = true),
        onExit: (_) => setState(() => _sobre = false),
        child: Semantics(
          label: texto,
          child: SizedBox(
            key: Key('faturamento-dia-${widget.dia.day}-${widget.dia.month}'),
            width: widget.largura,
            height: widget.alturaUtil,
            // O rótulo do maior dia fica acima da coluna, na folga do topo do gráfico.
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                if (altura > 0)
                  Container(
                    key: Key('faturamento-barra-${widget.dia.day}-${widget.dia.month}'),
                    width: grossura,
                    height: math.max(altura, 3),
                    decoration: BoxDecoration(
                      color: _sobre ? Color.lerp(widget.cor, Colors.white, .25) : widget.cor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                if (widget.rotuloAcima != null)
                  Positioned(
                    bottom: math.max(altura, 3) + 3,
                    child: Text(
                      widget.rotuloAcima!,
                      key: const Key('faturamento-maior-dia'),
                      softWrap: false,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: AceCores.tinta),
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

/// Mesmos números do gráfico em tabela (acessível e sem depender de passar o mouse).
class _TabelaDias extends StatelessWidget {
  const _TabelaDias({required this.dias, required this.porDia});

  final List<DateTime> dias;
  final Map<DateTime, double> porDia;

  @override
  Widget build(BuildContext context) {
    final comValor = [for (final d in dias) if ((porDia[d] ?? 0) > 0) d];
    if (comValor.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('Nenhuma locação confirmada no período.',
            style: TextStyle(color: AceCores.apagado)),
      );
    }
    return Column(
      key: const Key('faturamento-tabela'),
      children: [
        for (final d in comValor)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AceCores.linha)),
            ),
            child: Row(
              children: [
                Expanded(child: Text(dataBr(d), style: const TextStyle(fontSize: 14))),
                Text(formatarReal(porDia[d]!),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}
