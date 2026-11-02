import 'package:flutter/material.dart';

import '../models/quadra.dart';
import '../tema/ace_componentes.dart';
import '../tema/ace_cores.dart';
import 'quadras_repositorio.dart';

/// Cadastro e gestão de quadras (atividade 5.2 · H8 · RF12): listar, criar, editar e
/// inativar. Visual segue o protótipo Ace Saibro (tela "Quadras" da área admin).
class QuadrasPage extends StatefulWidget {
  const QuadrasPage({
    super.key,
    required this.repositorio,
    this.aoVoltar,
    this.aoSessaoExpirada,
  });

  final QuadrasRepositorio repositorio;

  /// Volta ao painel. Sem ele, usa `Navigator.maybePop`.
  final VoidCallback? aoVoltar;

  /// Chamado quando o banco recusa por falta de login (42501).
  final VoidCallback? aoSessaoExpirada;

  @override
  State<QuadrasPage> createState() => _QuadrasPageState();
}

class _QuadrasPageState extends State<QuadrasPage> {
  List<Quadra>? _quadras;
  FalhaQuadra? _falhaCarga;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _falhaCarga = null);
    try {
      final lista = await widget.repositorio.listar();
      if (mounted) setState(() => _quadras = lista);
    } on FalhaQuadra catch (f) {
      if (!mounted) return;
      setState(() => _falhaCarga = f);
      if (f.sessaoExpirada) widget.aoSessaoExpirada?.call();
    }
  }

  Future<void> _abrirFormulario([Quadra? quadra]) async {
    final salva = await showDialog<Quadra>(
      context: context,
      barrierColor: const Color(0x8C0A180C),
      builder: (_) => _FormularioQuadra(
        repositorio: widget.repositorio,
        quadra: quadra,
        aoSessaoExpirada: widget.aoSessaoExpirada,
      ),
    );
    if (salva == null || !mounted) return;
    setState(() {
      final lista = [...?_quadras];
      final i = lista.indexWhere((q) => q.id == salva.id);
      if (i >= 0) {
        lista[i] = salva;
      } else {
        lista.add(salva);
      }
      lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
      _quadras = lista;
    });
    _avisar(quadra == null
        ? 'Quadra criada. Agora cadastre os horários e os preços dela.'
        : 'Quadra atualizada.');
  }

  void _avisar(String texto) => aceAviso(context, texto);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: aceBarraAdmin(context, 'Quadras', aoVoltar: widget.aoVoltar),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('quadras-nova'),
        onPressed: _quadras == null ? null : () => _abrirFormulario(),
        backgroundColor: AceCores.bola,
        foregroundColor: AceCores.tinta,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.add, size: 26),
        label: const Text('NOVA QUADRA', style: AceEstilo.fab),
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
                    const Text('QUADRAS', style: AceEstilo.titulo),
                    const SizedBox(height: 10),
                    const Text(
                      'Cadastre, edite ou inative quadras. Quadras inativas não aparecem para os clientes.',
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
    final quadras = _quadras;
    if (quadras == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: AceCores.verde)),
        ),
      ];
    }
    if (quadras.isEmpty) return const [_Vazio()];
    return [
      for (final q in quadras)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _LinhaQuadra(quadra: q, aoEditar: () => _abrirFormulario(q)),
        ),
    ];
  }
}

class _LinhaQuadra extends StatelessWidget {
  const _LinhaQuadra({required this.quadra, required this.aoEditar});

  final Quadra quadra;
  final VoidCallback aoEditar;

  @override
  Widget build(BuildContext context) {
    final descricao = quadra.descricao;
    return Opacity(
      opacity: quadra.ativa ? 1 : .65,
      child: Container(
        key: Key('quadra-${quadra.id}'),
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
                color: quadra.tipoPiso.fundo,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.sports_tennis, color: quadra.tipoPiso.cor, size: 28),
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
                      Text(quadra.nome.toUpperCase(), style: AceEstilo.nomeQuadra),
                      AceChip(
                          texto: quadra.tipoPiso.rotulo,
                          fundo: quadra.tipoPiso.fundo,
                          cor: quadra.tipoPiso.cor),
                      quadra.ativa
                          ? const AceChip(
                              texto: 'Ativa', fundo: AceCores.verdeClaro, cor: AceCores.verde)
                          : const AceChip(
                              texto: 'Inativa', fundo: AceCores.cinzaClaro, cor: AceCores.cinza),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (descricao == null || descricao.isEmpty) ? 'Sem descrição' : descricao,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AceCores.apagado),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // No celular só o ícone, para sobrar espaço para o nome e os chips.
            MediaQuery.sizeOf(context).width < 480
                ? IconButton.filledTonal(
                    key: Key('quadra-editar-${quadra.id}'),
                    onPressed: aoEditar,
                    tooltip: 'Editar',
                    style: IconButton.styleFrom(
                        backgroundColor: AceCores.verdeClaro, foregroundColor: AceCores.verde),
                    icon: const Icon(Icons.edit, size: 20),
                  )
                : FilledButton.tonalIcon(
                    key: Key('quadra-editar-${quadra.id}'),
                    onPressed: aoEditar,
                    style: AceEstilo.botaoTonal,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Editar'),
                  ),
          ],
        ),
      ),
    );
  }
}

class _FormularioQuadra extends StatefulWidget {
  const _FormularioQuadra({required this.repositorio, this.quadra, this.aoSessaoExpirada});

  final QuadrasRepositorio repositorio;
  final Quadra? quadra;
  final VoidCallback? aoSessaoExpirada;

  @override
  State<_FormularioQuadra> createState() => _FormularioQuadraState();
}

class _FormularioQuadraState extends State<_FormularioQuadra> {
  late final _nome = TextEditingController(text: widget.quadra?.nome ?? '');
  late final _descricao = TextEditingController(text: widget.quadra?.descricao ?? '');
  late TipoPiso _piso = widget.quadra?.tipoPiso ?? TipoPiso.saibro;
  late bool _ativa = widget.quadra?.ativa ?? true;

  String? _erroNome;
  String? _erroGeral;
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    setState(() {
      _erroGeral = null;
      _erroNome = nome.isEmpty ? 'Informe o nome da quadra.' : null;
    });
    if (_erroNome != null) return;

    setState(() => _salvando = true);
    final dados = DadosQuadra(
      nome: nome,
      tipoPiso: _piso,
      descricao: _descricao.text,
      ativa: _ativa,
    );
    try {
      final quadra = widget.quadra;
      final salva = quadra == null
          ? await widget.repositorio.criar(dados)
          : await widget.repositorio.atualizar(quadra.id, dados);
      if (mounted) Navigator.of(context).pop(salva);
    } on FalhaQuadra catch (f) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        if (f.codigo == 'QUADRA_NOME_DUPLICADO') {
          _erroNome = f.mensagem;
        } else {
          _erroGeral = f.mensagem;
        }
      });
      if (f.sessaoExpirada) widget.aoSessaoExpirada?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.quadra != null;
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
              Text(editando ? 'EDITAR QUADRA' : 'NOVA QUADRA', style: AceEstilo.tituloDialogo),
              const SizedBox(height: 16),
              if (_erroGeral != null) AceAlerta(mensagem: _erroGeral!),
              const AceRotulo('Nome'),
              TextField(
                key: const Key('quadra-nome'),
                controller: _nome,
                autofocus: true,
                maxLength: 60,
                enabled: !_salvando,
                textInputAction: TextInputAction.next,
                decoration: AceEstilo.campo(hint: 'Ex.: Saibro 3', erro: _erroNome),
                onChanged: (_) {
                  if (_erroNome != null) setState(() => _erroNome = null);
                },
              ),
              const SizedBox(height: 8),
              const AceRotulo('Tipo de piso'),
              DropdownButtonFormField<TipoPiso>(
                key: const Key('quadra-piso'),
                initialValue: _piso,
                decoration: AceEstilo.campo(),
                borderRadius: BorderRadius.circular(16),
                items: [
                  for (final p in TipoPiso.values)
                    DropdownMenuItem(value: p, child: Text(p.rotulo)),
                ],
                onChanged: _salvando ? null : (p) => setState(() => _piso = p ?? _piso),
              ),
              const SizedBox(height: 16),
              const AceRotulo('Descrição'),
              TextField(
                key: const Key('quadra-descricao'),
                controller: _descricao,
                maxLength: 160,
                maxLines: 3,
                minLines: 2,
                enabled: !_salvando,
                decoration: AceEstilo.campo(hint: 'Cobertura, iluminação, observações…'),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Switch(
                    key: const Key('quadra-ativa'),
                    value: _ativa,
                    onChanged: _salvando ? null : (v) => setState(() => _ativa = v),
                    activeTrackColor: AceCores.verde,
                    activeThumbColor: AceCores.bola,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Quadra ativa (visível para os clientes)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              if (editando && widget.quadra!.ativa && !_ativa)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Só é possível inativar se não houver reservas futuras nesta quadra.',
                    style: TextStyle(fontSize: 13, color: AceCores.apagado),
                  ),
                ),
              const SizedBox(height: 20),
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
                    key: const Key('quadra-salvar'),
                    onPressed: _salvando ? null : _salvar,
                    style: AceEstilo.botaoPrimario,
                    child: _salvando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          )
                        : const Text('Salvar'),
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

class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        decoration: BoxDecoration(
          border: Border.all(color: AceCores.linha, width: 1.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          children: [
            Text('NENHUMA QUADRA',
                style: TextStyle(
                    fontSize: 40, fontWeight: FontWeight.w900, height: 1, color: AceCores.tinta)),
            SizedBox(height: 4),
            Text('Use “Nova quadra” para cadastrar a primeira.',
                textAlign: TextAlign.center, style: TextStyle(color: AceCores.apagado)),
          ],
        ),
      );
}

