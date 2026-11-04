import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/funcionamento.dart';
import '../models/preco.dart';
import '../models/quadra.dart';
import '../tema/ace_componentes.dart';
import '../tema/ace_cores.dart';
import 'precos_repositorio.dart';
import 'quadras_repositorio.dart' show FalhaQuadra;

/// Preços por faixa de horário (atividade 5.7 · H4 · RF18–RF20). Cada quadra tem uma
/// tabela de dia útil e outra de fim de semana (que também vale nos feriados). Visual da
/// tela "Preços por faixa" do protótipo Ace Saibro: abas, linhas de faixa e linha do tempo.
class PrecosPage extends StatefulWidget {
  const PrecosPage({
    super.key,
    required this.repositorio,
    this.aoVoltar,
    this.aoSessaoExpirada,
  });

  final PrecosRepositorio repositorio;
  final VoidCallback? aoVoltar;
  final VoidCallback? aoSessaoExpirada;

  @override
  State<PrecosPage> createState() => _PrecosPageState();
}

/// Cores das faixas na linha do tempo (`PCOL` do protótipo).
const _coresFaixa = [
  Color(0xFF1B5E20),
  Color(0xFF388E3C),
  Color(0xFF689F38),
  Color(0xFF9E9D24),
  Color(0xFF558B2F),
];
const _laranja = Color(0xFFB45309);
const _laranjaClaro = Color(0xFFFFE8C7);

/// Faixa editável. O valor fica num controlador para não perder o cursor ao redesenhar.
class _Faixa {
  _Faixa(this.inicio, this.fim, String valor) : valor = TextEditingController(text: valor);

  int inicio;
  int fim;
  final TextEditingController valor;

  FaixaEditada get editada => FaixaEditada(inicio, fim, valor.text);
}

class _PrecosPageState extends State<PrecosPage> {
  List<Quadra>? _quadras;
  Map<int, Semana> _funcionamento = {};
  Map<int, TabelaPrecos> _salvo = {};
  final Map<int, Map<TipoDia, List<_Faixa>>> _edicao = {};
  int? _quadraId;
  TipoDia _aba = TipoDia.util;
  FalhaQuadra? _falhaCarga;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _descartarEdicao();
    super.dispose();
  }

  void _descartarEdicao() {
    for (final porTipo in _edicao.values) {
      for (final faixas in porTipo.values) {
        for (final f in faixas) {
          f.valor.dispose();
        }
      }
    }
    _edicao.clear();
  }

  Future<void> _carregar() async {
    setState(() => _falhaCarga = null);
    try {
      final quadras = await widget.repositorio.quadras();
      final funcionamento = await widget.repositorio.funcionamento();
      final tabelas = await widget.repositorio.tabelas();
      if (!mounted) return;
      setState(() {
        _quadras = quadras;
        _funcionamento = funcionamento;
        _salvo = {
          for (final q in quadras)
            q.id: tabelas[q.id] ?? {TipoDia.util: [], TipoDia.fimDeSemana: []},
        };
        _descartarEdicao();
        for (final q in quadras) {
          _edicao[q.id] = {for (final t in TipoDia.values) t: _paraEdicao(_salvo[q.id]![t]!)};
        }
        if (_quadraId == null || !quadras.any((q) => q.id == _quadraId)) {
          _quadraId = quadras.isEmpty ? null : quadras.first.id;
        }
      });
    } on FalhaQuadra catch (f) {
      if (!mounted) return;
      setState(() => _falhaCarga = f);
      if (f.sessaoExpirada) widget.aoSessaoExpirada?.call();
    }
  }

  static List<_Faixa> _paraEdicao(List<FaixaPreco> faixas) =>
      [for (final f in faixas) _Faixa(f.inicio, f.fim, textoValor(f.valor))];

  List<_Faixa> _faixas(int quadraId, TipoDia tipo) => _edicao[quadraId]![tipo]!;

  Set<int> _cobrir(int quadraId, TipoDia tipo) =>
      horasACobrir(_funcionamento[quadraId] ?? const {}, tipo);

  ValidacaoFaixas _validar(int quadraId, TipoDia tipo) => validarFaixas(
      [for (final f in _faixas(quadraId, tipo)) f.editada], _cobrir(quadraId, tipo));

  /// Faixas da aba já como serão gravadas (só chame com a aba válida).
  List<FaixaPreco> _paraSalvar(int quadraId, TipoDia tipo) => [
        for (final f in _faixas(quadraId, tipo)) FaixaPreco(f.inicio, f.fim, lerValor(f.valor.text)!)
      ]..sort((a, b) => a.inicio.compareTo(b.inicio));

  bool _alterada(int quadraId, TipoDia tipo) {
    final salvas = [..._salvo[quadraId]![tipo]!]..sort((a, b) => a.inicio.compareTo(b.inicio));
    final editadas = _faixas(quadraId, tipo);
    if (editadas.length != salvas.length) return true;
    final ordenadas = [...editadas]..sort((a, b) => a.inicio.compareTo(b.inicio));
    for (var i = 0; i < salvas.length; i++) {
      final e = ordenadas[i];
      final s = salvas[i];
      if (e.inicio != s.inicio || e.fim != s.fim || lerValor(e.valor.text) != s.valor) return true;
    }
    return false;
  }

  void _adicionar() {
    final id = _quadraId!;
    final faixas = _faixas(id, _aba);
    final cobrir = _cobrir(id, _aba).toList()..sort();
    // Começa onde a última faixa termina (ou na abertura) e vai até o fim do funcionamento.
    final inicio = faixas.isEmpty
        ? (cobrir.isEmpty ? 7 : cobrir.first)
        : faixas.map((f) => f.fim).reduce((a, b) => a > b ? a : b).clamp(0, 23);
    final ultimo = cobrir.isEmpty ? inicio + 1 : cobrir.last + 1;
    final fim = ultimo > inicio ? ultimo : inicio + 1;
    setState(() => faixas.add(_Faixa(inicio, fim.clamp(1, 24), '')));
  }

  void _remover(int i) {
    final faixas = _faixas(_quadraId!, _aba);
    setState(() => faixas.removeAt(i).valor.dispose());
  }

  Future<void> _salvar() async {
    final id = _quadraId!;
    final tipo = _aba;
    if (!_validar(id, tipo).valida || !_alterada(id, tipo)) return;
    final novas = _paraSalvar(id, tipo);
    final quadra = _quadras!.firstWhere((q) => q.id == id);
    setState(() => _salvando = true);
    try {
      await widget.repositorio.salvar(id, tipo, novas);
      _salvo[id]![tipo] = novas;
      // H4 alternativo 2: o valor gravado nas reservas não muda; só informamos quantas são.
      var mantidas = 0;
      try {
        final reservas = await widget.repositorio.reservasFuturas(id);
        final feriados = reservas.isEmpty ? <String>{} : await widget.repositorio.feriados();
        mantidas = reservasComValorAnterior(reservas, tipo, novas, feriados);
      } on FalhaQuadra {
        // A tabela já foi salva; sem a contagem, só não mostramos o aviso extra.
      }
      if (!mounted) return;
      setState(() => _salvando = false);
      final base = 'Preços de ${tipo.rotulo.toLowerCase()} da ${quadra.nome} salvos.';
      aceAviso(
        context,
        mantidas == 0
            ? base
            : mantidas == 1
                ? '$base 1 reserva futura mantém o valor anterior.'
                : '$base $mantidas reservas futuras mantêm o valor anterior.',
      );
    } on FalhaQuadra catch (f) {
      if (!mounted) return;
      setState(() => _salvando = false);
      aceAviso(context, f.mensagem, erro: true);
      if (f.sessaoExpirada) widget.aoSessaoExpirada?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: aceBarraAdmin(context, 'Preços', aoVoltar: widget.aoVoltar),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('PREÇOS POR FAIXA',
                      style: AceEstilo.titulo.copyWith(
                          fontSize: MediaQuery.sizeOf(context).width < 600 ? 40 : 64)),
                  const SizedBox(height: 10),
                  const Text(
                    'Defina o valor da hora por faixa de horário. As faixas não podem se sobrepor '
                    'e devem cobrir todo o horário de funcionamento. Reservas já feitas mantêm o '
                    'valor da época do agendamento.',
                    style: TextStyle(color: AceCores.apagado, fontSize: 15),
                  ),
                  const SizedBox(height: 22),
                  ..._conteudo(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _conteudo() {
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
    final quadras = _quadras;
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

    final id = _quadraId!;
    final faixas = _faixas(id, _aba);
    final cobrir = _cobrir(id, _aba);
    final validacao = _validar(id, _aba);
    final alterada = _alterada(id, _aba);
    final quadra = quadras.firstWhere((q) => q.id == id);

    return [
      // Seletor de quadra.
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final q in quadras)
            _Pilula(
              key: Key('precos-quadra-${q.id}'),
              texto: q.nome,
              marcada: q.id == id,
              pendente: TipoDia.values.any((t) => _alterada(q.id, t)),
              aoTocar: _salvando ? null : () => setState(() => _quadraId = q.id),
            ),
        ],
      ),
      const SizedBox(height: 14),
      // Abas do tipo de dia.
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: const Color(0xFFE6ECE6), borderRadius: BorderRadius.circular(99)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in TipoDia.values)
                  _Aba(
                    key: Key('precos-aba-${t.valor}'),
                    texto: t.rotulo,
                    marcada: t == _aba,
                    pendente: _alterada(id, t),
                    aoTocar: _salvando ? null : () => setState(() => _aba = t),
                  ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (!quadra.ativa)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Quadra inativa: os preços valem quando ela voltar a ser ativada.',
              style: TextStyle(color: AceCores.apagado, fontSize: 13.5)),
        ),
      // Faixas.
      _Cartao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (faixas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Sem faixas. Adicione ao menos uma faixa de preço para esta aba.',
                    style: TextStyle(color: AceCores.apagado)),
              ),
            for (var i = 0; i < faixas.length; i++)
              _LinhaFaixa(
                key: ObjectKey(faixas[i]),
                indice: i,
                faixa: faixas[i],
                habilitado: !_salvando,
                aoMudar: () => setState(() {}),
                aoRemover: () => _remover(i),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const Key('precos-adicionar'),
                onPressed: _salvando ? null : _adicionar,
                style: AceEstilo.botaoTonal,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar faixa'),
              ),
            ),
          ],
        ),
      ),
      // Linha do tempo + problemas.
      _Cartao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AceCores.apagado),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Horas de funcionamento que precisam de preço (${_aba.dias})',
                    style: const TextStyle(color: AceCores.apagado, fontSize: 13.5),
                  ),
                ),
              ],
            ),
            if (_aba == TipoDia.fimDeSemana)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Feriado pode cair num dia útil, então esta tabela cobre o horário de todos os dias.',
                  style: TextStyle(color: AceCores.apagado, fontSize: 12.5),
                ),
              ),
            const SizedBox(height: 12),
            if (cobrir.isEmpty)
              const Text('Esta quadra não abre em nenhum dia desta aba.',
                  style: TextStyle(color: AceCores.apagado, fontStyle: FontStyle.italic))
            else
              _LinhaDoTempo(horas: cobrir, faixas: faixas, validacao: validacao),
            const SizedBox(height: 12),
            if (validacao.valida)
              const _Problema(
                ok: true,
                texto: 'Faixas válidas: sem sobreposição e cobrindo todo o horário de funcionamento.',
              )
            else
              for (final e in validacao.erros) _Problema(texto: e),
          ],
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 64,
        child: FilledButton(
          key: const Key('precos-salvar'),
          onPressed: (_salvando || !alterada || !validacao.valida) ? null : _salvar,
          style: AceEstilo.botaoPrimario,
          child: _salvando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                )
              : Text(
                  alterada ? 'SALVAR ${_aba.rotulo.toUpperCase()}' : 'NADA PARA SALVAR',
                  textAlign: TextAlign.center,
                  style: AceEstilo.fab,
                ),
        ),
      ),
    ];
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AceCores.linha),
          borderRadius: BorderRadius.circular(26),
        ),
        child: child,
      );
}

/// Botão de quadra. O ponto amarelo indica alteração ainda não salva.
class _Pilula extends StatelessWidget {
  const _Pilula({
    super.key,
    required this.texto,
    required this.marcada,
    required this.pendente,
    required this.aoTocar,
  });

  final String texto;
  final bool marcada;
  final bool pendente;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: marcada ? AceCores.verde : Colors.white,
      shape: StadiumBorder(
          side: BorderSide(color: marcada ? AceCores.verde : AceCores.linha, width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(texto,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: marcada ? Colors.white : AceCores.tinta)),
              ),
              if (pendente) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AceCores.bola, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Aba extends StatelessWidget {
  const _Aba({
    super.key,
    required this.texto,
    required this.marcada,
    required this.pendente,
    required this.aoTocar,
  });

  final String texto;
  final bool marcada;
  final bool pendente;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: marcada,
      button: true,
      child: Material(
        color: marcada ? AceCores.verde : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: aoTocar,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            child: Text(
              pendente ? '$texto •' : texto,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: marcada ? Colors.white : AceCores.tinta),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinhaFaixa extends StatelessWidget {
  const _LinhaFaixa({
    super.key,
    required this.indice,
    required this.faixa,
    required this.habilitado,
    required this.aoMudar,
    required this.aoRemover,
  });

  final int indice;
  final _Faixa faixa;
  final bool habilitado;
  final VoidCallback aoMudar;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    final chave = 'faixa-$indice';
    final valorInvalido = faixa.valor.text.isNotEmpty &&
        ((lerValor(faixa.valor.text) ?? 0) <= 0);
    final inicio = _SeletorHora(
      key: Key('$chave-inicio'),
      valor: faixa.inicio,
      de: 0,
      ate: 23,
      habilitado: habilitado,
      aoMudar: (h) {
        faixa.inicio = h;
        aoMudar();
      },
    );
    final fim = _SeletorHora(
      key: Key('$chave-fim'),
      valor: faixa.fim,
      de: 1,
      ate: 24,
      erro: faixa.fim <= faixa.inicio,
      habilitado: habilitado,
      aoMudar: (h) {
        faixa.fim = h;
        aoMudar();
      },
    );
    final valor = TextField(
      key: Key('$chave-valor'),
      controller: faixa.valor,
      enabled: habilitado,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        LengthLimitingTextInputFormatter(12),
      ],
      onChanged: (_) => aoMudar(),
      decoration: AceEstilo.campo(hint: '0,00', erro: valorInvalido ? 'Valor inválido' : null)
          .copyWith(
        prefixText: 'R\$ ',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
    final remover = IconButton(
      key: Key('$chave-remover'),
      tooltip: 'Remover faixa',
      onPressed: habilitado ? aoRemover : null,
      icon: const Icon(Icons.delete_outline, color: AceCores.vermelho),
    );
    final numero = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: _coresFaixa[indice % _coresFaixa.length], shape: BoxShape.circle),
      child: Text('${indice + 1}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
    );
    const as = Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text('às', style: TextStyle(color: AceCores.apagado)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                numero,
                const SizedBox(width: 10),
                Expanded(child: inicio),
                as,
                Expanded(child: fim),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const SizedBox(width: 40),
                Expanded(child: valor),
                remover,
              ]),
              const Divider(height: 18, color: AceCores.linha),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 7), child: numero),
            const SizedBox(width: 12),
            SizedBox(width: 120, child: inicio),
            const Padding(padding: EdgeInsets.only(top: 12), child: as),
            SizedBox(width: 120, child: fim),
            const SizedBox(width: 16),
            SizedBox(width: 200, child: valor),
            const SizedBox(width: 4),
            remover,
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
    required this.habilitado,
    required this.aoMudar,
    this.erro = false,
  });

  final int valor;
  final int de;
  final int ate;
  final bool habilitado;
  final bool erro;
  final ValueChanged<int> aoMudar;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 15, color: AceCores.tinta),
          items: [
            for (var h = de; h <= ate; h++)
              DropdownMenuItem(value: h, child: Text(Intervalo.textoDe(h))),
          ],
          onChanged: habilitado ? (h) => aoMudar(h ?? valor) : null,
        ),
      ),
    );
  }
}

/// Uma célula por hora de funcionamento: cor da faixa, vermelho se sobreposta, listrado
/// laranja se sem preço.
class _LinhaDoTempo extends StatelessWidget {
  const _LinhaDoTempo({required this.horas, required this.faixas, required this.validacao});

  final Set<int> horas;
  final List<_Faixa> faixas;
  final ValidacaoFaixas validacao;

  @override
  Widget build(BuildContext context) {
    final ordenadas = horas.toList()..sort();
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (final h in ordenadas) _celula(h),
      ],
    );
  }

  Widget _celula(int h) {
    final rotulo = h.toString().padLeft(2, '0');
    Color fundo;
    Color texto = Colors.white;
    String dica;
    if (validacao.lacunas.contains(h)) {
      fundo = _laranjaClaro;
      texto = _laranja;
      dica = '${rotulo}h sem preço';
    } else if (validacao.sobrepostas.contains(h)) {
      fundo = AceCores.vermelho;
      dica = '${rotulo}h sobreposta';
    } else {
      final i = faixas.indexWhere((f) => f.fim > f.inicio && h >= f.inicio && h < f.fim);
      fundo = _coresFaixa[(i < 0 ? 0 : i) % _coresFaixa.length];
      final v = i < 0 ? null : lerValor(faixas[i].valor.text);
      dica = v == null ? '${rotulo}h' : '${rotulo}h · R\$ ${textoValor(v)}';
    }
    return Tooltip(
      message: dica,
      child: Container(
        key: Key('hora-$h'),
        width: 38,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: BorderRadius.circular(8),
          border: validacao.lacunas.contains(h) ? Border.all(color: const Color(0xFFFFD39B)) : null,
        ),
        child: Text(rotulo,
            style: TextStyle(
                color: texto,
                fontFamily: 'monospace',
                fontSize: 12.5,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _Problema extends StatelessWidget {
  const _Problema({required this.texto, this.ok = false});

  final String texto;
  final bool ok;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                size: 18, color: ok ? AceCores.verde : AceCores.vermelho),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texto,
                  key: ok ? const Key('precos-ok') : const Key('precos-erro'),
                  style: TextStyle(
                      fontSize: 13.5, color: ok ? AceCores.verde : const Color(0xFF8E1B1B))),
            ),
          ],
        ),
      );
}
