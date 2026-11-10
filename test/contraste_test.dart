import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gqt/app_theme.dart';

/// Contraste das cores (atividade 6.5, RNF18): texto normal precisa de pelo menos 4,5:1
/// (WCAG 2.1 nível AA). A conta é a da própria WCAG, feita com a luminância das cores da
/// paleta (`AppColors`).
///
/// Aqui estão os pares de texto e fundo que **passam** e que não podem piorar. Os pares que
/// ficam abaixo de 4,5:1 estão listados em docs/atividade-6.5-testes-nao-funcionais.md.

const minimoTextoNormal = 4.5;

double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final escuro = la > lb ? lb : la;
  return (claro + 0.05) / (escuro + 0.05);
}

/// Cor do texto sobre o fundo do chip de status: a própria cor com 10% de opacidade.
Color _fundoDoChip(Color cor) => Color.alphaBlend(cor.withValues(alpha: 0.1), AppColors.bg);

void main() {
  test('o cálculo de contraste bate com os valores conhecidos da WCAG', () {
    expect(contraste(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contraste(Colors.white, Colors.white), closeTo(1, 0.01));
  });

  final pares = <String, (Color, Color)>{
    'texto principal sobre o fundo branco': (AppColors.ink, AppColors.bg),
    'texto principal sobre o fundo claro': (AppColors.ink, AppColors.surf),
    'texto principal sobre o papel': (AppColors.ink, AppColors.paper),
    'texto secundário sobre o fundo branco': (AppColors.muted, AppColors.bg),
    'texto secundário sobre o fundo claro': (AppColors.muted, AppColors.surf),
    'texto secundário sobre o papel': (AppColors.muted, AppColors.paper),
    'branco sobre o verde (botões e horários livres)': (AppColors.bg, AppColors.green),
    'branco sobre o verde médio': (AppColors.bg, AppColors.greenMid),
    'branco sobre o verde escuro': (AppColors.bg, AppColors.greenDark),
    'bola de tênis sobre o verde escuro': (AppColors.ball, AppColors.greenDark),
    'verde sobre o verde claro': (AppColors.green, AppColors.greenTint),
    'branco sobre o vermelho': (AppColors.bg, AppColors.red),
    'chip "Reservado" (vermelho sobre vermelho claro)': (AppColors.red, _fundoDoChip(AppColors.red)),
    'chip "Bloqueado" (marrom sobre marrom claro)': (AppColors.brown, _fundoDoChip(AppColors.brown)),
  };

  for (final par in pares.entries) {
    test('${par.key} tem contraste de pelo menos 4,5:1 (CT-RNF18-01)', () {
      final razao = contraste(par.value.$1, par.value.$2);

      expect(razao, greaterThanOrEqualTo(minimoTextoNormal), reason: razao.toStringAsFixed(2));
    });
  }
}
