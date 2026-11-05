import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gqt/admin/agendamentos_page.dart';
import 'package:gqt/admin/agendamentos_repositorio.dart';
import 'package:gqt/admin/cancelamento.dart';
import 'package:gqt/admin/quadras_repositorio.dart';
import 'package:gqt/models/agendamento.dart';
import 'package:gqt/models/quadra.dart';

final hoje = DateTime(2030, 1, 7); // segunda-feira
final agora = DateTime(2030, 1, 7, 10, 30);

const saibro1 =
    Quadra(id: 1, nome: 'Saibro 1', tipoPiso: TipoPiso.saibro, descricao: null, ativa: true);

Agendamento reserva(int id,
        {DateTime? data, int hora = 18, bool cancelada = false, String? motivo}) =>
    Agendamento(
      id: id,
      quadraId: 1,
      quadraNome: 'Saibro 1',
      data: data ?? hoje,
      hora: hora,
      nome: 'Maria da Silva',
      telefone: '31999990000',
      valor: 90,
      cancelada: cancelada,
      anonimizada: false,
      motivoCancelamento: motivo,
    );

class AgendamentosFalsos implements AgendamentosRepositorio {
  AgendamentosFalsos(this.lista);

  final List<Agendamento> lista;
  int cargas = 0;

  @override
  Future<List<Quadra>> quadras() async => [saibro1];

  @override
  Future<List<Agendamento>> listar(FiltroAgendamentos f) async {
    cargas++;
    return [...lista];
  }
}

/// Repete as regras da `cancelar_reserva`: exclusão lógica + motivo no log.
class CancelamentoFalso implements CancelamentoRepositorio {
  CancelamentoFalso(this.lista, {this.falha});

  final List<Agendamento> lista;
  FalhaQuadra? falha;
  final chamadas = <(int, String?)>[];

  @override
  Future<void> cancelar(int reservaId, {String? motivo}) async {
    if (falha != null) throw falha!;
    final i = lista.indexWhere((a) => a.id == reservaId);
    final a = lista[i];
    if (a.cancelada) {
      throw const FalhaQuadra('Esta reserva já está cancelada.', codigo: 'RESERVA_JA_CANCELADA');
    }
    final m = motivo?.trim();
    chamadas.add((reservaId, (m == null || m.isEmpty) ? null : m));
    lista[i] = reserva(a.id,
        data: a.data, hora: a.hora, cancelada: true, motivo: chamadas.last.$2);
  }
}

class Cenario {
  Cenario(List<Agendamento> reservas, {FalhaQuadra? falha})
      : agendamentos = AgendamentosFalsos(reservas),
        cancelamento = CancelamentoFalso(reservas, falha: falha);

  final AgendamentosFalsos agendamentos;
  final CancelamentoFalso cancelamento;
  bool expirou = false;
}

Future<Cenario> abrir(WidgetTester tester, Cenario c,
    {Size tamanho = const Size(1200, 1600)}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: AgendamentosPage(
      repositorio: c.agendamentos,
      hoje: hoje,
      acoes: acoesCancelamento(
        repositorio: c.cancelamento,
        aoSessaoExpirada: () => c.expirou = true,
        agora: () => agora,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return c;
}

Future<void> tocar(WidgetTester tester, String chave) async {
  await tester.ensureVisible(find.byKey(Key(chave)));
  await tester.tap(find.byKey(Key(chave)));
  await tester.pumpAndSettle();
}

void main() {
  group('regras (H3)', () {
    test('pode cancelar futura e em andamento; não passada nem cancelada', () {
      expect(podeCancelar(reserva(1, hora: 18), agora), isTrue);
      expect(podeCancelar(reserva(1, hora: 10), agora), isTrue); // 10h–11h, são 10h30
      expect(podeCancelar(reserva(1, hora: 9), agora), isFalse); // terminou às 10h
      expect(podeCancelar(reserva(1, data: DateTime(2030, 1, 6)), agora), isFalse);
      expect(podeCancelar(reserva(1, cancelada: true), agora), isFalse);
    });

    test('em andamento só entre o início e o fim', () {
      expect(emAndamento(reserva(1, hora: 10), agora), isTrue);
      expect(emAndamento(reserva(1, hora: 11), agora), isFalse);
      expect(emAndamento(reserva(1, hora: 9), agora), isFalse);
    });

    test('reserva das 23h termina à meia-noite do dia seguinte', () {
      expect(podeCancelar(reserva(1, hora: 23), DateTime(2030, 1, 7, 23, 59)), isTrue);
      expect(podeCancelar(reserva(1, hora: 23), DateTime(2030, 1, 8)), isFalse);
    });
  });

  testWidgets('botão só nas reservas que ainda dá para cancelar (H3 alt. 1)', (tester) async {
    await abrir(
      tester,
      Cenario([
        reserva(1, hora: 18),
        reserva(2, hora: 8), // já passou
        reserva(3, hora: 19, cancelada: true),
        reserva(4, data: DateTime(2030, 1, 6)), // ontem
      ]),
    );

    expect(find.byKey(const Key('cancelar-1')), findsOneWidget);
    expect(find.byKey(const Key('cancelar-2')), findsNothing);
    expect(find.byKey(const Key('cancelar-3')), findsNothing);
    expect(find.byKey(const Key('cancelar-4')), findsNothing);
  });

  testWidgets('cancela com motivo e a lista mostra a reserva cancelada', (tester) async {
    final c = await abrir(tester, Cenario([reserva(42, hora: 18)]));

    await tocar(tester, 'cancelar-42');
    expect(find.text('CANCELAR RESERVA'), findsOneWidget);
    expect(find.text('SAIBRO 1 · R0042'), findsOneWidget);
    expect(find.text('Segunda, 07/01/2030 às 18:00'), findsOneWidget);
    expect(find.text('Maria da Silva · R\$ 90,00'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('cancelar-motivo')), ' Cliente avisou que não vem ');
    await tocar(tester, 'cancelar-confirmar');

    expect(c.cancelamento.chamadas.single, (42, 'Cliente avisou que não vem'));
    expect(find.text('Reserva cancelada. O horário voltou a ficar livre para os clientes.'),
        findsOneWidget);
    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.text('Motivo: Cliente avisou que não vem'), findsOneWidget);
    expect(find.byKey(const Key('cancelar-42')), findsNothing);
  });

  testWidgets('sem motivo também cancela', (tester) async {
    final c = await abrir(tester, Cenario([reserva(5)]));

    await tocar(tester, 'cancelar-5');
    await tocar(tester, 'cancelar-confirmar');

    expect(c.cancelamento.chamadas.single, (5, null));
  });

  testWidgets('"Manter reserva" fecha sem cancelar', (tester) async {
    final c = await abrir(tester, Cenario([reserva(5)]));

    await tocar(tester, 'cancelar-5');
    await tocar(tester, 'cancelar-manter');

    expect(c.cancelamento.chamadas, isEmpty);
    expect(find.text('Confirmada'), findsOneWidget);
  });

  testWidgets('reserva em andamento avisa no diálogo', (tester) async {
    await abrir(tester, Cenario([reserva(6, hora: 10)]));

    await tocar(tester, 'cancelar-6');

    expect(find.byKey(const Key('cancelar-em-andamento')), findsOneWidget);
  });

  testWidgets('já cancelada por outra aba: avisa e recarrega', (tester) async {
    final c = await abrir(
      tester,
      Cenario([reserva(7)],
          falha: const FalhaQuadra('Esta reserva já está cancelada.',
              codigo: 'RESERVA_JA_CANCELADA')),
    );
    final cargasAntes = c.agendamentos.cargas;

    await tocar(tester, 'cancelar-7');
    await tocar(tester, 'cancelar-confirmar');

    expect(find.text('CANCELAR RESERVA'), findsNothing);
    expect(find.text('Esta reserva já está cancelada.'), findsOneWidget);
    expect(c.agendamentos.cargas, cargasAntes + 1);
  });

  testWidgets('sem internet: o diálogo fica aberto para tentar de novo', (tester) async {
    final c = await abrir(
      tester,
      Cenario([reserva(8)],
          falha: const FalhaQuadra(
              'Não foi possível conectar. Verifique a internet e tente novamente.')),
    );

    await tocar(tester, 'cancelar-8');
    await tocar(tester, 'cancelar-confirmar');
    expect(find.textContaining('Não foi possível conectar'), findsOneWidget);
    expect(find.text('CANCELAR RESERVA'), findsOneWidget);

    c.cancelamento.falha = null;
    await tocar(tester, 'cancelar-confirmar');
    expect(c.cancelamento.chamadas.single.$1, 8);
  });

  testWidgets('sessão expirada chama o callback', (tester) async {
    final c = await abrir(
      tester,
      Cenario([reserva(9)],
          falha: const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true)),
    );

    await tocar(tester, 'cancelar-9');
    await tocar(tester, 'cancelar-confirmar');

    expect(c.expirou, isTrue);
  });

  testWidgets('cabe em celular (360px), lista e diálogo', (tester) async {
    await abrir(tester, Cenario([reserva(10), reserva(11, hora: 10)]),
        tamanho: const Size(360, 740));
    expect(tester.takeException(), isNull, reason: 'lista');
    expect(find.byType(IconButton), findsWidgets); // ícone no lugar do botão com texto
    await tocar(tester, 'cancelar-11');
    expect(tester.takeException(), isNull, reason: 'diálogo');
  });

  group('traduzirErroCancelamento', () {
    test('hint do banco', () {
      final f = traduzirErroCancelamento(const PostgrestException(
          message: 'Não é possível cancelar uma reserva que já terminou.',
          hint: 'RESERVA_PASSADA'));
      expect(f.codigo, 'RESERVA_PASSADA');
      expect(f.mensagem, 'Não é possível cancelar uma reserva que já terminou.');
    });

    test('NAO_AUTORIZADO e 42501 = sessão expirada', () {
      expect(
          traduzirErroCancelamento(
                  const PostgrestException(message: 'x', hint: 'NAO_AUTORIZADO'))
              .sessaoExpirada,
          isTrue);
      expect(
          traduzirErroCancelamento(const PostgrestException(message: 'x', code: '42501'))
              .sessaoExpirada,
          isTrue);
    });
  });
}
