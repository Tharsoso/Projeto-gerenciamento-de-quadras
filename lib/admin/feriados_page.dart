import 'package:flutter/material.dart';

import '../fuso.dart';
import '../models/bloqueio.dart' show dataBr, dataIso;
import '../models/funcionamento.dart' show nomesDias, diaSemanaDe;
import '../tema/ace_componentes.dart';
import '../tema/ace_cores.dart';
import 'feriados_repositorio.dart';
import 'quadras_repositorio.dart' show FalhaQuadra;

/// Calendário de feriados (atividade 5.7 · H4 alternativo 3 · RF21). Nos feriados vale a
/// tabela de preço de fim de semana. Visual da tela "Feriados" do protótipo Ace Saibro:
/// abas por ano, lista e botão "Novo feriado".
class FeriadosPage extends StatefulWidget {
  const FeriadosPage({
    super.key,
    required this.repositorio,
    this.aoVoltar,
    this.aoSessaoExpirada,
    this.hoje,
  });

  final FeriadosRepositorio repositorio;
  final VoidCallback? aoVoltar;
  final VoidCallback? aoSessaoExpirada;

  /// Data de hoje (para testes). Sem ela, usa o relógio do aparelho.
  final DateTime? hoje;

  @override
  State<FeriadosPage> createState() => _FeriadosPageState();
}

const _barro = Color(0xFFA4400F);
const _barroClaro = Color(0xFFFBE9E0);

class _FeriadosPageState extends State<FeriadosPage> {
  List<Feriado>? _feriados;
  FalhaQuadra? _falhaCarga;
  final Set<String> _removendo = {};
  late int _ano = _hoje.year;

  DateTime get _hoje {
    final h = widget.hoje ?? agoraBrasilia();
    return DateTime(h.year, h.month, h.day);
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _falhou(FalhaQuadra f) {
    if (f.sessaoExpirada) widget.aoSessaoExpirada?.call();
  }

  Future<void> _carregar() async {
    setState(() => _falhaCarga = null);
    try {
      final lista = await widget.repositorio.listar();
      if (mounted) setState(() => _feriados = lista);
    } on FalhaQuadra catch (f) {
      if (!mounted) return;
      setState(() => _falhaCarga = f);
      _falhou(f);
    }
  }

  /// Anos com feriado, mais o atual e o próximo (para cadastrar com antecedência).
  List<int> get _anos => ({
        _hoje.year,
        _hoje.year + 1,
        for (final f in _feriados ?? const <Feriado>[]) f.data.year,
      }.toList()
        ..sort());

  Future<void> _novo() async {
    final criado = await showDialog<DateTime>(
      context: context,
      barrierColor: const Color(0x8C0A180C),
      builder: (_) => _NovoFeriado(
        repositorio: widget.repositorio,
        dataInicial: _ano == _hoje.year ? _hoje : DateTime(_ano, 1, 1),
        existentes: {for (final f in _feriados ?? const <Feriado>[]) dataIso(f.data)},
        aoSessaoExpirada: widget.aoSessaoExpirada,
      ),
    );
    if (criado == null || !mounted) return;
    setState(() => _ano = criado.year);
    aceAviso(context, 'Feriado cadastrado. Vale o preço de fim de semana nesse dia.');
    await _carregar();
  }

  Future<void> _remover(Feriado f) async {
    final chave = dataIso(f.data);
    setState(() => _removendo.add(chave));
    try {
      await widget.repositorio.remover(f.data);
      if (!mounted) return;
      setState(() {
        _removendo.remove(chave);
        _feriados = [...?_feriados]..removeWhere((x) => dataIso(x.data) == chave);
      });
      aceAviso(context, 'Feriado removido. Reservas já feitas mantêm o valor que foi cobrado.');
    } on FalhaQuadra catch (e) {
      if (!mounted) return;
      setState(() => _removendo.remove(chave));
      aceAviso(context, e.mensagem, erro: true);
      _falhou(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estreito = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: aceBarraAdmin(context, 'Feriados', aoVoltar: widget.aoVoltar),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('feriados-novo'),
        onPressed: _feriados == null ? null : _novo,
        backgroundColor: AceCores.bola,
        foregroundColor: AceCores.tinta,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.add, size: 26),
        label: const Text('NOVO FERIADO', style: AceEstilo.fab),
      ),
      body: RefreshIndicator(
        color: AceCores.verde,
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 110),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('FERIADOS', style: AceEstilo.titulo.copyWith(fontSize: estreito ? 40 : 64)),
                    const SizedBox(height: 10),
                    const Text(
                      'Nos feriados vale o preço de fim de semana, mesmo que caiam num dia útil. '
                      'Cadastre aqui os feriados nacionais, estaduais e municipais.',
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
    final feriados = _feriados;
    if (feriados == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: AceCores.verde)),
        ),
      ];
    }
    final doAno = feriados.where((f) => f.data.year == _ano).toList()
      ..sort((a, b) => a.data.compareTo(b.data));
    return [
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
                for (final a in _anos)
                  Material(
                    color: a == _ano ? AceCores.verde : Colors.transparent,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      key: Key('feriados-ano-$a'),
                      customBorder: const StadiumBorder(),
                      onTap: () => setState(() => _ano = a),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.center,
                        child: Text('$a',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: a == _ano ? Colors.white : AceCores.tinta)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (doAno.isEmpty)
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: AceCores.superficie,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              Text('SEM FERIADOS EM $_ano',
                  style: AceEstilo.nomeQuadra.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Use "Novo feriado" para cadastrar.',
                  style: TextStyle(color: AceCores.apagado)),
            ],
          ),
        )
      else
        for (final f in doAno)
          _LinhaFeriado(
            feriado: f,
            passado: f.data.isBefore(_hoje),
            removendo: _removendo.contains(dataIso(f.data)),
            aoRemover: () => _remover(f),
          ),
    ];
  }
}

class _LinhaFeriado extends StatelessWidget {
  const _LinhaFeriado({
    required this.feriado,
    required this.passado,
    required this.removendo,
    required this.aoRemover,
  });

  final Feriado feriado;
  final bool passado;
  final bool removendo;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    final dia = diaSemanaDe(feriado.data);
    final util = dia >= 1 && dia <= 5;
    return Opacity(
      opacity: passado ? .6 : 1,
      child: Container(
        key: Key('feriado-${dataIso(feriado.data)}'),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AceCores.linha),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration:
                  BoxDecoration(color: _barroClaro, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.beach_access, color: _barro),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(feriado.descricao,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    '${dataBr(feriado.data)} · ${nomesDias[dia]}'
                    '${util ? ' · preço de fim de semana' : ''}',
                    style: const TextStyle(color: AceCores.apagado, fontSize: 13.5),
                  ),
                ],
              ),
            ),
            if (removendo)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AceCores.verde)),
              )
            else
              IconButton(
                key: Key('feriado-remover-${dataIso(feriado.data)}'),
                tooltip: 'Remover feriado',
                onPressed: aoRemover,
                icon: const Icon(Icons.delete_outline, color: AceCores.vermelho),
              ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo "Novo feriado". Devolve a data cadastrada, ou null se cancelou.
class _NovoFeriado extends StatefulWidget {
  const _NovoFeriado({
    required this.repositorio,
    required this.dataInicial,
    required this.existentes,
    this.aoSessaoExpirada,
  });

  final FeriadosRepositorio repositorio;
  final DateTime dataInicial;

  /// Datas (`aaaa-mm-dd`) que já são feriado: avisa antes de ir ao banco.
  final Set<String> existentes;
  final VoidCallback? aoSessaoExpirada;

  @override
  State<_NovoFeriado> createState() => _NovoFeriadoState();
}

class _NovoFeriadoState extends State<_NovoFeriado> {
  late DateTime _data = widget.dataInicial;
  final _descricao = TextEditingController();
  String? _erroData;
  String? _erroDescricao;
  String? _erroGeral;
  bool _salvando = false;

  @override
  void dispose() {
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(_data.year - 1),
      lastDate: DateTime(_data.year + 3, 12, 31),
      helpText: 'Data do feriado',
    );
    if (escolhida == null || !mounted) return;
    setState(() {
      _data = escolhida;
      _erroData = null;
    });
  }

  Future<void> _salvar() async {
    final texto = _descricao.text.trim();
    setState(() {
      _erroData = widget.existentes.contains(dataIso(_data))
          ? 'Já existe um feriado nesta data.'
          : null;
      _erroDescricao = texto.length < 3 ? 'Informe a descrição (mínimo de 3 letras).' : null;
      _erroGeral = null;
    });
    if (_erroData != null || _erroDescricao != null) return;
    setState(() => _salvando = true);
    try {
      await widget.repositorio.adicionar(_data, texto);
      if (mounted) Navigator.of(context).pop(_data);
    } on FalhaQuadra catch (f) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        if (f.codigo == 'FERIADO_DUPLICADO') {
          _erroData = f.mensagem;
        } else {
          _erroGeral = f.mensagem;
        }
      });
      if (f.sessaoExpirada) {
        Navigator.of(context).pop();
        widget.aoSessaoExpirada?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('NOVO FERIADO', style: AceEstilo.tituloDialogo),
              const SizedBox(height: 18),
              if (_erroGeral != null) AceAlerta(mensagem: _erroGeral!),
              const AceRotulo('Data'),
              OutlinedButton.icon(
                key: const Key('feriado-data'),
                onPressed: _salvando ? null : _escolherData,
                style: AceEstilo.botaoContorno.copyWith(
                  alignment: Alignment.centerLeft,
                  side: WidgetStatePropertyAll(BorderSide(
                      color: _erroData != null ? AceCores.vermelho : AceCores.linha, width: 1.5)),
                ),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text('${dataBr(_data)} · ${nomesDias[diaSemanaDe(_data)]}'),
              ),
              if (_erroData != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 6),
                  child: Text(_erroData!,
                      key: const Key('feriado-erro-data'),
                      style: const TextStyle(color: AceCores.vermelho, fontSize: 12.5)),
                ),
              const SizedBox(height: 16),
              const AceRotulo('Descrição'),
              TextField(
                key: const Key('feriado-descricao'),
                controller: _descricao,
                enabled: !_salvando,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _salvar(),
                decoration:
                    AceEstilo.campo(hint: 'Ex.: Aniversário da cidade', erro: _erroDescricao),
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: _salvando ? null : () => Navigator.of(context).pop(),
                    style: AceEstilo.botaoContorno,
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    key: const Key('feriado-salvar'),
                    onPressed: _salvando ? null : _salvar,
                    style: AceEstilo.botaoPrimario,
                    child: _salvando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Adicionar'),
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
