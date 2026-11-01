import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Tempo sem interação que encerra a sessão do proprietário (RNF05).
const limiteInatividadePadrao = Duration(minutes: 30);

/// Chama [aoExpirar] quando o usuário passa [limite] sem clicar, rolar ou digitar
/// dentro de [child]. Envolve toda a área administrativa.
class ControleInatividade extends StatefulWidget {
  const ControleInatividade({
    super.key,
    required this.limite,
    required this.aoExpirar,
    required this.child,
  });

  final Duration limite;
  final VoidCallback aoExpirar;
  final Widget child;

  @override
  State<ControleInatividade> createState() => _ControleInatividadeState();
}

class _ControleInatividadeState extends State<ControleInatividade> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_aoTeclar);
    _reiniciar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_aoTeclar);
    super.dispose();
  }

  void _reiniciar() {
    _timer?.cancel();
    _timer = Timer(widget.limite, widget.aoExpirar);
  }

  bool _aoTeclar(KeyEvent _) {
    _reiniciar();
    return false; // não consome a tecla
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _reiniciar(),
      onPointerSignal: (_) => _reiniciar(),
      child: widget.child,
    );
  }
}
