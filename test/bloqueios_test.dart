import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gqt/admin/bloqueios_page.dart';
import 'package:gqt/admin/bloqueios_repositorio.dart';
import 'package:gqt/admin/quadras_repositorio.dart';
import 'package:gqt/models/bloqueio.dart';
import 'package:gqt/models/quadra.dart';

final hoje = DateTime(2030, 1, 7); // segunda-feira
final amanha = DateTime(2030, 1, 8);

const saibro1 =
    Quadra(id: 1, nome: 'Saibro 1', tipoPiso: TipoPiso.saibro, descricao: null, ativa: true);
const rapida =
    Quadra(id: 3, nome: 'Rápida 1', tipoPiso: TipoPiso.dura, descricao: null, ativa: true);

/// Repositório em memória com as regras do gatilho `validar_bloqueio`.
class BloqueiosFalsos implements BloqueiosRepositorio {
  BloqueiosFalsos({
    List<Bloqueio>? bloqueios,
    this.reservadas = const {},
    this.fechadaNoDia,
    this.reservaChegaAntes = false,
  }) : lista = bloqueios ?? [];

  final List<Bloqueio> lista;

  /// `"quadraId|aaaa-mm-dd|hora"` com reserva confirmada.
  final Set<String> reservadas;

  /// Data em que as quadras não abrem.
  final DateTime? fechadaNoDia;

  /// Simula outra pessoa reservando entre a busca e o salvar.
  final bool reservaChegaAntes;

  int _id = 100;

  String _k(int q, DateTime d, int h) => '$q|${dataIso(d)}|$h';

  @override
  Future<List<Quadra>> quadrasAtivas() async => [rapida, saibro1];

  @override
  Future<List<Bloqueio>> futuros() async => [...lista];

  @override
  Future<HorariosBloqueaveis> livres(int quadraId, DateTime data) async {
    if (fechadaNoDia != null && dataIso(fechadaNoDia!) == dataIso(data)) {
      return const HorariosBloqueaveis(aberta: false, livres: []);
    }
    final livres = [
      for (var h = 7; h < 22; h++)
        if (!reservadas.contains(_k(quadraId, data, h)) &&
            !lista.any((b) => b.quadraId == quadraId && dataIso(b.data) == dataIso(data) && b.hora == h))
          h,
    ];
    return HorariosBloqueaveis(aberta: true, livres: livres);
  }

  @override
  Future<void> bloquear(
      {required int quadraId, required DateTime data, required int hora, String? motivo}) async {
    if (reservaChegaAntes || reservadas.contains(_k(quadraId, data, hora))) {
      throw const FalhaQuadra(
          'Existe um agendamento neste horário. Cancele a reserva do cliente antes de realizar o bloqueio.',
          codigo: 'HORARIO_RESERVADO');
    }
    final m = motivo?.trim();
    lista.add(Bloqueio(
      id: _id++,
      quadraId: quadraId,
      quadraNome: quadraId == 1 ? 'Saibro 1' : 'Rápida 1',
      data: data,
      hora: hora,
      motivo: (m == null || m.isEmpty) ? null : m,
    ));
  }

  @override
  Future<void> desbloquear(int id) async => lista.removeWhere((b) => b.id == id);
}

Future<BloqueiosFalsos> abrir(WidgetTester tester, BloqueiosFalsos repo,
    {Size tamanho = const Size(1200, 1600)}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: BloqueiosPage(repositorio: repo, hoje: hoje)));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> abrirNovo(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('bloqueios-novo')));
  await tester.pumpAndSettle();
}

Future<void> escolher(WidgetTester tester, String chaveCampo, String opcao) async {
  await tester.tap(find.byKey(Key(chaveCampo)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(opcao).last);
  await tester.pumpAndSettle();
}

Bloqueio bloqueio(int id, int hora, {String? motivo}) => Bloqueio(
    id: id, quadraId: 1, quadraNome: 'Saibro 1', data: amanha, hora: hora, motivo: motivo);

void main() {
  testWidgets('lista vazia mostra o convite para bloquear', (tester) async {
    await abrir(tester, BloqueiosFalsos());
    expect(find.text('NENHUM BLOQUEIO FUTURO'), findsOneWidget);
  });

  testWidgets('lista bloqueios com faixa, data, dia e motivo', (tester) async {
    await abrir(tester,
        BloqueiosFalsos(bloqueios: [bloqueio(1, 9, motivo: 'Troca da rede'), bloqueio(2, 10)]));

    expect(find.text('SAIBRO 1'), findsNWidgets(2));
    expect(find.text('09:00–10:00'), findsOneWidget);
    expect(find.text('08/01/2030 · Terça · Troca da rede'), findsOneWidget);
    expect(find.text('08/01/2030 · Terça · Sem motivo informado'), findsOneWidget);
  });

  testWidgets('bloqueia um horário livre com motivo (cenário principal)', (tester) async {
    final repo = await abrir(tester, BloqueiosFalsos());

    await abrirNovo(tester);
    expect(find.text('15 horários livres.'), findsOneWidget); // amanhã, 07h–22h
    await escolher(tester, 'bloqueio-quadra', 'Saibro 1');
    await escolher(tester, 'bloqueio-hora-1-2030-01-08-15', '14:00–15:00');
    await tester.enterText(find.byKey(const Key('bloqueio-motivo')), ' Manutenção do piso ');
    await tester.tap(find.byKey(const Key('bloqueio-salvar')));
    await tester.pumpAndSettle();

    expect(repo.lista.single.quadraId, 1);
    expect(repo.lista.single.hora, 14);
    expect(repo.lista.single.motivo, 'Manutenção do piso');
    expect(find.textContaining('aparece em marrom'), findsOneWidget);
    expect(find.text('14:00–15:00'), findsOneWidget);
  });

  testWidgets('horário reservado não aparece entre os livres', (tester) async {
    await abrir(tester, BloqueiosFalsos(reservadas: {'3|2030-01-08|7'}));

    await abrirNovo(tester); // Rápida 1 é a primeira (ordem de nome)
    expect(find.text('14 horários livres.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bloqueio-hora-3-2030-01-08-14')));
    await tester.pumpAndSettle();
    expect(find.text('07:00–08:00'), findsNothing);
  });

  testWidgets('quadra fechada no dia desliga o salvar', (tester) async {
    await abrir(tester, BloqueiosFalsos(fechadaNoDia: amanha));

    await abrirNovo(tester);

    expect(find.text('A quadra está fechada neste dia da semana.'), findsOneWidget);
    final botao = tester.widget<FilledButton>(find.byKey(const Key('bloqueio-salvar')));
    expect(botao.onPressed, isNull);
  });

  testWidgets('reserva feita no meio do caminho: mostra o erro do banco (H5 alt.)',
      (tester) async {
    final repo = await abrir(tester, BloqueiosFalsos(reservaChegaAntes: true));

    await abrirNovo(tester);
    await tester.tap(find.byKey(const Key('bloqueio-salvar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cancele a reserva do cliente'), findsOneWidget);
    expect(find.text('NOVO BLOQUEIO'), findsWidgets); // diálogo continua aberto
    expect(repo.lista, isEmpty);
  });

  testWidgets('remover libera o horário', (tester) async {
    final repo = await abrir(tester, BloqueiosFalsos(bloqueios: [bloqueio(7, 9)]));

    await tester.tap(find.byKey(const Key('bloqueio-remover-7')));
    await tester.pumpAndSettle();

    expect(repo.lista, isEmpty);
    expect(find.text('Bloqueio removido. O horário voltou a ficar livre.'), findsOneWidget);
    expect(find.text('NENHUM BLOQUEIO FUTURO'), findsOneWidget);
  });

  testWidgets('cabe em celular (360px), lista e diálogo', (tester) async {
    await abrir(
      tester,
      BloqueiosFalsos(bloqueios: [
        Bloqueio(
            id: 1,
            quadraId: 1,
            quadraNome: 'Quadra Central Coberta',
            data: amanha,
            hora: 21,
            motivo: 'Motivo bem comprido para ver se a linha quebra direitinho'),
      ]),
      tamanho: const Size(360, 740),
    );
    expect(tester.takeException(), isNull, reason: 'lista');
    expect(find.text('21h–22h'), findsOneWidget); // formato curto no celular
    await abrirNovo(tester);
    expect(tester.takeException(), isNull, reason: 'diálogo');
  });

  group('traduzirErroBloqueio', () {
    test('hint do banco', () {
      final f = traduzirErroBloqueio(const PostgrestException(
          message: 'Não é possível bloquear um horário que já passou.', hint: 'HORARIO_PASSADO'));
      expect(f.codigo, 'HORARIO_PASSADO');
    });

    test('unique = já bloqueado', () {
      final f = traduzirErroBloqueio(const PostgrestException(message: 'dup', code: '23505'));
      expect(f.mensagem, 'Este horário já está bloqueado.');
    });

    test('sem permissão = sessão expirada', () {
      final f = traduzirErroBloqueio(const PostgrestException(message: 'rls', code: '42501'));
      expect(f.sessaoExpirada, isTrue);
    });
  });
}
