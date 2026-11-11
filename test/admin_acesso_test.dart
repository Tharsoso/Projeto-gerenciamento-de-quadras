import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:gqt/admin/agendamentos_page.dart';
import 'package:gqt/admin/agendamentos_repositorio.dart';
import 'package:gqt/admin/bloqueios_page.dart';
import 'package:gqt/admin/bloqueios_repositorio.dart';
import 'package:gqt/admin/cancelamento.dart';
import 'package:gqt/admin/faturamento_page.dart';
import 'package:gqt/admin/faturamento_repositorio.dart';
import 'package:gqt/admin/feriados_page.dart';
import 'package:gqt/admin/feriados_repositorio.dart';
import 'package:gqt/admin/horarios_page.dart';
import 'package:gqt/admin/horarios_repositorio.dart';
import 'package:gqt/admin/precos_page.dart';
import 'package:gqt/admin/precos_repositorio.dart';
import 'package:gqt/admin/quadras_page.dart';
import 'package:gqt/admin/quadras_repositorio.dart';
import 'package:gqt/app.dart';
import 'package:gqt/auth/autenticacao.dart';
import 'package:gqt/models/agendamento.dart';
import 'package:gqt/models/bloqueio.dart';
import 'package:gqt/models/funcionamento.dart';
import 'package:gqt/models/preco.dart';
import 'package:gqt/models/quadra.dart';

/// Testes de acesso à área administrativa (atividade 6.3): proteção de todas as rotas
/// `/admin/*`, módulos do painel e expiração da sessão por inatividade em cada tela.
///
/// Os testes de cada módulo (quadras, horários, preços...) ficam nos arquivos deles. Aqui os
/// repositórios são falsos e devolvem listas vazias, só para as telas abrirem.

/// Autenticação em memória: começa logada ou não e `sair()` encerra a sessão.
class AuthFalsa extends ChangeNotifier implements Autenticacao {
  AuthFalsa({this.logado = false});

  @override
  bool logado;

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

class _Quadras extends Fake implements QuadrasRepositorio {
  @override
  Future<List<Quadra>> listar() async => <Quadra>[];
}

class _Horarios extends Fake implements HorariosRepositorio {
  @override
  Future<List<Quadra>> quadras() async => <Quadra>[];

  @override
  Future<Map<int, Semana>> funcionamento() async => <int, Semana>{};
}

class _Bloqueios extends Fake implements BloqueiosRepositorio {
  @override
  Future<List<Quadra>> quadrasAtivas() async => <Quadra>[];

  @override
  Future<List<Bloqueio>> futuros() async => <Bloqueio>[];
}

class _Precos extends Fake implements PrecosRepositorio {
  @override
  Future<List<Quadra>> quadras() async => <Quadra>[];

  @override
  Future<Map<int, Semana>> funcionamento() async => <int, Semana>{};

  @override
  Future<Map<int, TabelaPrecos>> tabelas() async => <int, TabelaPrecos>{};
}

class _Feriados extends Fake implements FeriadosRepositorio {
  @override
  Future<List<Feriado>> listar() async => <Feriado>[];
}

class _Agendamentos extends Fake implements AgendamentosRepositorio {
  @override
  Future<List<Quadra>> quadras() async => <Quadra>[];

  @override
  Future<List<Agendamento>> listar(FiltroAgendamentos filtro) async => <Agendamento>[];
}

class _Faturamento extends Fake implements FaturamentoRepositorio {
  @override
  Future<ResumoFaturamento> resumo(DateTime inicio, DateTime fim, {String? telefone}) async =>
      const ResumoFaturamento(locacoes: 0, faturamento: 0, canceladas: 0);

  @override
  Future<Map<DateTime, double>> porDia(DateTime inicio, DateTime fim, {String? telefone}) async =>
      <DateTime, double>{};
}

class _Cancelamento extends Fake implements CancelamentoRepositorio {
  @override
  Future<void> cancelar(int reservaId, {String? motivo}) async {}
}

const limite = Duration(minutes: 30);

/// Todas as rotas da área administrativa.
const rotasAdmin = [
  '/admin',
  '/admin/quadras',
  '/admin/horarios',
  '/admin/bloqueios',
  '/admin/precos',
  '/admin/feriados',
  '/admin/reservas',
  '/admin/faturamento',
];

/// Chave do cartão no painel e a tela que ele deve abrir.
const modulos = <String, Type>{
  'painel-quadras': QuadrasPage,
  'painel-horarios': HorariosPage,
  'painel-precos': PrecosPage,
  'painel-bloqueios': BloqueiosPage,
  'painel-reservas': AgendamentosPage,
  'painel-faturamento': FaturamentoPage,
  'painel-feriados': FeriadosPage,
};

/// Abre o app na home e vai para [rota], como acontece quando alguém digita o endereço.
Future<void> abrir(WidgetTester tester, AuthFalsa auth, String rota) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(App(
    auth: auth,
    limiteInatividade: limite,
    quadras: _Quadras(),
    horarios: _Horarios(),
    bloqueios: _Bloqueios(),
    precos: _Precos(),
    feriados: _Feriados(),
    agendamentos: _Agendamentos(),
    faturamento: _Faturamento(),
    cancelamento: _Cancelamento(),
  ));
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(rota);
  await tester.pumpAndSettle();
}

void main() {
  for (final rota in rotasAdmin) {
    testWidgets('$rota sem login vai para o login (CT-H7-06)', (tester) async {
      await abrir(tester, AuthFalsa(), rota);

      expect(find.text('Área do proprietário'), findsOneWidget);
      expect(find.text('Painel do proprietário'), findsNothing);
    });
  }

  testWidgets('o painel mostra os sete módulos do proprietário (CT-H7-11)', (tester) async {
    await abrir(tester, AuthFalsa(logado: true), '/admin');

    expect(find.text('Painel do proprietário'), findsOneWidget);
    for (final chave in modulos.keys) {
      expect(find.byKey(Key(chave)), findsOneWidget, reason: chave);
    }
  });

  for (final modulo in modulos.entries) {
    testWidgets('o cartão ${modulo.key} abre a tela do módulo (CT-H7-12)', (tester) async {
      await abrir(tester, AuthFalsa(logado: true), '/admin');

      await tester.tap(find.byKey(Key(modulo.key)));
      await tester.pumpAndSettle();

      expect(find.byType(modulo.value), findsOneWidget);
      expect(find.text('Painel do proprietário'), findsNothing);
    });
  }

  for (final rota in rotasAdmin) {
    testWidgets('30 min sem interação em $rota encerra a sessão (CT-H7-04)', (tester) async {
      final auth = AuthFalsa(logado: true);
      await abrir(tester, auth, rota);
      expect(find.text('Área do proprietário'), findsNothing, reason: 'logado, a tela abre');

      await tester.pump(limite);
      await tester.pumpAndSettle();

      expect(auth.logado, isFalse);
      expect(find.text('Sessão encerrada por inatividade. Entre novamente.'), findsOneWidget);
    });
  }
}
