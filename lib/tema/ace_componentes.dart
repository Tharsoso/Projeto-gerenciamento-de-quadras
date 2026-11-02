import 'package:flutter/material.dart';

import 'ace_cores.dart';

/// Componentes do protótipo Ace Saibro usados nas telas da área do proprietário.

/// Aviso escuro com a bolinha amarela (o "toast" do protótipo).
void aceAviso(BuildContext context, String texto, {bool erro = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AceCores.tinta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Row(children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: erro ? const Color(0xFFFF6B6B) : AceCores.bola, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(texto)),
      ]),
    ));
}

/// Barra verde-escura da área admin, com voltar ao painel.
PreferredSizeWidget aceBarraAdmin(BuildContext context, String titulo, {VoidCallback? aoVoltar}) =>
    AppBar(
      backgroundColor: AceCores.verdeEscuro,
      foregroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 64,
      leading: IconButton(
        tooltip: 'Voltar ao painel',
        icon: const Icon(Icons.arrow_back),
        onPressed: aoVoltar ?? () => Navigator.of(context).maybePop(),
      ),
      title: Text(titulo.toUpperCase(), style: AceEstilo.barra),
    );

class AceChip extends StatelessWidget {
  const AceChip({super.key, required this.texto, required this.fundo, required this.cor});

  final String texto;
  final Color fundo;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(texto, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class AceRotulo extends StatelessWidget {
  const AceRotulo(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 7),
        child: Text(
          texto.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: .6,
              color: AceCores.apagado),
        ),
      );
}

class AceAlerta extends StatelessWidget {
  const AceAlerta({super.key, required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: AceCores.vermelhoClaro, borderRadius: BorderRadius.circular(18)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFF8E1B1B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(mensagem,
                  style: const TextStyle(color: Color(0xFF8E1B1B), fontSize: 14.5)),
            ),
          ],
        ),
      );
}

/// Tipografia e botões do protótipo. A fonte "Big Shoulders Display" não está no app
/// (precisaria do pacote google_fonts); os títulos usam peso 900 em caixa alta.
abstract final class AceEstilo {
  static const barra =
      TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 1, height: 1);
  static const titulo = TextStyle(
      fontSize: 64, fontWeight: FontWeight.w900, height: .9, color: AceCores.tinta);
  static const tituloDialogo = TextStyle(
      fontSize: 40, fontWeight: FontWeight.w900, height: .95, color: AceCores.tinta);
  static const nomeQuadra = TextStyle(
      fontSize: 22, fontWeight: FontWeight.w800, height: 1.1, color: AceCores.tinta);
  static const fab = TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.2);

  static final _pilula = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));

  static final botaoPrimario = FilledButton.styleFrom(
    backgroundColor: AceCores.verde,
    foregroundColor: Colors.white,
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    shape: _pilula,
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );
  static final botaoTonal = FilledButton.styleFrom(
    backgroundColor: AceCores.verdeClaro,
    foregroundColor: AceCores.verde,
    minimumSize: const Size(0, 38),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: _pilula,
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );
  static final botaoContorno = OutlinedButton.styleFrom(
    foregroundColor: AceCores.tinta,
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    side: const BorderSide(color: AceCores.linha, width: 1.5),
    shape: _pilula,
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );

  static InputDecoration campo({String? hint, String? erro}) {
    OutlineInputBorder borda(Color cor, [double largura = 1.5]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cor, width: largura));
    return InputDecoration(
      hintText: hint,
      errorText: erro,
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: borda(AceCores.linha),
      focusedBorder: borda(AceCores.verde, 2),
      errorBorder: borda(AceCores.vermelho),
      focusedErrorBorder: borda(AceCores.vermelho, 2),
      disabledBorder: borda(AceCores.linha),
    );
  }
}
