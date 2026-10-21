import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gqt/app_theme.dart';
import 'package:gqt/screens/admin/login_prototipo_screen.dart';

void main() {
  testWidgets('Login do proprietário valida e-mail e senha', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const LoginPrototipoScreen(),
    ));

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsOneWidget);
  });
}
