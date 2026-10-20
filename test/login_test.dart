import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:gqt/app.dart';
import 'package:gqt/auth/autenticacao.dart';

/// Autenticação em memória: só aceita proprietario@gqt.com / segredo.
class AutenticacaoFalsa extends ChangeNotifier implements Autenticacao {
  AutenticacaoFalsa({this.logado = false});

  @override
  bool logado;

  @override
  Future<void> entrar({required String email, required String senha}) async {
    if (email.trim() != 'proprietario@gqt.com' || senha != 'segredo') {
      throw const FalhaLogin('E-mail ou senha inválidos');
    }
    logado = true;
    notifyListeners();
  }

  @override
  Future<void> sair() async {
    logado = false;
    notifyListeners();
  }
}

const limite = Duration(minutes: 30);

Future<void> abrir(WidgetTester tester, Autenticacao auth, String rota) async {
  await tester.pumpWidget(App(auth: auth, limiteInatividade: limite));
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(rota);
  await tester.pumpAndSettle();
}

Future<void> preencherLogin(WidgetTester tester, String email, String senha) async {
  await tester.enterText(find.byKey(const Key('login-email')), email);
  await tester.enterText(find.byKey(const Key('login-senha')), senha);
  await tester.tap(find.byKey(const Key('login-entrar')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('acesso direto a /admin sem login vai para o login (alt. 3)', (tester) async {
    await abrir(tester, AutenticacaoFalsa(), '/admin');

    expect(find.text('Área do proprietário'), findsOneWidget);
    expect(find.text('Painel do proprietário'), findsNothing);
  });

  testWidgets('login válido abre o painel (cenário principal)', (tester) async {
    await abrir(tester, AutenticacaoFalsa(), '/login');

    await preencherLogin(tester, 'proprietario@gqt.com', 'segredo');

    expect(find.text('Painel do proprietário'), findsOneWidget);
  });

  testWidgets('credenciais inválidas mostram mensagem genérica (alt. 1)', (tester) async {
    await abrir(tester, AutenticacaoFalsa(), '/login');

    await preencherLogin(tester, 'proprietario@gqt.com', 'errada');

    expect(find.text('E-mail ou senha inválidos'), findsOneWidget);
    expect(find.text('Painel do proprietário'), findsNothing);
  });

  testWidgets('campos vazios não tentam entrar', (tester) async {
    await abrir(tester, AutenticacaoFalsa(), '/login');

    await tester.tap(find.byKey(const Key('login-entrar')));
    await tester.pumpAndSettle();

    expect(find.text('Campo obrigatório'), findsNWidgets(2));
  });

  testWidgets('logado em /login vai direto para o painel', (tester) async {
    await abrir(tester, AutenticacaoFalsa(logado: true), '/login');

    expect(find.text('Painel do proprietário'), findsOneWidget);
  });

  testWidgets('botão Sair encerra a sessão', (tester) async {
    final auth = AutenticacaoFalsa(logado: true);
    await abrir(tester, auth, '/admin');

    await tester.tap(find.byKey(const Key('painel-sair')));
    await tester.pumpAndSettle();

    expect(auth.logado, isFalse);
    expect(find.text('Área do proprietário'), findsOneWidget);
  });

  testWidgets('30 min sem interação encerra a sessão (alt. 2)', (tester) async {
    final auth = AutenticacaoFalsa(logado: true);
    await abrir(tester, auth, '/admin');

    await tester.pump(limite);
    await tester.pumpAndSettle();

    expect(auth.logado, isFalse);
    expect(find.text('Sessão encerrada por inatividade. Entre novamente.'), findsOneWidget);
  });

  testWidgets('interação reinicia a contagem de inatividade', (tester) async {
    final auth = AutenticacaoFalsa(logado: true);
    await abrir(tester, auth, '/admin');

    await tester.pump(const Duration(minutes: 20));
    await tester.tap(find.text('Agenda do dia (em construção)'));
    await tester.pump(const Duration(minutes: 20));

    expect(auth.logado, isTrue);
    expect(find.text('Painel do proprietário'), findsOneWidget);
  });
}
