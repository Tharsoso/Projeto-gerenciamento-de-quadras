import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gqt/admin/feriados_page.dart';
import 'package:gqt/admin/feriados_repositorio.dart';
import 'package:gqt/admin/quadras_repositorio.dart';
import 'package:gqt/models/bloqueio.dart' show dataIso;

final hoje = DateTime(2030, 9, 2); // segunda-feira

/// Repositório em memória com a chave primária (`data`) da tabela `feriados`.
class FeriadosFalsos implements FeriadosRepositorio {
  FeriadosFalsos([List<Feriado>? inicial]) : lista = inicial ?? [];

  final List<Feriado> lista;

  @override
  Future<List<Feriado>> listar() async =>
      [...lista]..sort((a, b) => a.data.compareTo(b.data));

  @override
  Future<void> adicionar(DateTime data, String descricao) async {
    if (lista.any((f) => dataIso(f.data) == dataIso(data))) {
      throw const FalhaQuadra('Já existe um feriado nesta data.', codigo: 'FERIADO_DUPLICADO');
    }
    lista.add(Feriado(data: data, descricao: descricao.trim()));
  }

  @override
  Future<void> remover(DateTime data) async =>
      lista.removeWhere((f) => dataIso(f.data) == dataIso(data));
}

Future<FeriadosFalsos> abrir(WidgetTester tester, FeriadosFalsos repo,
    {Size tamanho = const Size(1200, 1600)}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: FeriadosPage(repositorio: repo, hoje: hoje)));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> tocar(WidgetTester tester, String chave) async {
  await tester.tap(find.byKey(Key(chave)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ano sem feriado mostra o convite', (tester) async {
    await abrir(tester, FeriadosFalsos());
    expect(find.text('SEM FERIADOS EM 2030'), findsOneWidget);
    expect(find.byKey(const Key('feriados-ano-2031')), findsOneWidget);
  });

  testWidgets('lista do ano com dia da semana e aviso de preço em dia útil', (tester) async {
    await abrir(
      tester,
      FeriadosFalsos([
        Feriado(data: DateTime(2030, 9, 7), descricao: 'Independência'), // sábado
        Feriado(data: DateTime(2030, 11, 15), descricao: 'Proclamação da República'), // sexta
        Feriado(data: DateTime(2031, 1, 1), descricao: 'Confraternização'),
      ]),
    );

    expect(find.text('Independência'), findsOneWidget);
    expect(find.text('07/09/2030 · Sábado'), findsOneWidget);
    expect(find.text('15/11/2030 · Sexta · preço de fim de semana'), findsOneWidget);
    expect(find.text('Confraternização'), findsNothing);

    await tocar(tester, 'feriados-ano-2031');
    expect(find.text('Confraternização'), findsOneWidget);
    expect(find.text('Independência'), findsNothing);
  });

  testWidgets('cadastra feriado (H4 alt. 3)', (tester) async {
    final repo = await abrir(tester, FeriadosFalsos());

    await tocar(tester, 'feriados-novo');
    expect(find.text('02/09/2030 · Segunda'), findsOneWidget); // começa em hoje
    await tester.enterText(find.byKey(const Key('feriado-descricao')), ' Aniversário da cidade ');
    await tocar(tester, 'feriado-salvar');

    expect(repo.lista.single.descricao, 'Aniversário da cidade');
    expect(dataIso(repo.lista.single.data), '2030-09-02');
    expect(find.text('Feriado cadastrado. Vale o preço de fim de semana nesse dia.'),
        findsOneWidget);
    expect(find.text('02/09/2030 · Segunda · preço de fim de semana'), findsOneWidget);
  });

  testWidgets('descrição curta e data repetida não salvam', (tester) async {
    final repo = await abrir(
        tester, FeriadosFalsos([Feriado(data: hoje, descricao: 'Feriado municipal')]));

    await tocar(tester, 'feriados-novo');
    await tester.enterText(find.byKey(const Key('feriado-descricao')), 'ab');
    await tocar(tester, 'feriado-salvar');

    expect(find.text('Informe a descrição (mínimo de 3 letras).'), findsOneWidget);
    expect(find.text('Já existe um feriado nesta data.'), findsOneWidget);
    expect(repo.lista, hasLength(1));
    expect(find.text('NOVO FERIADO'), findsWidgets); // diálogo continua aberto
  });

  testWidgets('remover tira da lista', (tester) async {
    final repo = await abrir(
        tester, FeriadosFalsos([Feriado(data: DateTime(2030, 10, 12), descricao: 'Padroeira')]));

    await tocar(tester, 'feriado-remover-2030-10-12');

    expect(repo.lista, isEmpty);
    expect(find.text('SEM FERIADOS EM 2030'), findsOneWidget);
  });

  testWidgets('cabe em celular (360px), lista e diálogo', (tester) async {
    await abrir(
      tester,
      FeriadosFalsos([
        Feriado(
            data: DateTime(2030, 11, 20),
            descricao: 'Dia Nacional de Zumbi e da Consciência Negra'),
      ]),
      tamanho: const Size(360, 740),
    );
    expect(tester.takeException(), isNull, reason: 'lista');
    await tocar(tester, 'feriados-novo');
    expect(tester.takeException(), isNull, reason: 'diálogo');
  });

  group('traduzirErroFeriado', () {
    test('chave primária = data repetida', () {
      final f = traduzirErroFeriado(const PostgrestException(message: 'dup', code: '23505'));
      expect(f.codigo, 'FERIADO_DUPLICADO');
    });

    test('sem permissão = sessão expirada', () {
      final f = traduzirErroFeriado(const PostgrestException(message: 'rls', code: '42501'));
      expect(f.sessaoExpirada, isTrue);
    });
  });
}
