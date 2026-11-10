import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import 'package:gqt/admin/agendamentos_repositorio.dart';
import 'package:gqt/admin/cancelamento.dart';
import 'package:gqt/app.dart';
import 'package:gqt/auth/autenticacao.dart';
import 'package:gqt/fuso.dart';
import 'package:gqt/models/agendamento.dart';
import 'package:gqt/models/horario_slot.dart';
import 'package:gqt/models/quadra.dart';
import 'package:gqt/publico/reservas_repositorio.dart';
import 'package:gqt/screens/public/consulta_horarios_screen.dart';
import 'package:gqt/services/quadras_service.dart';

/// Responsividade (atividade 6.5, RNF12): as telas principais precisam ficar utilizáveis de
/// 360 px a 1920 px, sem estourar o layout e sem rolagem horizontal.
///
/// Cada tela é aberta em quatro tamanhos. Um layout que estoura aparece como exceção do
/// Flutter ("overflowed by N pixels"), que `tester.takeException()` devolve. A rolagem
/// horizontal é procurada nos widgets que a criam (`ListView`, `SingleChildScrollView` etc.).
///
/// Quando um teste falha, a mensagem diz qual foi a causa (overflow ou rolagem horizontal),
/// qual widget estourou e quais widgets rolam na horizontal.
///
/// As telas de preços, feriados e faturamento têm gráficos e tabelas com rolagem horizontal
/// própria e são conferidas à mão (docs/atividade-6.5-testes-nao-funcionais.md).

const tamanhos = [Size(360, 800), Size(768, 1024), Size(1280, 800), Size(1920, 1080)];

class AuthFalsa extends ChangeNotifier implements Autenticacao {
  AuthFalsa({this.logado = false});

  @override
  bool logado;

  @override
  Future<void> entrar({required String email, required String senha}) async {}

  @override
  Future<void> sair() async {}
}

class QuadrasServiceFalso extends Fake implements QuadrasService {
  QuadrasServiceFalso(this.slots);

  final List<HorarioSlot> slots;

  @override
  Future<List<HorarioSlot>> horariosDoDia(DateTime data) async => slots;

  @override
  RealtimeChannel? assinarOcupacoes(void Function() onChange) => null;
}

class _Reservas extends Fake implements ReservasRepositorio {}

class _Agendamentos extends Fake implements AgendamentosRepositorio {
  _Agendamentos(this.reservas);

  final List<Agendamento> reservas;

  @override
  Future<List<Quadra>> quadras() async => [_quadraLonga];

  @override
  Future<List<Agendamento>> listar(FiltroAgendamentos filtro) async => reservas;
}

class _Cancelamento extends Fake implements CancelamentoRepositorio {
  @override
  Future<void> cancelar(int reservaId, {String? motivo}) async {}
}

const _quadraLonga = Quadra(
  id: 1,
  nome: 'Quadra Central de Saibro Coberta 1',
  tipoPiso: TipoPiso.saibro,
  descricao: null,
  ativa: true,
);

/// Horários de duas quadras, com nomes longos e todos os estados possíveis.
List<HorarioSlot> _slots() {
  const estados = ['livre', 'reservado', 'bloqueado', 'passado', 'sem_preco', 'livre'];
  return [
    for (final quadra in [1, 2])
      for (var hora = 7; hora < 22; hora++)
        HorarioSlot(
          quadraId: quadra,
          quadraNome: quadra == 1 ? 'Quadra Central de Saibro Coberta 1' : 'Rápida 2',
          tipoPiso: quadra == 1 ? 'saibro' : 'dura',
          horaInicio: '${hora.toString().padLeft(2, '0')}:00',
          valor: estados[hora % estados.length] == 'sem_preco' ? null : 1250.5,
          status: estados[hora % estados.length],
        ),
  ];
}

/// Reservas com nome, quadra e motivo de cancelamento bem longos.
List<Agendamento> _reservas() {
  final n = agoraBrasilia();
  final hoje = DateTime(n.year, n.month, n.day);
  return [
    for (var i = 1; i <= 4; i++)
      Agendamento(
        id: i,
        quadraId: 1,
        quadraNome: 'Quadra Central de Saibro Coberta 1',
        data: hoje.add(Duration(days: i)),
        hora: 7 + i,
        nome: 'Maria Aparecida dos Santos Oliveira Albuquerque',
        telefone: '31999990000',
        valor: 1250.5,
        cancelada: i.isEven,
        anonimizada: false,
        motivoCancelamento:
            i.isEven ? 'Cliente avisou que não poderá comparecer por causa de uma viagem inesperada' : null,
      ),
  ];
}

HorarioEscolhido _horario() {
  final n = agoraBrasilia();
  return HorarioEscolhido(
    quadraId: 1,
    quadra: 'Quadra Central de Saibro Coberta 1',
    data: DateTime(n.year, n.month, n.day + 2),
    hora: '18:00',
    valor: 1250.5,
  );
}

void _tamanho(WidgetTester tester, Size tamanho) {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Abre o app inteiro e vai para [rota], como acontece quando alguém digita o endereço.
Future<void> _abrirApp(WidgetTester tester, String rota, {Object? extra, bool logado = false}) async {
  await tester.pumpWidget(App(
    auth: AuthFalsa(logado: logado),
    reservas: _Reservas(),
    agendamentos: _Agendamentos(_reservas()),
    cancelamento: _Cancelamento(),
  ));
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(rota, extra: extra);
  await tester.pumpAndSettle();
}

/// A home tem animações que nunca terminam: só `pump()`, nunca `pumpAndSettle()`.
Future<void> _abrirHome(WidgetTester tester) async {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => ConsultaHorariosScreen(servico: QuadrasServiceFalso(_slots())),
    ),
  ]);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Primeira linha da mensagem de uma exceção do Flutter, para o log não ficar enorme.
String _resumo(Object excecao) {
  final linhas = excecao.toString().split('\n').where((l) => l.trim().isNotEmpty);
  return linhas.take(3).join(' | ');
}

void _conferir(WidgetTester tester) {
  // `takeException()` devolve só a primeira exceção; o laço recolhe todas.
  final excecoes = <Object>[];
  for (Object? e = tester.takeException(); e != null; e = tester.takeException()) {
    excecoes.add(e);
  }
  expect(
    excecoes,
    isEmpty,
    reason: 'o layout estourou (${excecoes.length}): ${excecoes.map(_resumo).join(' || ')}',
  );

  final rolagemHorizontal = find.byWidgetPredicate((w) =>
      (w is ScrollView && w.scrollDirection == Axis.horizontal) ||
      (w is SingleChildScrollView && w.scrollDirection == Axis.horizontal));
  final achados = rolagemHorizontal.evaluate().map((e) => e.widget.runtimeType).toList();

  expect(rolagemHorizontal, findsNothing, reason: 'a tela rola na horizontal: $achados');
}

void main() {
  final telas = <String, Future<void> Function(WidgetTester)>{
    'a home': _abrirHome,
    'a reserva': (t) => _abrirApp(t, '/reserva', extra: _horario()),
    'a confirmação': (t) => _abrirApp(
          t,
          '/sucesso',
          extra: ReservaConfirmada(
            id: 42,
            quadra: 'Quadra Central de Saibro Coberta 1',
            data: DateTime(2026, 11, 10),
            hora: '18:00',
            valor: 1250.5,
            nome: 'Maria Aparecida dos Santos Oliveira Albuquerque',
            telefone: '31999990000',
          ),
        ),
    'o login': (t) => _abrirApp(t, '/login'),
    'o painel': (t) => _abrirApp(t, '/admin', logado: true),
    'as reservas do proprietário': (t) => _abrirApp(t, '/admin/reservas', logado: true),
  };

  for (final tela in telas.entries) {
    for (final tamanho in tamanhos) {
      testWidgets('${tela.key} cabe em ${tamanho.width.toInt()} px (CT-RNF12-01)', (tester) async {
        _tamanho(tester, tamanho);
        await tela.value(tester);

        _conferir(tester);
      });
    }
  }
}
