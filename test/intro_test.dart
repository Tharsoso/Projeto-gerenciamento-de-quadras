import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gqt/screens/intro_screen.dart';

void main() {
  Future<void> abrir(WidgetTester tester, VoidCallback aoTerminar) async {
    var terminou = false;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: StatefulBuilder(
        builder: (context, setState) => terminou
            ? const SizedBox()
            : IntroScreen(onDone: () {
                aoTerminar();
                setState(() => terminou = true);
              }),
      ),
    ));
  }

  testWidgets('roda sozinha até o fim e avisa uma vez', (tester) async {
    var avisos = 0;
    await abrir(tester, () => avisos++);

    await tester.pump(const Duration(seconds: 2)); // limite de espera dos frames
    expect(avisos, 0);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(avisos, 1);
    expect(find.byType(IntroScreen), findsNothing);
  });

  testWidgets('Pular encerra antes do fim', (tester) async {
    var avisos = 0;
    await abrir(tester, () => avisos++);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('intro-pular')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(avisos, 1);
  });
}
