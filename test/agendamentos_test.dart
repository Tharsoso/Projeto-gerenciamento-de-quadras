import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gqt/admin/agendamentos_page.dart';
import 'package:gqt/admin/agendamentos_repositorio.dart';
import 'package:gqt/admin/quadras_repositorio.dart';
import 'package:gqt/app.dart';
import 'package:gqt/auth/autenticacao.dart';
import 'package:gqt/models/agendamento.dart';
import 'package:gqt/models/quadra.dart';

final hoje = DateTime(2030, 1, 7); // segunda-feira

const saibro1 =
    Quadra(id: 1, nome: 'Saibro 1', tipoPiso: TipoPiso.saibro, descricao: null, ativa: true);
const grama =
    Quadra(id: 4, nome: 'Grama 1', tipoPiso: TipoPiso.grama, descricao: null, ativa: false);

Agendamento reserva(
  int id, {
  int quadraId = 1,
  DateTime? data,
  int hora = 18,
  String nome = 'Maria da Silva',
  String? telefone = '31999990000',
  bool cancelada = false,
  bool anonimizada = false,
  String? motivo,
}) =>
    Agendamento(
      id: id,
      quadraId: quadraId,
      quadraNome: quadraId == 1 ? 'Saibro 1' : 'Grama 1',
      data: data ?? hoje,
      hora: hora,
      nome: nome,
      telefone: telefone,
      valor: 80,
      cancelada: cancelada,
      anonimizada: anonimizada,
      motivoCancelamento: motivo,
    );

/// Repositório em memória que aplica os filtros como o banco.
class AgendamentosFalsos implements AgendamentosRepositorio {
  AgendamentosFalsos({List<Agendamento>? lista, this.falha}) : lista = lista ?? [];

  final List<Agendamento> lista;
  FalhaQuadra? falha;
  final filtros = <FiltroAgendamentos>[];

  @override
  Future<List<Quadra>> quadras() async => [grama, saibro1];

  @override
  Future<List<Agendamento>> listar(FiltroAgendamentos f) async {
    filtros.add(f);
    if (falha != null) throw falha!;
    final digitos = f.busca.replaceAll(RegExp(r'\D'), '');
    return lista
        .where((a) => !a.data.isBefore(f.inicio) && !a.data.isAfter(f.fim))
        .where((a) => f.quadraId == null || a.quadraId == f.quadraId)
        .where((a) => digitos.isNotEmpty
            ? (a.telefone ?? '').contains(digitos)
            : a.nome.toLowerCase().contains(f.busca.trim().toLowerCase()))
        .toList();
  }
}

Future<void> abrir(
  WidgetTester tester,
  AgendamentosFalsos repo, {
  VoidCallback? aoSessaoExpirada,
  AcoesAgendamento? acoes,
}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('pt', 'BR')],
    locale: const Locale('pt', 'BR'),
    home: AgendamentosPage(
      repositorio: repo,
      hoje: hoje,
      aoSessaoExpirada: aoSessaoExpirada,
      acoes: acoes,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lista confirmadas e canceladas do período (H11)', (tester) async {
    final repo = AgendamentosFalsos(lista: [
      reserva(1),
      reserva(2, hora: 19, cancelada: true, motivo: 'Chuva'),
    ]);
    await abrir(tester, repo);

    expect(find.byKey(const Key('agendamento-1')), findsOneWidget);
    expect(find.byKey(const Key('agendamento-2')), findsOneWidget);
    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.text('Motivo: Chuva'), findsOneWidget);
    expect(find.text('Maria da Silva · (31) 99999-0000'), findsNWidgets(2));
    expect(find.text('2 reserva(s) no período · 1 confirmada(s)'), findsOneWidget);
  });

  testWidgets('período inicial vai de 7 dias antes a 14 dias depois de hoje', (tester) async {
    final repo = AgendamentosFalsos();
    await abrir(tester, repo);

    expect(repo.filtros.single.inicio, DateTime(2029, 12, 31));
    expect(repo.filtros.single.fim, DateTime(2030, 1, 21));
    expect(find.text('31/12/2029'), findsOneWidget);
    expect(find.text('21/01/2030'), findsOneWidget);
  });

  testWidgets('filtra por quadra, incluindo as inativas', (tester) async {
    final repo = AgendamentosFalsos(lista: [reserva(1), reserva(2, quadraId: 4)]);
    await abrir(tester, repo);

    await tester.tap(find.byKey(const Key('agendamentos-quadra')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grama 1 (inativa)').last);
    await tester.pumpAndSettle();

    expect(repo.filtros.last.quadraId, 4);
    expect(find.byKey(const Key('agendamento-1')), findsNothing);
    expect(find.byKey(const Key('agendamento-2')), findsOneWidget);
  });

  testWidgets('busca por telefone espera parar de digitar', (tester) async {
    final repo = AgendamentosFalsos(lista: [
      reserva(1),
      reserva(2, nome: 'João Pedro', telefone: '21988887777'),
    ]);
    await abrir(tester, repo);

    await tester.enterText(find.byKey(const Key('agendamentos-busca')), '(21) 9888');
    await tester.pump(const Duration(milliseconds: 200));
    expect(repo.filtros, hasLength(1));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(repo.filtros, hasLength(2));
    expect(repo.filtros.last.busca, '(21) 9888');
    expect(find.byKey(const Key('agendamento-1')), findsNothing);
    expect(find.byKey(const Key('agendamento-2')), findsOneWidget);
  });

  testWidgets('dados anonimizados não mostram nome nem telefone (LGPD)', (tester) async {
    final repo = AgendamentosFalsos(lista: [
      reserva(1, nome: 'Cliente anonimizado', telefone: null, anonimizada: true),
    ]);
    await abrir(tester, repo);

    expect(find.text('Anonimizado (LGPD) · (••) •••••-••••'), findsOneWidget);
  });

  testWidgets('sem reservas mostra o aviso para ajustar os filtros', (tester) async {
    await abrir(tester, AgendamentosFalsos());

    expect(find.byKey(const Key('agendamentos-vazio')), findsOneWidget);
  });

  testWidgets('período invertido não consulta e avisa', (tester) async {
    final repo = AgendamentosFalsos();
    await abrir(tester, repo);

    await tester.tap(find.byKey(const Key('agendamentos-de')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '25/01/2030');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(repo.filtros, hasLength(1));
    expect(
      find.text('Período inválido: a data inicial precisa ser anterior ou igual à final.'),
      findsOneWidget,
    );
  });

  testWidgets('erro de conexão mostra a mensagem e deixa tentar de novo', (tester) async {
    final repo = AgendamentosFalsos(
      lista: [reserva(1)],
      falha: const FalhaQuadra('Não foi possível conectar.'),
    );
    await abrir(tester, repo);
    expect(find.text('Não foi possível conectar.'), findsOneWidget);

    repo.falha = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agendamento-1')), findsOneWidget);
  });

  testWidgets('sessão expirada manda para o login', (tester) async {
    var expirou = false;
    await abrir(
      tester,
      AgendamentosFalsos(falha: const FalhaQuadra('Sessão expirada.', sessaoExpirada: true)),
      aoSessaoExpirada: () => expirou = true,
    );

    expect(expirou, isTrue);
  });

  testWidgets('ações extras aparecem em cada reserva (encaixe da 5.5)', (tester) async {
    await abrir(
      tester,
      AgendamentosFalsos(lista: [reserva(1), reserva(2, hora: 19)]),
      acoes: (context, a, recarregar) =>
          TextButton(key: Key('acao-${a.id}'), onPressed: recarregar, child: const Text('Ação')),
    );

    expect(find.byKey(const Key('acao-1')), findsOneWidget);
    expect(find.byKey(const Key('acao-2')), findsOneWidget);
  });

  testWidgets('card Reservas do painel abre a consulta', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(App(
      auth: _Logado(),
      agendamentos: AgendamentosFalsos(lista: [reserva(1, data: DateTime.now())]),
    ));
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/admin');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('painel-reservas')));
    await tester.pumpAndSettle();

    expect(find.text('RESERVAS'), findsWidgets);
    expect(find.byKey(const Key('agendamento-1')), findsOneWidget);
  });

  testWidgets('cabe na tela de um celular sem estourar', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: AgendamentosPage(
        repositorio: AgendamentosFalsos(lista: [
          reserva(1, nome: 'Maria Aparecida dos Santos Oliveira'),
          reserva(2, cancelada: true, motivo: 'Cliente avisou que não poderá comparecer'),
        ]),
        hoje: hoje,
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('agendamento-1')), findsOneWidget);
  });

  test('erro de permissão do banco vira sessão expirada', () {
    final f = traduzirErroAgendamentos(const PostgrestException(message: 'denied', code: '42501'));

    expect(f.sessaoExpirada, isTrue);
  });
}

class _Logado extends ChangeNotifier implements Autenticacao {
  @override
  bool get logado => true;

  @override
  Future<void> entrar({required String email, required String senha}) async {}

  @override
  Future<void> sair() async {}
}
