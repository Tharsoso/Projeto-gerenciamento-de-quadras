import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gqt/admin/horarios_page.dart';
import 'package:gqt/admin/horarios_repositorio.dart';
import 'package:gqt/admin/quadras_repositorio.dart';
import 'package:gqt/models/funcionamento.dart';
import 'package:gqt/models/quadra.dart';

/// Repositório em memória. Guarda o que a tela gravou para os testes conferirem.
class HorariosFalsos implements HorariosRepositorio {
  HorariosFalsos({
    required this.lista,
    required this.semanas,
    this.reservas = const [],
    this.falharAoSalvar,
  });

  final List<Quadra> lista;
  final Map<int, Semana> semanas;
  final List<ReservaFutura> reservas;
  final FalhaQuadra? falharAoSalvar;
  final List<int> salvas = [];

  @override
  Future<List<Quadra>> quadras() async => lista;

  @override
  Future<Map<int, Semana>> funcionamento() async =>
      {for (final e in semanas.entries) e.key: Map.of(e.value)};

  @override
  Future<List<ReservaFutura>> reservasFuturas(Set<int> quadraIds) async =>
      reservas.where((r) => quadraIds.contains(r.quadraId)).toList();

  @override
  Future<void> salvar(int quadraId, Semana semana) async {
    final f = falharAoSalvar;
    if (f != null) throw f;
    semanas[quadraId] = Map.of(semana);
    salvas.add(quadraId);
  }
}

const saibro1 =
    Quadra(id: 1, nome: 'Saibro 1', tipoPiso: TipoPiso.saibro, descricao: null, ativa: true);
const nova = Quadra(id: 2, nome: 'Nova', tipoPiso: TipoPiso.grama, descricao: null, ativa: true);

Semana semanaPadrao() => {for (var d = 0; d < 7; d++) d: const Intervalo(7, 22)};

Future<HorariosFalsos> abrir(WidgetTester tester, HorariosFalsos repo) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: HorariosPage(repositorio: repo)));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> escolherHora(WidgetTester tester, String chave, String hora) async {
  await tester.ensureVisible(find.byKey(Key(chave)));
  await tester.tap(find.byKey(Key(chave)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(hora).last);
  await tester.pumpAndSettle();
}

Future<void> salvar(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('horarios-salvar')));
  await tester.tap(find.byKey(const Key('horarios-salvar')));
  await tester.pumpAndSettle();
}

void main() {
  group('reservasForaDoHorario (H9 alternativo)', () {
    final sabado = DateTime(2026, 11, 7); // sábado = 6
    final segunda = DateTime(2026, 11, 9); // segunda = 1
    final reservas = [
      ReservaFutura(quadraId: 1, data: sabado, hora: 20, nomeCliente: 'Ana'),
      ReservaFutura(quadraId: 1, data: segunda, hora: 8, nomeCliente: 'Bruno'),
      ReservaFutura(quadraId: 3, data: sabado, hora: 21, nomeCliente: 'Caio'),
    ];

    test('aponta só as reservas que saem do novo intervalo', () {
      final novo = {1: {...semanaPadrao(), 6: const Intervalo(8, 18)}};
      final fora = reservasForaDoHorario(reservas, novo);
      expect(fora.map((r) => r.nomeCliente), ['Ana']);
    });

    test('dia fechado conta como fora; quadra não alterada é ignorada', () {
      final novo = {1: semanaPadrao()..remove(1)};
      final fora = reservasForaDoHorario(reservas, novo);
      expect(fora.map((r) => r.nomeCliente), ['Bruno']);
    });

    test('fechamento é exclusivo: reserva às 22h fica fora de 07h–22h', () {
      final r = [ReservaFutura(quadraId: 1, data: segunda, hora: 22, nomeCliente: 'Davi')];
      expect(reservasForaDoHorario(r, {1: semanaPadrao()}), hasLength(1));
    });

    test('diaSemanaDe segue o extract(dow) do banco', () {
      expect(diaSemanaDe(DateTime(2026, 11, 8)), 0); // domingo
      expect(diaSemanaDe(segunda), 1);
      expect(diaSemanaDe(sabado), 6);
    });
  });

  testWidgets('mostra o horário gravado e avisa quadra sem horário', (tester) async {
    await abrir(
        tester, HorariosFalsos(lista: [saibro1, nova], semanas: {1: semanaPadrao()}));

    expect(find.text('SAIBRO 1'), findsOneWidget);
    expect(find.textContaining('Sem horário cadastrado'), findsOneWidget);
    expect(find.text('NADA PARA SALVAR'), findsOneWidget);
  });

  testWidgets('altera o sábado e salva só a quadra alterada (cenário principal)', (tester) async {
    final repo = await abrir(
        tester, HorariosFalsos(lista: [saibro1, nova], semanas: {1: semanaPadrao()}));

    await escolherHora(tester, 'dia-1-6-fecha', '18:00');
    expect(find.text('SALVAR (1 QUADRA ALTERADA)'), findsOneWidget);
    await salvar(tester);

    expect(repo.salvas, [1]);
    expect(repo.semanas[1]![6], const Intervalo(7, 18));
    expect(repo.semanas[1]![5], const Intervalo(7, 22));
    expect(find.text('Horários de funcionamento salvos.'), findsOneWidget);
  });

  testWidgets('fechar um dia tira ele da semana gravada', (tester) async {
    final repo =
        await abrir(tester, HorariosFalsos(lista: [saibro1], semanas: {1: semanaPadrao()}));

    await tester.ensureVisible(find.byKey(const Key('dia-1-0-aberto')));
    await tester.tap(find.byKey(const Key('dia-1-0-aberto')));
    await tester.pumpAndSettle();
    expect(find.text('Fechado o dia todo'), findsOneWidget);
    await salvar(tester);

    expect(repo.semanas[1]!.containsKey(0), isFalse);
    expect(repo.semanas[1], hasLength(6));
  });

  testWidgets('fechamento antes da abertura bloqueia o salvar', (tester) async {
    final repo =
        await abrir(tester, HorariosFalsos(lista: [saibro1], semanas: {1: semanaPadrao()}));

    await escolherHora(tester, 'dia-1-1-fecha', '06:00');

    expect(find.text('O fechamento precisa ser depois da abertura.'), findsOneWidget);
    final botao = tester.widget<FilledButton>(find.byKey(const Key('horarios-salvar')));
    expect(botao.onPressed, isNull);
    expect(repo.salvas, isEmpty);
  });

  testWidgets('reduzir com reserva futura avisa e mantém se confirmar (H9 alt.)',
      (tester) async {
    final repo = await abrir(
      tester,
      HorariosFalsos(
        lista: [saibro1],
        semanas: {1: semanaPadrao()},
        reservas: [
          ReservaFutura(quadraId: 1, data: DateTime(2030, 1, 5), hora: 20, nomeCliente: 'Ana'),
        ],
      ),
    );

    await escolherHora(tester, 'dia-1-6-fecha', '18:00'); // 05/01/2030 é sábado
    await salvar(tester);

    expect(find.text('Existe 1 reserva futura fora do novo horário.'), findsOneWidget);
    expect(find.textContaining('Saibro 1 · sáb 05/01 · 20:00 · Ana'), findsOneWidget);
    await tester.tap(find.byKey(const Key('impacto-confirmar')));
    await tester.pumpAndSettle();

    expect(repo.salvas, [1]);
  });

  testWidgets('desistir no aviso de impacto não grava nada', (tester) async {
    final repo = await abrir(
      tester,
      HorariosFalsos(
        lista: [saibro1],
        semanas: {1: semanaPadrao()},
        reservas: [
          ReservaFutura(quadraId: 1, data: DateTime(2030, 1, 5), hora: 20, nomeCliente: 'Ana'),
        ],
      ),
    );

    await escolherHora(tester, 'dia-1-6-fecha', '18:00');
    await salvar(tester);
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    expect(repo.salvas, isEmpty);
    expect(find.text('SALVAR (1 QUADRA ALTERADA)'), findsOneWidget);
  });

  testWidgets('erro do banco aparece no aviso', (tester) async {
    await abrir(
      tester,
      HorariosFalsos(
        lista: [saibro1],
        semanas: {1: semanaPadrao()},
        falharAoSalvar:
            const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true),
      ),
    );

    await escolherHora(tester, 'dia-1-6-fecha', '18:00');
    await salvar(tester);

    expect(find.text('Sua sessão expirou. Entre novamente.'), findsOneWidget);
  });

  testWidgets('cabe em celular (360px) sem estourar', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: HorariosPage(
            repositorio: HorariosFalsos(lista: [saibro1], semanas: {1: semanaPadrao()}))));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
