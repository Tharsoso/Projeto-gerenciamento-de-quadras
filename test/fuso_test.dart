import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gqt/formatos.dart';
import 'package:gqt/fuso.dart';

/// Regras F1–F7 da atividade 5.9 (RNF15).
void main() {
  group('horário de Brasília (F1, F2)', () {
    test('é sempre UTC−3, sem horário de verão', () {
      expect(agoraBrasilia(DateTime.utc(2026, 11, 5, 15, 30)), DateTime(2026, 11, 5, 12, 30));
      // Janeiro: na época do horário de verão continuaria UTC−3.
      expect(agoraBrasilia(DateTime.utc(2027, 1, 10, 12)), DateTime(2027, 1, 10, 9));
    });

    test('vira o dia três horas depois de UTC', () {
      // 02:30 UTC de 06/11 ainda é 05/11 em Brasília.
      expect(hojeBrasilia(DateTime.utc(2026, 11, 6, 2, 30)), DateTime(2026, 11, 5));
      expect(hojeBrasilia(DateTime.utc(2026, 11, 6, 3)), DateTime(2026, 11, 6));
      // Virada do ano.
      expect(hojeBrasilia(DateTime.utc(2027, 1, 1, 1)), DateTime(2026, 12, 31));
    });

    test('não depende do fuso do aparelho: o mesmo instante dá o mesmo resultado', () {
      final instante = DateTime.utc(2026, 11, 6, 1, 15);
      // Um aparelho em Lisboa (UTC+0) ou em Manaus (UTC−4) vê o mesmo instante.
      final emLisboa = instante.add(Duration.zero);
      final emManaus = DateTime.parse('2026-11-05T21:15:00-04:00');
      expect(agoraBrasilia(emLisboa), DateTime(2026, 11, 5, 22, 15));
      expect(agoraBrasilia(emManaus), DateTime(2026, 11, 5, 22, 15));
    });

    test('devolve data local, no mesmo formato das datas do banco', () {
      expect(agoraBrasilia(DateTime.utc(2026, 11, 5)).isUtc, isFalse);
    });

    test('usa o relógio configurável quando não recebe instante', () {
      final original = relogioUtc;
      addTearDown(() => relogioUtc = original);
      relogioUtc = () => DateTime.utc(2026, 11, 6, 2, 59);
      expect(hojeBrasilia(), DateTime(2026, 11, 5));
      expect(agoraBrasilia().hour, 23);
    });
  });

  test('nenhum arquivo do lib/ usa DateTime.now direto (F3)', () {
    final proibido = RegExp(r'DateTime\.now\b');
    final violacoes = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('fuso.dart')) continue;
      final linhas = f.readAsLinesSync();
      for (var i = 0; i < linhas.length; i++) {
        if (proibido.hasMatch(linhas[i])) violacoes.add('${f.path}:${i + 1}');
      }
    }
    expect(violacoes, isEmpty, reason: 'Use agoraBrasilia()/hojeBrasilia() de lib/fuso.dart');
  });

  testWidgets('o calendário aparece em português (F5)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('pt', 'BR')],
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDatePicker(
            context: context,
            initialDate: DateTime(2026, 11, 5),
            firstDate: DateTime(2026),
            lastDate: DateTime(2027),
          ),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('novembro'), findsWidgets);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  test('moeda e data no formato brasileiro (F6, F7)', () {
    expect(formatarReal(60), 'R\$ 60,00');
    expect(formatarReal(1234.5), 'R\$ 1.234,50');
    expect(formatarReal(1000000), 'R\$ 1.000.000,00');
    expect(formatarReal(0), 'R\$ 0,00');
    expect(formatarData(DateTime(2026, 3, 5)), '05/03/2026');
  });
}
