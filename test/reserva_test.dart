import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gqt/app.dart';
import 'package:gqt/auth/autenticacao.dart';
import 'package:gqt/formatos.dart';
import 'package:gqt/publico/reservas_repositorio.dart';

class AutenticacaoFalsa extends ChangeNotifier implements Autenticacao {
  @override
  bool get logado => false;

  @override
  Future<void> entrar({required String email, required String senha}) async {}

  @override
  Future<void> sair() async {}
}

class RepositorioFalso implements ReservasRepositorio {
  FalhaReserva? falha;
  Completer<void>? segurar;
  int chamadas = 0;
  String? nomeRecebido;
  String? telefoneRecebido;

  @override
  Future<ReservaConfirmada> criar({
    required HorarioEscolhido horario,
    required String nome,
    required String telefone,
  }) async {
    chamadas++;
    nomeRecebido = nome;
    telefoneRecebido = telefone;
    await segurar?.future;
    if (falha != null) throw falha!;
    return ReservaConfirmada(
      id: 42,
      quadra: horario.quadra,
      data: horario.data,
      hora: horario.hora,
      valor: 80,
      nome: nome,
      telefone: telefone,
    );
  }
}

final horario = HorarioEscolhido(
  quadraId: 1,
  quadra: 'Saibro 1',
  data: DateTime(2026, 11, 10),
  hora: '18:00',
  valor: 80,
);

Future<void> abrir(WidgetTester tester, RepositorioFalso repo, {Object? extra}) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(App(auth: AutenticacaoFalsa(), reservas: repo));
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/reserva', extra: extra ?? horario);
  await tester.pumpAndSettle();
}

Future<void> preencher(WidgetTester tester, String nome, String telefone) async {
  await tester.enterText(find.byKey(const Key('reserva-nome')), nome);
  await tester.enterText(find.byKey(const Key('reserva-telefone')), telefone);
}

Future<void> confirmar(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('reserva-confirmar')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dados válidos reservam e abrem a confirmação (H1)', (tester) async {
    final repo = RepositorioFalso();
    await abrir(tester, repo);

    await preencher(tester, '  Maria   da Silva ', '31999990000');
    await confirmar(tester);

    expect(repo.nomeRecebido, 'Maria da Silva');
    expect(repo.telefoneRecebido, '31999990000');
    expect(find.text('CÓDIGO R0042'), findsOneWidget);
    expect(find.text('(31) 99999-0000'), findsOneWidget);
    expect(find.text('R\$ 80,00'), findsOneWidget);
  });

  testWidgets('nome curto e telefone inválido não chegam ao banco', (tester) async {
    final repo = RepositorioFalso();
    await abrir(tester, repo);

    await preencher(tester, 'Jo', '3199999');
    await confirmar(tester);

    expect(repo.chamadas, 0);
    expect(find.text('Digite seu nome completo (mínimo de 3 letras).'), findsOneWidget);
    expect(
      find.text('Telefone inválido. Use DDD + 9 + 8 dígitos, ex.: (31) 99999-0000.'),
      findsOneWidget,
    );
  });

  testWidgets('telefone recebe a máscara ao digitar', (tester) async {
    await abrir(tester, RepositorioFalso());

    await preencher(tester, 'Maria', '31999990000');

    final campo = tester.widget<TextFormField>(find.byKey(const Key('reserva-telefone')));
    expect(campo.controller!.text, '(31) 99999-0000');
  });

  testWidgets('limite de 2 por dia avisa e continua no formulário (4.3)', (tester) async {
    final repo = RepositorioFalso()
      ..falha = const FalhaReserva(
        'Limite de 2 horários por dia atingido para este telefone.',
        codigo: 'LIMITE_DIARIO',
      );
    await abrir(tester, repo);

    await preencher(tester, 'Maria da Silva', '31999990000');
    await confirmar(tester);

    expect(find.text('Limite de reservas atingido.'), findsOneWidget);
    expect(find.byKey(const Key('reserva-nome')), findsOneWidget);
    expect(find.byKey(const Key('sucesso-codigo')), findsNothing);
  });

  testWidgets('horário tomado por outro cliente avisa para escolher outro', (tester) async {
    final repo = RepositorioFalso()
      ..falha = const FalhaReserva(
        'Este horário acabou de ser reservado.',
        codigo: 'HORARIO_OCUPADO',
      );
    await abrir(tester, repo);

    await preencher(tester, 'Maria da Silva', '31999990000');
    await confirmar(tester);

    expect(find.text('Ops! Esse horário acabou de ser reservado.'), findsOneWidget);
  });

  testWidgets('sem conexão mostra a mensagem e deixa tentar de novo', (tester) async {
    final repo = RepositorioFalso()
      ..falha = const FalhaReserva('Não foi possível conectar.');
    await abrir(tester, repo);

    await preencher(tester, 'Maria da Silva', '31999990000');
    await confirmar(tester);
    expect(find.text('Não foi possível conectar.'), findsOneWidget);

    repo.falha = null;
    await confirmar(tester);

    expect(repo.chamadas, 2);
    expect(find.text('CÓDIGO R0042'), findsOneWidget);
  });

  testWidgets('dois toques seguidos só criam uma reserva', (tester) async {
    final repo = RepositorioFalso()..segurar = Completer<void>();
    await abrir(tester, repo);

    await preencher(tester, 'Maria da Silva', '31999990000');
    await tester.tap(find.byKey(const Key('reserva-confirmar')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reserva-confirmar')), warnIfMissed: false);
    await tester.pump();

    expect(repo.chamadas, 1);
    expect(find.text('RESERVANDO…'), findsOneWidget);

    repo.segurar!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('abrir /reserva sem horário escolhido volta para a home', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(App(auth: AutenticacaoFalsa(), reservas: RepositorioFalso()));
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/reserva');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('reserva-nome')), findsNothing);
  });

  test('traduzirErroReserva usa message e hint do banco', () {
    final f = traduzirErroReserva(const PostgrestException(
      message: 'Limite de 2 horários por dia atingido para este telefone.',
      code: 'P0001',
      hint: 'LIMITE_DIARIO',
    ));

    expect(f.codigo, 'LIMITE_DIARIO');
    expect(f.mensagem, 'Limite de 2 horários por dia atingido para este telefone.');
  });

  test('traduzirErroReserva sem hint não mostra erro técnico', () {
    final f = traduzirErroReserva(const PostgrestException(message: 'relation x does not exist'));

    expect(f.codigo, isNull);
    expect(f.mensagem, 'Não foi possível concluir a reserva. Tente novamente.');
  });

  test('formatos brasileiros', () {
    expect(formatarReal(60), 'R\$ 60,00');
    expect(formatarData(DateTime(2026, 3, 5)), '05/03/2026');
    expect(mascararTelefone('31999990000'), '(31) 99999-0000');
  });

  testWidgets('a tela de reserva diz para que servem os dados e por quanto tempo (LGPD, L1)',
      (tester) async {
    await abrir(tester, RepositorioFalso());

    final aviso = find.byKey(const Key('reserva-aviso-lgpd'));
    expect(aviso, findsOneWidget);
    final texto = tester.widget<Text>(find.descendant(of: aviso, matching: find.byType(Text)));
    expect(texto.data, contains('identificar a reserva'));
    expect(texto.data, contains('12 meses depois da data da reserva'));
  });
}
