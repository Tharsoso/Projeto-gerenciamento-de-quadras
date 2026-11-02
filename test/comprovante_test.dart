import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gqt/publico/comprovante_whatsapp.dart';
import 'package:gqt/publico/reservas_repositorio.dart';
import 'package:gqt/screens/public/sucesso_screen.dart';

final reserva = ReservaConfirmada(
  id: 42,
  quadra: 'Saibro 1',
  data: DateTime(2026, 11, 10),
  hora: '18:00',
  valor: 80,
  nome: 'Maria da Silva',
  telefone: '31999990000',
);

Future<void> abrir(WidgetTester tester, AbrirLink abrirLink) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: SucessoScreen(reserva: reserva, abrirLink: abrirLink),
  ));
}

void main() {
  test('mensagem traz todos os dados da reserva', () {
    final m = mensagemComprovante(reserva);

    expect(m, contains('Quadra: Saibro 1'));
    expect(m, contains('Data: 10/11/2026'));
    expect(m, contains('Horário: 18:00 às 19:00'));
    expect(m, contains('Valor: R\$ 80,00'));
    expect(m, contains('Nome: Maria da Silva'));
    expect(m, contains('Telefone: (31) 99999-0000'));
    expect(m, contains('Código: R0042'));
  });

  test('link wa.me vai para o número do proprietário com o texto codificado', () {
    final link = linkComprovante(reserva, numero: '+55 (31) 98888-7777');

    expect(link.host, 'wa.me');
    expect(link.path, '/5531988887777');
    expect(link.toString(), isNot(contains('+')));
    expect(link.queryParameters['text'], mensagemComprovante(reserva));
  });

  test('sem número configurado o cliente escolhe o contato', () {
    final link = linkComprovante(reserva, numero: '');

    expect(link.toString(), startsWith('https://wa.me/?text='));
  });

  test('reserva às 21:00 termina às 22:00', () {
    final r = ReservaConfirmada(
      id: 1,
      quadra: 'Saibro 1',
      data: DateTime(2026, 11, 10),
      hora: '21:00',
      valor: 80,
      nome: 'Ana',
      telefone: '31999990000',
    );

    expect(mensagemComprovante(r), contains('21:00 às 22:00'));
  });

  testWidgets('botão abre o WhatsApp com o comprovante (4.4)', (tester) async {
    Uri? aberto;
    await abrir(tester, (link) async {
      aberto = link;
      return true;
    });

    await tester.tap(find.byKey(const Key('sucesso-whatsapp')));
    await tester.pump();

    expect(aberto?.host, 'wa.me');
    expect(aberto?.queryParameters['text'], contains('Código: R0042'));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('se o WhatsApp não abrir, avisa para anotar o código', (tester) async {
    await abrir(tester, (link) async => false);

    await tester.tap(find.byKey(const Key('sucesso-whatsapp')));
    await tester.pump();

    expect(
      find.text('Não foi possível abrir o WhatsApp. Anote o código da reserva.'),
      findsOneWidget,
    );
  });
}
