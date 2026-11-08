import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:gqt/app.dart';
import 'package:gqt/auth/autenticacao.dart';
import 'package:gqt/publico/reservas_repositorio.dart';
import 'package:gqt/screens/public/consulta_horarios_screen.dart';

/// Testes da tela de confirmação da reserva e da proteção da rota `/sucesso` (atividade 6.2).
/// O comprovante do WhatsApp já é testado em `comprovante_test.dart`.
class _AuthFalsa extends ChangeNotifier implements Autenticacao {
  @override
  bool get logado => false;

  @override
  Future<void> entrar({required String email, required String senha}) async {}

  @override
  Future<void> sair() async {}
}

final _reserva = ReservaConfirmada(
  id: 42,
  quadra: 'Saibro 1',
  data: DateTime(2026, 11, 10),
  hora: '18:00',
  valor: 80,
  nome: 'Maria da Silva',
  telefone: '31999990000',
);

/// Abre o app na home e vai para `/sucesso`, como o fluxo da reserva faz.
/// A home tem animações que nunca terminam, então se usa `pump()` e não `pumpAndSettle()`.
Future<void> _abrirSucesso(WidgetTester tester, {Object? extra}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(App(auth: _AuthFalsa()));
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/sucesso', extra: extra);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('a tela de sucesso mostra o código mesmo sem usar o WhatsApp (RNF10)', (tester) async {
    await _abrirSucesso(tester, extra: _reserva);

    final codigo = tester.widget<Text>(find.byKey(const Key('sucesso-codigo')));
    expect(codigo.data, contains('R0042'));
    expect(find.byKey(const Key('sucesso-whatsapp')), findsOneWidget);
  });

  testWidgets('"Ver outros horários" volta para a home', (tester) async {
    await _abrirSucesso(tester, extra: _reserva);

    await tester.tap(find.byKey(const Key('sucesso-voltar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(ConsultaHorariosScreen), findsOneWidget);
    expect(find.byKey(const Key('sucesso-codigo')), findsNothing);
  });

  testWidgets('abrir /sucesso sem ter feito a reserva volta para a home', (tester) async {
    await _abrirSucesso(tester);

    expect(find.byKey(const Key('sucesso-codigo')), findsNothing);
    expect(find.byType(ConsultaHorariosScreen), findsOneWidget);
  });
}
