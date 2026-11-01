import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gqt/admin/quadras_page.dart';
import 'package:gqt/admin/quadras_repositorio.dart';
import 'package:gqt/models/quadra.dart';

/// Repositório em memória com as mesmas regras do gatilho `validar_quadra`.
class QuadrasFalsas implements QuadrasRepositorio {
  QuadrasFalsas(this.quadras, {this.comReservasFuturas = const {}});

  final List<Quadra> quadras;
  final Set<int> comReservasFuturas;
  int _proximoId = 100;

  void _validar(DadosQuadra d, {int? id}) {
    final nome = d.nome.trim().toLowerCase();
    if (quadras.any((q) => q.nome.trim().toLowerCase() == nome && q.id != id)) {
      throw const FalhaQuadra('Já existe uma quadra com este nome.',
          codigo: 'QUADRA_NOME_DUPLICADO');
    }
    final atual = id == null ? null : quadras.firstWhere((q) => q.id == id);
    if (atual != null && atual.ativa && !d.ativa && comReservasFuturas.contains(id)) {
      throw const FalhaQuadra(
          'Existe 1 reserva futura nesta quadra. Cancele-a antes de inativar.',
          codigo: 'QUADRA_COM_RESERVAS');
    }
  }

  Quadra _montar(int id, DadosQuadra d) {
    final m = d.toMap();
    return Quadra(
        id: id,
        nome: m['nome'],
        tipoPiso: d.tipoPiso,
        descricao: m['descricao'],
        ativa: d.ativa);
  }

  @override
  Future<List<Quadra>> listar() async => [...quadras];

  @override
  Future<Quadra> criar(DadosQuadra dados) async {
    _validar(dados);
    final q = _montar(_proximoId++, dados);
    quadras.add(q);
    return q;
  }

  @override
  Future<Quadra> atualizar(int id, DadosQuadra dados) async {
    _validar(dados, id: id);
    final q = _montar(id, dados);
    quadras[quadras.indexWhere((x) => x.id == id)] = q;
    return q;
  }
}

const saibro1 = Quadra(
    id: 1, nome: 'Saibro 1', tipoPiso: TipoPiso.saibro, descricao: 'Coberta', ativa: true);
const dura2 = Quadra(id: 2, nome: 'Dura 2', tipoPiso: TipoPiso.dura, descricao: null, ativa: false);

Future<QuadrasFalsas> abrir(WidgetTester tester, {Set<int> comReservas = const {}}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = QuadrasFalsas([saibro1, dura2], comReservasFuturas: comReservas);
  await tester.pumpWidget(MaterialApp(home: QuadrasPage(repositorio: repo)));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('lista ativas e inativas com piso e situação', (tester) async {
    await abrir(tester);

    expect(find.text('SAIBRO 1'), findsOneWidget);
    expect(find.text('DURA 2'), findsOneWidget);
    expect(find.text('Ativa'), findsOneWidget);
    expect(find.text('Inativa'), findsOneWidget);
    expect(find.text('Sem descrição'), findsOneWidget);
  });

  testWidgets('cria uma quadra nova (cenário principal)', (tester) async {
    final repo = await abrir(tester);

    await tester.tap(find.byKey(const Key('quadras-nova')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quadra-nome')), '  Grama 3 ');
    await tester.tap(find.byKey(const Key('quadra-piso')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grama').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quadra-salvar')));
    await tester.pumpAndSettle();

    expect(find.text('GRAMA 3'), findsOneWidget);
    expect(repo.quadras.last.nome, 'Grama 3');
    expect(repo.quadras.last.tipoPiso, TipoPiso.grama);
    expect(find.textContaining('Quadra criada'), findsOneWidget);
  });

  testWidgets('nome vazio não chega ao banco', (tester) async {
    final repo = await abrir(tester);

    await tester.tap(find.byKey(const Key('quadras-nova')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quadra-nome')), '   ');
    await tester.tap(find.byKey(const Key('quadra-salvar')));
    await tester.pumpAndSettle();

    expect(find.text('Informe o nome da quadra.'), findsOneWidget);
    expect(repo.quadras, hasLength(2));
  });

  testWidgets('nome duplicado mostra o erro no campo (H8 alt. 1)', (tester) async {
    await abrir(tester);

    await tester.tap(find.byKey(const Key('quadras-nova')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quadra-nome')), 'saibro 1');
    await tester.tap(find.byKey(const Key('quadra-salvar')));
    await tester.pumpAndSettle();

    expect(find.text('Já existe uma quadra com este nome.'), findsOneWidget);
    expect(find.text('NOVA QUADRA'), findsWidgets); // diálogo continua aberto
  });

  testWidgets('edita e inativa uma quadra', (tester) async {
    final repo = await abrir(tester);

    await tester.tap(find.byKey(const Key('quadra-editar-1')));
    await tester.pumpAndSettle();
    expect(find.text('EDITAR QUADRA'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quadra-ativa')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quadra-salvar')));
    await tester.pumpAndSettle();

    expect(repo.quadras.first.ativa, isFalse);
    expect(find.text('Inativa'), findsNWidgets(2));
    expect(find.text('Quadra atualizada.'), findsOneWidget);
  });

  testWidgets('não inativa com reservas futuras (H8 alt. 2)', (tester) async {
    final repo = await abrir(tester, comReservas: {1});

    await tester.tap(find.byKey(const Key('quadra-editar-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quadra-ativa')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quadra-salvar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cancele-a antes de inativar'), findsOneWidget);
    expect(repo.quadras.first.ativa, isTrue);
  });

  group('traduzirErro', () {
    test('usa message e hint do banco', () {
      final f = traduzirErro(const PostgrestException(
          message: 'Já existe uma quadra com este nome.', hint: 'QUADRA_NOME_DUPLICADO'));
      expect(f.codigo, 'QUADRA_NOME_DUPLICADO');
      expect(f.mensagem, 'Já existe uma quadra com este nome.');
    });

    test('índice único (corrida) vira nome duplicado', () {
      final f = traduzirErro(const PostgrestException(message: 'duplicate key', code: '23505'));
      expect(f.codigo, 'QUADRA_NOME_DUPLICADO');
    });

    test('sem permissão pede login de novo', () {
      final f = traduzirErro(const PostgrestException(message: 'rls', code: '42501'));
      expect(f.sessaoExpirada, isTrue);
    });
  });
}
