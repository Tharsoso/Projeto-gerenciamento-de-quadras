import 'package:flutter/material.dart';

import '../models/quadra.dart';
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

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AceCores.tinta,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: AceCores.bola, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ]),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AceCores.verdeEscuro,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          tooltip: 'Voltar ao painel',
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.aoVoltar ?? () => Navigator.of(context).maybePop(),
        ),
        title: const Text('QUADRAS', style: _Estilo.barra),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('quadras-nova'),
        onPressed: _quadras == null ? null : () => _abrirFormulario(),
        backgroundColor: AceCores.bola,
        foregroundColor: AceCores.tinta,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.add, size: 26),
        label: const Text('NOVA QUADRA', style: _Estilo.fab),
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
                    const Text('QUADRAS', style: _Estilo.titulo),
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
        _Alerta(mensagem: falha.mensagem),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _carregar,
            style: _Estilo.botaoContorno,
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
                      Text(quadra.nome.toUpperCase(), style: _Estilo.nomeQuadra),
                      _Chip(
                          texto: quadra.tipoPiso.rotulo,
                          fundo: quadra.tipoPiso.fundo,
                          cor: quadra.tipoPiso.cor),
                      quadra.ativa
                          ? const _Chip(
                              texto: 'Ativa', fundo: AceCores.verdeClaro, cor: AceCores.verde)
                          : const _Chip(
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
                    style: _Estilo.botaoTonal,
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
              Text(editando ? 'EDITAR QUADRA' : 'NOVA QUADRA', style: _Estilo.tituloDialogo),
              const SizedBox(height: 16),
              if (_erroGeral != null) _Alerta(mensagem: _erroGeral!),
              const _Rotulo('Nome'),
              TextField(
                key: const Key('quadra-nome'),
                controller: _nome,
                autofocus: true,
                maxLength: 60,
                enabled: !_salvando,
                textInputAction: TextInputAction.next,
                decoration: _Estilo.campo(hint: 'Ex.: Saibro 3', erro: _erroNome),
                onChanged: (_) {
                  if (_erroNome != null) setState(() => _erroNome = null);
                },
              ),
              const SizedBox(height: 8),
              const _Rotulo('Tipo de piso'),
              DropdownButtonFormField<TipoPiso>(
                key: const Key('quadra-piso'),
                initialValue: _piso,
                decoration: _Estilo.campo(),
                borderRadius: BorderRadius.circular(16),
                items: [
                  for (final p in TipoPiso.values)
                    DropdownMenuItem(value: p, child: Text(p.rotulo)),
                ],
                onChanged: _salvando ? null : (p) => setState(() => _piso = p ?? _piso),
              ),
              const SizedBox(height: 16),
              const _Rotulo('Descrição'),
              TextField(
                key: const Key('quadra-descricao'),
                controller: _descricao,
                maxLength: 160,
                maxLines: 3,
                minLines: 2,
                enabled: !_salvando,
                decoration: _Estilo.campo(hint: 'Cobertura, iluminação, observações…'),
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
                    style: _Estilo.botaoContorno,
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    key: const Key('quadra-salvar'),
                    onPressed: _salvando ? null : _salvar,
                    style: _Estilo.botaoPrimario,
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

class _Chip extends StatelessWidget {
  const _Chip({required this.texto, required this.fundo, required this.cor});

  final String texto;
  final Color fundo;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(texto, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600)),
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
        padding: const EdgeInsets.only(left: 4, bottom: 7),
        child: Text(
          texto.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: .6,
              color: AceCores.apagado),
        ),
      );
}

class _Alerta extends StatelessWidget {
  const _Alerta({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: AceCores.vermelhoClaro, borderRadius: BorderRadius.circular(18)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFF8E1B1B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(mensagem,
                  style: const TextStyle(color: Color(0xFF8E1B1B), fontSize: 14.5)),
            ),
          ],
        ),
      );
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

/// Tipografia e botões do protótipo. A fonte "Big Shoulders Display" não está no app
/// (precisaria do pacote google_fonts); os títulos usam peso 900 em caixa alta.
abstract final class _Estilo {
  static const barra =
      TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 1, height: 1);
  static const titulo = TextStyle(
      fontSize: 64, fontWeight: FontWeight.w900, height: .9, color: AceCores.tinta);
  static const tituloDialogo = TextStyle(
      fontSize: 40, fontWeight: FontWeight.w900, height: .95, color: AceCores.tinta);
  static const nomeQuadra = TextStyle(
      fontSize: 22, fontWeight: FontWeight.w800, height: 1.1, color: AceCores.tinta);
  static const fab = TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.2);

  static final _pilula = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));

  static final botaoPrimario = FilledButton.styleFrom(
    backgroundColor: AceCores.verde,
    foregroundColor: Colors.white,
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    shape: _pilula,
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );
  static final botaoTonal = FilledButton.styleFrom(
    backgroundColor: AceCores.verdeClaro,
    foregroundColor: AceCores.verde,
    minimumSize: const Size(0, 38),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: _pilula,
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );
  static final botaoContorno = OutlinedButton.styleFrom(
    foregroundColor: AceCores.tinta,
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    side: const BorderSide(color: AceCores.linha, width: 1.5),
    shape: _pilula,
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );

  static InputDecoration campo({String? hint, String? erro}) {
    OutlineInputBorder borda(Color cor, [double largura = 1.5]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cor, width: largura));
    return InputDecoration(
      hintText: hint,
      errorText: erro,
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: borda(AceCores.linha),
      focusedBorder: borda(AceCores.verde, 2),
      errorBorder: borda(AceCores.vermelho),
      focusedErrorBorder: borda(AceCores.vermelho, 2),
      disabledBorder: borda(AceCores.linha),
    );
  }
}
