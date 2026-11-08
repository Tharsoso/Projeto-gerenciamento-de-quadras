import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import 'package:gqt/fuso.dart';
import 'package:gqt/models/horario_slot.dart';
import 'package:gqt/publico/reservas_repositorio.dart';
import 'package:gqt/screens/public/consulta_horarios_screen.dart';
import 'package:gqt/services/quadras_service.dart';

/// Testes da home pública (atividade 6.2): consulta de quadras e horários (H1).
///
/// A tela recebe o serviço pelo parâmetro `servico`. Aqui ele é trocado por um falso, que
/// devolve os horários que cada teste quer e anota que dias foram pedidos.
///
/// A home tem animações que nunca terminam, então não se usa `pumpAndSettle()`: só `pump()`.
class QuadrasServiceFalso extends Fake implements QuadrasService {
  QuadrasServiceFalso(this.responder);

  /// Decide o que `horariosDoDia` devolve (ou lança, para simular uma falha).
  Future<List<HorarioSlot>> Function(DateTime dia) responder;

  /// Dias pedidos ao serviço, na ordem.
  final List<DateTime> pedidos = [];

  /// Função que a tela entrega para ser chamada quando o Realtime avisa uma mudança.
  void Function()? aoMudar;

  @override
  Future<List<HorarioSlot>> horariosDoDia(DateTime data) {
    pedidos.add(data);
    return responder(data);
  }

  @override
  RealtimeChannel? assinarOcupacoes(void Function() onChange) {
    aoMudar = onChange;
    return null;
  }
}

HorarioSlot slot(
  String quadra,
  String hora, {
  String status = 'livre',
  double? valor = 60,
  int quadraId = 1,
  String piso = 'saibro',
}) =>
    HorarioSlot(
      quadraId: quadraId,
      quadraNome: quadra,
      tipoPiso: piso,
      horaInicio: hora,
      valor: valor,
      status: status,
    );

DateTime hoje() {
  final n = agoraBrasilia();
  return DateTime(n.year, n.month, n.day);
}

bool mesmoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

Future<void> avancar(WidgetTester tester, [int ms = 100]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

/// Toca no botão (InkWell) que tem esse texto, como a hora de um horário ou uma seta.
Future<void> tocar(WidgetTester tester, String texto) async {
  await tester.tap(find.widgetWithText(InkWell, texto));
  await avancar(tester);
}

/// Abre a home com um roteador mínimo: `/reserva` e `/login` são telas de mentira que só
/// mostram o que receberam, para conferir para onde a home levou.
Future<void> abrir(WidgetTester tester, QuadrasServiceFalso servico) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (context, state) => ConsultaHorariosScreen(servico: servico)),
    GoRoute(
      path: '/reserva',
      builder: (context, state) {
        final h = state.extra! as HorarioEscolhido;
        return Scaffold(
          body: Text(
            'RESERVA|${h.quadraId}|${h.quadra}|${h.hora}|${h.valor}|${h.data.year}-${h.data.month}-${h.data.day}',
            key: const Key('reserva-stub'),
          ),
        );
      },
    ),
    GoRoute(path: '/login', builder: (context, state) => const Scaffold(body: Text('LOGIN'))),
  ]);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await avancar(tester);
}

void main() {
  testWidgets('mostra as quadras do dia com os horários e os preços (CT-H1-01)', (tester) async {
    final servico = QuadrasServiceFalso((dia) async => [
          slot('Saibro 1', '07:00'),
          slot('Saibro 1', '08:00'),
          slot('Saibro 1', '09:00', status: 'reservado'),
          slot('Rápida 1', '10:00', quadraId: 2, piso: 'dura', valor: 100),
        ]);

    await abrir(tester, servico);

    expect(mesmoDia(servico.pedidos.first, hoje()), isTrue, reason: 'a consulta abre em hoje');
    expect(find.text('SAIBRO 1'), findsOneWidget);
    expect(find.text('RÁPIDA 1'), findsOneWidget);
    expect(find.widgetWithText(InkWell, '07:00'), findsOneWidget);
    expect(find.widgetWithText(InkWell, '10:00'), findsOneWidget);
    expect(find.text('R\$ 60,00'), findsNWidgets(2));
    expect(find.text('R\$ 100,00'), findsOneWidget);
  });

  testWidgets('horário reservado, bloqueado e passado não abrem a reserva (CT-H1-04)', (tester) async {
    final servico = QuadrasServiceFalso((dia) async => [
          slot('Saibro 1', '09:00', status: 'reservado'),
          slot('Saibro 1', '10:00', status: 'bloqueado'),
          slot('Saibro 1', '11:00', status: 'passado'),
          slot('Saibro 1', '12:00'),
        ]);
    await abrir(tester, servico);

    for (final hora in ['09:00', '10:00', '11:00']) {
      await tocar(tester, hora);
      expect(find.byKey(const Key('reserva-stub')), findsNothing, reason: '$hora não é livre');
    }

    await tocar(tester, '12:00');
    await avancar(tester, 500);
    expect(find.byKey(const Key('reserva-stub')), findsOneWidget, reason: '12:00 é livre');
  });

  testWidgets('tocar em um horário livre abre a reserva com os dados escolhidos (CT-H1-06)', (tester) async {
    final servico = QuadrasServiceFalso((dia) async => [
          slot('Saibro 1', '18:00', quadraId: 7, valor: 90),
        ]);
    await abrir(tester, servico);

    await tocar(tester, '18:00');
    await avancar(tester, 500);

    final h = hoje();
    final stub = tester.widget<Text>(find.byKey(const Key('reserva-stub')));
    expect(stub.data, 'RESERVA|7|Saibro 1|18:00|90.0|${h.year}-${h.month}-${h.day}');
  });

  testWidgets('a seta ‹ não volta para antes de hoje e a seta › avança o dia (CT-H1-02)', (tester) async {
    final servico = QuadrasServiceFalso((dia) async => [slot('Saibro 1', '18:00')]);
    await abrir(tester, servico);
    expect(servico.pedidos.length, 1);

    await tocar(tester, '‹');
    expect(servico.pedidos.length, 1, reason: 'em hoje, voltar não consulta nada');

    await tocar(tester, '›');
    expect(servico.pedidos.length, 2);
    expect(mesmoDia(servico.pedidos.last, hoje().add(const Duration(days: 1))), isTrue);

    await tocar(tester, '‹');
    expect(servico.pedidos.length, 3);
    expect(mesmoDia(servico.pedidos.last, hoje()), isTrue, reason: 'voltou para hoje, e não para antes');
  });

  testWidgets('o botão HOJE volta para o dia de hoje (CT-H1-10)', (tester) async {
    final servico = QuadrasServiceFalso((dia) async => [slot('Saibro 1', '18:00')]);
    await abrir(tester, servico);

    await tocar(tester, '›');
    await tocar(tester, '›');
    expect(mesmoDia(servico.pedidos.last, hoje().add(const Duration(days: 2))), isTrue);

    await tester.tap(find.widgetWithText(InkWell, 'HOJE'));
    await avancar(tester);

    expect(mesmoDia(servico.pedidos.last, hoje()), isTrue);
  });

  testWidgets('dia sem quadras mostra "fechada neste dia" (CT-H1-07)', (tester) async {
    final servico = QuadrasServiceFalso((dia) async => <HorarioSlot>[]);

    await abrir(tester, servico);

    expect(find.text('FECHADA NESTE DIA'), findsOneWidget);
    expect(
      find.text('Nenhuma quadra funciona neste dia da semana. Escolha outra data.'),
      findsOneWidget,
    );
  });

  testWidgets('falha na consulta mostra o erro e deixa tentar de novo (CT-H1-08)', (tester) async {
    var chamadas = 0;
    final servico = QuadrasServiceFalso((dia) async {
      chamadas++;
      if (chamadas == 1) throw Exception('sem conexão');
      return [slot('Saibro 1', '18:00')];
    });

    await abrir(tester, servico);
    expect(find.text('Erro ao carregar'), findsOneWidget);
    expect(find.text('SAIBRO 1'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await avancar(tester);

    expect(find.text('Erro ao carregar'), findsNothing);
    expect(find.text('SAIBRO 1'), findsOneWidget);
  });

  testWidgets('quando o Realtime avisa uma mudança, a consulta recarrega sozinha (RNF08)', (tester) async {
    var status = 'livre';
    final servico = QuadrasServiceFalso((dia) async => [slot('Saibro 1', '18:00', status: status)]);
    await abrir(tester, servico);
    expect(servico.aoMudar, isNotNull, reason: 'a tela assina as mudanças de ocupação');
    expect(servico.pedidos.length, 1);

    // Outro cliente reserva o horário: o banco avisa a tela, sem o usuário recarregar.
    status = 'reservado';
    servico.aoMudar!();
    await avancar(tester);

    expect(servico.pedidos.length, 2);
    await tocar(tester, '18:00');
    expect(find.byKey(const Key('reserva-stub')), findsNothing, reason: 'o horário deixou de ser livre');
  });

  testWidgets('o ícone da área do proprietário leva ao login (CT-H7-10)', (tester) async {
    final servico = QuadrasServiceFalso((dia) async => [slot('Saibro 1', '18:00')]);
    await abrir(tester, servico);

    await tester.tap(find.byTooltip('Área do proprietário'));
    await avancar(tester, 500);

    expect(find.text('LOGIN'), findsOneWidget);
  });
}
