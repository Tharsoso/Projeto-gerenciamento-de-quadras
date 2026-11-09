import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:gqt/admin/agendamentos_repositorio.dart';
import 'package:gqt/admin/cancelamento.dart';
import 'package:gqt/app.dart';
import 'package:gqt/auth/autenticacao.dart';
import 'package:gqt/fuso.dart';
import 'package:gqt/models/agendamento.dart';
import 'package:gqt/models/quadra.dart';
import 'package:gqt/publico/reservas_repositorio.dart';



const saibro1 =
    Quadra(id: 1, nome: 'Saibro 1', tipoPiso: TipoPiso.saibro, descricao: null, ativa: true);

bool _mesmoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;


    implements ReservasRepositorio, AgendamentosRepositorio, CancelamentoRepositorio {
  final List<Agendamento> reservas = [];
  int _proximoId = 1;

  @override
  Future<ReservaConfirmada> criar({
    required HorarioEscolhido horario,
    required String nome,
    required String telefone,
  }) async {
    final hora = int.parse(horario.hora.substring(0, 2));
    final doDia = reservas.where((a) => !a.cancelada && _mesmoDia(a.data, horario.data));

    if (doDia.where((a) => a.telefone == telefone).length >= 2) {
      throw const FalhaReserva(
        'Limite de 2 horários por dia atingido para este telefone.',
        codigo: 'LIMITE_DIARIO',
      );
    }
    if (doDia.any((a) => a.quadraId == horario.quadraId && a.hora == hora)) {
      throw const FalhaReserva('Este horário acabou de ser reservado.', codigo: 'HORARIO_OCUPADO');
    }

    final id = _proximoId++;
    final valor = horario.valor ?? 0;
    reservas.add(Agendamento(
      id: id,
      quadraId: horario.quadraId,
      quadraNome: horario.quadra,
      data: horario.data,
      hora: hora,
      nome: nome,
      telefone: telefone,
      valor: valor,
      cancelada: false,
      anonimizada: false,
    ));
    return ReservaConfirmada(
      id: id,
      quadra: horario.quadra,
      data: horario.data,
      hora: horario.hora,
      valor: valor,
      nome: nome,
      telefone: telefone,
    );
  }

  @override
  Future<List<Quadra>> quadras() async => [saibro1];

  @override
  Future<List<Agendamento>> listar(FiltroAgendamentos filtro) async => [...reservas];

  @override
  Future<void> cancelar(int reservaId, {String? motivo}) async {
    final i = reservas.indexWhere((a) => a.id == reservaId);
    final a = reservas[i];
    final m = motivo?.trim();
    reservas[i] = Agendamento(
      id: a.id,
      quadraId: a.quadraId,
      quadraNome: a.quadraNome,
      data: a.data,
      hora: a.hora,
      nome: a.nome,
      telefone: a.telefone,
      valor: a.valor,
      cancelada: true,
      anonimizada: a.anonimizada,
      motivoCancelamento: (m == null || m.isEmpty) ? null : m,
    );
  }
}


class AuthFalsa extends ChangeNotifier implements Autenticacao {
  @override
  bool logado = false;

  @override
  Future<void> entrar({required String email, required String senha}) async {
    logado = true;
    notifyListeners();
  }

  @override
  Future<void> sair() async {
    logado = false;
    notifyListeners();
  }
}


HorarioEscolhido horarioEm(String hora, {int dias = 2}) {
  final n = agoraBrasilia();
  return HorarioEscolhido(
    quadraId: 1,
    quadra: 'Saibro 1',
    data: DateTime(n.year, n.month, n.day + dias),
    hora: hora,
    valor: 80,
  );
}

Future<void> abrir(WidgetTester tester, BancoFalso banco, AuthFalsa auth) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(App(
    auth: auth,
    reservas: banco,
    agendamentos: banco,
    cancelamento: banco,
  ));
  await tester.pump();
}


Future<void> irPara(WidgetTester tester, String rota, {Object? extra}) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(rota, extra: extra);
  await tester.pumpAndSettle();
}

Future<void> reservar(WidgetTester tester, HorarioEscolhido horario, String nome, String telefone) async {
  await irPara(tester, '/reserva', extra: horario);
  await tester.enterText(find.byKey(const Key('reserva-nome')), nome);
  await tester.enterText(find.byKey(const Key('reserva-telefone')), telefone);
  await tester.tap(find.byKey(const Key('reserva-confirmar')));
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, String chave) async {
  await tester.ensureVisible(find.byKey(Key(chave)));
  await tester.tap(find.byKey(Key(chave)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cliente reserva, o proprietário vê a reserva e a cancela (H2, H11, H3)', (tester) async {
    final banco = BancoFalso();
    await abrir(tester, banco, AuthFalsa());

   
    await reservar(tester, horarioEm('18:00'), 'Maria da Silva', '31999990000');
    expect(find.text('CÓDIGO R0001'), findsOneWidget);
    expect(banco.reservas.single.telefone, '31999990000');

   
    await irPara(tester, '/login');
    await tester.enterText(find.byKey(const Key('login-email')), 'proprietario@gqt.com');
    await tester.enterText(find.byKey(const Key('login-senha')), 'segredo');
    await tester.tap(find.byKey(const Key('login-entrar')));
    await tester.pumpAndSettle();
    expect(find.text('Painel do proprietário'), findsOneWidget);

    await tocar(tester, 'painel-reservas');
    expect(find.byKey(const Key('agendamento-1')), findsOneWidget);
    expect(find.text('R0001'), findsOneWidget);
    expect(find.text('Confirmada'), findsOneWidget);

   
    await tocar(tester, 'cancelar-1');
    await tester.enterText(find.byKey(const Key('cancelar-motivo')), 'Cliente avisou que não vem');
    await tocar(tester, 'cancelar-confirmar');

    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.text('Motivo: Cliente avisou que não vem'), findsOneWidget);
    expect(find.byKey(const Key('cancelar-1')), findsNothing);
    expect(banco.reservas.single.cancelada, isTrue);
  });

  testWidgets('dois clientes disputam o mesmo horário e o segundo é avisado (H2)', (tester) async {
    final banco = BancoFalso();
    await abrir(tester, banco, AuthFalsa());

    await reservar(tester, horarioEm('18:00'), 'Maria da Silva', '31999990000');
    expect(find.text('CÓDIGO R0001'), findsOneWidget);

    await reservar(tester, horarioEm('18:00'), 'João Pereira', '31988880000');

    expect(find.text('Ops! Esse horário acabou de ser reservado.'), findsOneWidget);
    expect(find.byKey(const Key('sucesso-codigo')), findsNothing);
    expect(banco.reservas.length, 1, reason: 'a segunda tentativa não criou reserva');
  });

  testWidgets('o mesmo telefone reserva 2 horários no dia e a 3ª é recusada (H10)', (tester) async {
    final banco = BancoFalso();
    await abrir(tester, banco, AuthFalsa());

    await reservar(tester, horarioEm('18:00'), 'Maria da Silva', '31999990000');
    expect(find.text('CÓDIGO R0001'), findsOneWidget);

    await reservar(tester, horarioEm('19:00'), 'Maria da Silva', '31999990000');
    expect(find.text('CÓDIGO R0002'), findsOneWidget);

    await reservar(tester, horarioEm('20:00'), 'Maria da Silva', '31999990000');

    expect(find.text('Limite de reservas atingido.'), findsOneWidget);
    expect(find.byKey(const Key('reserva-nome')), findsOneWidget, reason: 'continua no formulário');
    expect(banco.reservas.length, 2);
  });

  testWidgets('o proprietário cancela uma reserva e o telefone volta a poder reservar (H3, H10)', (tester) async {
    final banco = BancoFalso();
    final auth = AuthFalsa();
    await abrir(tester, banco, auth);

    await reservar(tester, horarioEm('18:00'), 'Maria da Silva', '31999990000');
    await reservar(tester, horarioEm('19:00'), 'Maria da Silva', '31999990000');

   
    await auth.entrar(email: 'proprietario@gqt.com', senha: 'segredo');
    await irPara(tester, '/admin/reservas');
    await tocar(tester, 'cancelar-1');
    await tocar(tester, 'cancelar-confirmar');
    expect(banco.reservas.first.cancelada, isTrue);

  
    await reservar(tester, horarioEm('20:00'), 'Maria da Silva', '31999990000');

    expect(find.text('CÓDIGO R0003'), findsOneWidget);
    expect(banco.reservas.length, 3);
  });
}
