import 'package:flutter/material.dart';

import '../models/bloqueio.dart';
import '../models/funcionamento.dart' show nomesDias, diaSemanaDe, Intervalo;
import '../models/quadra.dart';
import '../tema/ace_componentes.dart';
import '../tema/ace_cores.dart';
import 'bloqueios_repositorio.dart';
import 'quadras_repositorio.dart' show FalhaQuadra;

/// Bloqueio de horários para manutenção (atividade 5.6 · H5 · RF17): listar os bloqueios
/// futuros, bloquear um horário livre e desbloquear. Visual da tela "Bloqueios" do
/// protótipo Ace Saibro (marrom = bloqueado, igual à consulta pública).
class BloqueiosPage extends StatefulWidget {
  const BloqueiosPage({
    super.key,
    required this.repositorio,
    this.aoVoltar,
    this.aoSessaoExpirada,
    this.hoje,
  });

  final BloqueiosRepositorio repositorio;
  final VoidCallback? aoVoltar;
  final VoidCallback? aoSessaoExpirada;

  /// Data de hoje (para testes). Sem ela, usa o relógio do aparelho.
  final DateTime? hoje;

  @override
  State<BloqueiosPage> createState() => _BloqueiosPageState();
}

class _BloqueiosPageState extends State<BloqueiosPage> {
  List<Bloqueio>? _bloqueios;
  FalhaQuadra? _falhaCarga;
  final Set<int> _removendo = {};

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
      final lista = await widget.repositorio.futuros();
      if (mounted) setState(() => _bloqueios = lista);
    } on FalhaQuadra catch (f) {
      if (!mounted) return;
      setState(() => _falhaCarga = f);
      _falhou(f);
    }
  }

  Future<void> _novo() async {
    final criado = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x8C0A180C),
      builder: (_) => _NovoBloqueio(
        repositorio: widget.repositorio,
        hoje: _hoje,
        aoSessaoExpirada: widget.aoSessaoExpirada,
      ),
    );
    if (criado != true || !mounted) return;
    aceAviso(context, 'Horário bloqueado. Ele já aparece em marrom para os clientes.');
    await _carregar();
  }

  Future<void> _remover(Bloqueio b) async {
    setState(() => _removendo.add(b.id));
    try {
      await widget.repositorio.desbloquear(b.id);
      if (!mounted) return;
      setState(() {
        _removendo.remove(b.id);
        _bloqueios = [...?_bloqueios]..removeWhere((x) => x.id == b.id);
      });
      aceAviso(context, 'Bloqueio removido. O horário voltou a ficar livre.');
    } on FalhaQuadra catch (f) {
      if (!mounted) return;
      setState(() => _removendo.remove(b.id));
      aceAviso(context, f.mensagem, erro: true);
      _falhou(f);
    }
  }

  DateTime get _hoje {
    final h = widget.hoje ?? DateTime.now();
    return DateTime(h.year, h.month, h.day);
  }

  @override
  Widget build(BuildContext context) {
    final estreito = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: aceBarraAdmin(context, 'Bloqueios', aoVoltar: widget.aoVoltar),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('bloqueios-novo'),
        onPressed: _bloqueios == null ? null : _novo,
        backgroundColor: AceCores.bola,
        foregroundColor: AceCores.tinta,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.add, size: 26),
        label: const Text('NOVO BLOQUEIO', style: AceEstilo.fab),
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
                    Text('BLOQUEIOS',
                        style: AceEstilo.titulo.copyWith(fontSize: estreito ? 48 : 64)),
                    const SizedBox(height: 10),
                    const Text(
                      'Reserve horários para manutenção ou eventos. Eles aparecem em marrom para '
                      'os clientes e não podem ser reservados.',
                      style: TextStyle(color: AceCores.apagado, fontSize: 15),
                    ),
                    const SizedBox(height: 22),
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

  List<Widget> _conteudo(bool estreito) {
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
    final lista = _bloqueios;
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          decoration: BoxDecoration(
            border: Border.all(color: AceCores.linha, width: 1.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Text('NENHUM BLOQUEIO FUTURO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: estreito ? 28 : 40,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      color: AceCores.tinta)),
              const SizedBox(height: 6),
              const Text('Use “Novo bloqueio” para reservar um horário de manutenção.',
                  textAlign: TextAlign.center, style: TextStyle(color: AceCores.apagado)),
            ],
          ),
        ),
      ];
    }
    return [
      for (final b in lista)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _LinhaBloqueio(
            bloqueio: b,
            estreito: estreito,
            removendo: _removendo.contains(b.id),
            aoRemover: () => _remover(b),
          ),
        ),
    ];
  }
}

class _LinhaBloqueio extends StatelessWidget {
  const _LinhaBloqueio({
    required this.bloqueio,
    required this.estreito,
    required this.removendo,
    required this.aoRemover,
  });

  final Bloqueio bloqueio;
  final bool estreito;
  final bool removendo;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    final b = bloqueio;
    // No celular, formato curto para o horário (o dado principal) não ser cortado.
    final faixa = estreito
        ? '${b.hora}h–${b.hora + 1}h'
        : '${Intervalo.textoDe(b.hora)}–${Intervalo.textoDe(b.hora + 1)}';
    final motivo = b.motivo;
    final chave = Key('bloqueio-remover-${b.id}');
    return Container(
      key: Key('bloqueio-${b.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AceCores.linha),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AceCores.marromClaro, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.block, color: AceCores.marrom, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(b.quadraNome.toUpperCase(), style: AceEstilo.nomeQuadra),
                    AceChip(texto: faixa, fundo: AceCores.marromClaro, cor: AceCores.marrom),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${dataBr(b.data)} · ${nomesDias[diaSemanaDe(b.data)]} · '
                  '${(motivo == null || motivo.isEmpty) ? 'Sem motivo informado' : motivo}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AceCores.apagado),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (removendo)
            const SizedBox(
              width: 44,
              height: 44,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 3, color: AceCores.verde),
              ),
            )
          else if (estreito)
            IconButton.outlined(
              key: chave,
              tooltip: 'Remover bloqueio',
              onPressed: aoRemover,
              style: IconButton.styleFrom(
                  side: const BorderSide(color: AceCores.linha, width: 1.5)),
              icon: const Icon(Icons.delete_outline),
            )
          else
            OutlinedButton.icon(
              key: chave,
              onPressed: aoRemover,
              style: AceEstilo.botaoContorno.copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remover'),
            ),
        ],
      ),
    );
  }
}

class _NovoBloqueio extends StatefulWidget {
  const _NovoBloqueio({required this.repositorio, required this.hoje, this.aoSessaoExpirada});

  final BloqueiosRepositorio repositorio;
  final DateTime hoje;
  final VoidCallback? aoSessaoExpirada;

  @override
  State<_NovoBloqueio> createState() => _NovoBloqueioState();
}

class _NovoBloqueioState extends State<_NovoBloqueio> {
  List<Quadra>? _quadras;
  int? _quadraId;
  late DateTime _data = widget.hoje.add(const Duration(days: 1));
  HorariosBloqueaveis? _horarios;
  int? _hora;
  bool _buscando = false;
  bool _salvando = false;
  String? _erro;
  final _motivo = TextEditingController();

  /// Evita que uma resposta antiga (troca rápida de quadra/data) sobrescreva a nova.
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    try {
      final quadras = await widget.repositorio.quadrasAtivas();
      if (!mounted) return;
      setState(() {
        _quadras = quadras;
        _quadraId = quadras.isEmpty ? null : quadras.first.id;
      });
      await _buscarLivres();
    } on FalhaQuadra catch (f) {
      _mostrarFalha(f);
    }
  }

  Future<void> _buscarLivres() async {
    final quadraId = _quadraId;
    if (quadraId == null) return;
    final n = ++_consulta;
    setState(() {
      _buscando = true;
      _horarios = null;
      _hora = null;
      _erro = null;
    });
    try {
      final r = await widget.repositorio.livres(quadraId, _data);
      if (!mounted || n != _consulta) return;
      setState(() {
        _buscando = false;
        _horarios = r;
        _hora = r.livres.isEmpty ? null : r.livres.first;
      });
    } on FalhaQuadra catch (f) {
      if (n == _consulta) _mostrarFalha(f);
    }
  }

  void _mostrarFalha(FalhaQuadra f) {
    if (!mounted) return;
    setState(() {
      _buscando = false;
      _salvando = false;
      _erro = f.mensagem;
    });
    if (f.sessaoExpirada) widget.aoSessaoExpirada?.call();
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: widget.hoje,
      lastDate: widget.hoje.add(const Duration(days: 365)),
      helpText: 'Data do bloqueio',
    );
    if (escolhida == null || !mounted) return;
    setState(() => _data = escolhida);
    await _buscarLivres();
  }

  Future<void> _salvar() async {
    final quadraId = _quadraId, hora = _hora;
    if (quadraId == null || hora == null) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await widget.repositorio
          .bloquear(quadraId: quadraId, data: _data, hora: hora, motivo: _motivo.text);
      if (mounted) Navigator.of(context).pop(true);
    } on FalhaQuadra catch (f) {
      _mostrarFalha(f);
      // Alguém reservou ou bloqueou antes: atualizar as horas livres.
      if (f.codigo == 'HORARIO_RESERVADO' || f.codigo == 'JA_BLOQUEADO') {
        final erro = _erro;
        await _buscarLivres();
        if (mounted) setState(() => _erro = erro);
      }
    }
  }

  String get _ajuda {
    final h = _horarios;
    if (_buscando || h == null) return 'Buscando horários livres…';
    if (!h.aberta) return 'A quadra está fechada neste dia da semana.';
    if (h.livres.isEmpty) return 'Não há horários livres nesta data.';
    return h.livres.length == 1 ? '1 horário livre.' : '${h.livres.length} horários livres.';
  }

  @override
  Widget build(BuildContext context) {
    final quadras = _quadras;
    final livres = _horarios?.livres ?? const <int>[];
    final podeSalvar = !_salvando && !_buscando && _hora != null;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('NOVO BLOQUEIO', style: AceEstilo.tituloDialogo),
              const SizedBox(height: 16),
              if (_erro != null) AceAlerta(mensagem: _erro!),
              if (quadras == null && _erro == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: AceCores.verde)),
                )
              else if (quadras != null && quadras.isEmpty)
                const Text('Nenhuma quadra ativa para bloquear.',
                    style: TextStyle(color: AceCores.apagado))
              else if (quadras != null) ...[
                const AceRotulo('Quadra'),
                DropdownButtonFormField<int>(
                  key: const Key('bloqueio-quadra'),
                  initialValue: _quadraId,
                  decoration: AceEstilo.campo(),
                  borderRadius: BorderRadius.circular(16),
                  items: [
                    for (final q in quadras) DropdownMenuItem(value: q.id, child: Text(q.nome)),
                  ],
                  onChanged: _salvando
                      ? null
                      : (id) {
                          setState(() => _quadraId = id);
                          _buscarLivres();
                        },
                ),
                const SizedBox(height: 16),
                const AceRotulo('Data'),
                OutlinedButton(
                  key: const Key('bloqueio-data'),
                  onPressed: _salvando ? null : _escolherData,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    foregroundColor: AceCores.tinta,
                    side: const BorderSide(color: AceCores.linha, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(
                              '${dataBr(_data)} · ${nomesDias[diaSemanaDe(_data)]}')),
                      const Icon(Icons.calendar_today_outlined, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const AceRotulo('Hora (somente horários livres)'),
                DropdownButtonFormField<int>(
                  key: ValueKey('bloqueio-hora-$_quadraId-${dataIso(_data)}-${livres.length}'),
                  initialValue: _hora,
                  decoration: AceEstilo.campo(),
                  borderRadius: BorderRadius.circular(16),
                  hint: const Text('—'),
                  items: [
                    for (final h in livres)
                      DropdownMenuItem(
                          value: h,
                          child: Text('${Intervalo.textoDe(h)}–${Intervalo.textoDe(h + 1)}')),
                  ],
                  onChanged: (_salvando || livres.isEmpty) ? null : (h) => setState(() => _hora = h),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 6),
                  child: Text(_ajuda,
                      key: const Key('bloqueio-ajuda'),
                      style: const TextStyle(fontSize: 13, color: AceCores.apagado)),
                ),
                const SizedBox(height: 16),
                const AceRotulo('Motivo (opcional)'),
                TextField(
                  key: const Key('bloqueio-motivo'),
                  controller: _motivo,
                  maxLength: 60,
                  enabled: !_salvando,
                  decoration: AceEstilo.campo(hint: 'Ex.: Manutenção do piso'),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
                    style: AceEstilo.botaoContorno,
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    key: const Key('bloqueio-salvar'),
                    onPressed: podeSalvar ? _salvar : null,
                    style: AceEstilo.botaoPrimario,
                    child: _salvando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          )
                        : const Text('Bloquear horário'),
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
