import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Intro do protótipo (docs/referencia/ace-saibro-reservas.html): vídeo do saque feito
/// com 8 frames, flood verde-limão e a marca "ACE.". Tempos em ms, iguais aos do HTML.
/// Fica por cima da home e sobe no fim, revelando-a; [onDone] avisa quando saiu da tela.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  static const frames = 8;
  static String frame(int i) => 'assets/intro/frame_$i.webp';

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with TickerProviderStateMixin {
  static const _duracao = 3700.0;
  static const _trocas = [0, 430, 760, 1030, 1230, 1400, 1550, 1690];
  static const _impacto = 1030.0;
  static const _flood = 1790.0;
  static const _marca = 2500.0;

  static const _sobe = Cubic(.2, .8, .2, 1);
  static const _floodCurva = Cubic(.65, 0, .2, 1);
  static const _saidaCurva = Cubic(.76, 0, .16, 1);

  // preserve: com "reduzir animações" ligado no sistema, o Flutter acelera os controllers
  // em 20× e a intro duraria 0,2 s. Quem não quiser assistir tem o botão Pular.
  late final AnimationController _filme = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _duracao.toInt()),
    animationBehavior: AnimationBehavior.preserve,
  );
  late final AnimationController _saida = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
    animationBehavior: AnimationBehavior.preserve,
  );
  Timer? _limiteCarga;
  bool _carregou = false;
  bool _saindo = false;

  @override
  void initState() {
    super.initState();
    _filme.addStatusListener((s) {
      if (s == AnimationStatus.completed) _sair();
    });
    _saida.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    // Como no HTML: espera os frames decodificarem, mas nunca mais que 1,8 s.
    _limiteCarga = Timer(const Duration(milliseconds: 1800), _comecar);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_carregou) return;
    _carregou = true;
    Future.wait([
      for (var i = 0; i < IntroScreen.frames; i++)
        precacheImage(AssetImage(IntroScreen.frame(i)), context),
    ]).whenComplete(_comecar);
  }

  void _comecar() {
    _limiteCarga?.cancel();
    if (mounted && !_saindo && !_filme.isAnimating && _filme.value == 0) _filme.forward();
  }

  void _sair({bool rapido = false}) {
    if (_saindo) return;
    _saindo = true;
    _limiteCarga?.cancel();
    _filme.stop();
    if (rapido) _saida.duration = const Duration(milliseconds: 450);
    _saida.forward();
  }

  @override
  void dispose() {
    _limiteCarga?.cancel();
    _filme.dispose();
    _saida.dispose();
    super.dispose();
  }

  /// Progresso de 0 a 1 de um trecho que começa em [inicio] e dura [duracao] ms.
  static double _p(double ms, double inicio, double duracao, [Curve curva = Curves.linear]) =>
      curva.transform(((ms - inicio) / duracao).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => AnimatedBuilder(
        animation: Listenable.merge([_filme, _saida]),
        builder: (context, _) => FractionalTranslation(
          translation: Offset(0, -1.01 * _saidaCurva.transform(_saida.value)),
          child: _cena(c.maxWidth, c.maxHeight, _filme.value * _duracao),
        ),
      ),
    );
  }

  Widget _cena(double w, double h, double ms) {
    final larguraFilme = math.min(w, h * .4644);
    final cx = w / 2;
    final cy = h * .545;
    final raio = math.sqrt(cx * cx + math.max(cy, h - cy) * math.max(cy, h - cy));
    final tamanhoFlood = raio * 2 + 60;
    final escalaInicial = math.min(larguraFilme * 1.05, h * .62) / tamanhoFlood;
    final disco = math.min(w * .88, h * .62);

    return Material(
      color: const Color(0xFFF7F8F3),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(child: CustomPaint(painter: _GradePainter())),
          Positioned(
            left: cx - disco / 2,
            top: h * .44 - disco / 2,
            width: disco,
            height: disco,
            child: Transform.scale(
              scale: _p(ms, 0, 900, _sobe),
              child: const DecoratedBox(
                decoration: BoxDecoration(color: AppColors.ball, shape: BoxShape.circle),
              ),
            ),
          ),
          _palavras(w, h, ms),
          _filmeSaque(w, h, larguraFilme, ms),
          if (ms >= _impacto && ms < _impacto + 280)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white.withValues(alpha: .85 * (1 - _p(ms, _impacto, 280))),
              ),
            ),
          Positioned.fill(child: _Hud(ms: ms, frame: _frameEm(ms))),
          if (ms >= _flood)
            Positioned(
              left: cx - tamanhoFlood / 2,
              top: cy - tamanhoFlood / 2,
              width: tamanhoFlood,
              height: tamanhoFlood,
              child: Transform.scale(
                scale: escalaInicial + (1 - escalaInicial) * _p(ms, _flood, 800, _floodCurva),
                child: const DecoratedBox(
                  decoration: BoxDecoration(color: AppColors.ball, shape: BoxShape.circle),
                ),
              ),
            ),
          if (ms >= _marca)
            Positioned.fill(
              child: CustomPaint(
                painter: _CosturaPainter(_p(ms, _marca, 1000, const Cubic(.6, 0, .2, 1))),
              ),
            ),
          if (ms >= _marca) Positioned.fill(child: _marcaAce(w, h, ms)),
          Positioned(
            right: 20,
            bottom: 46,
            child: GestureDetector(
              key: const Key('intro-pular'),
              onTap: () => _sair(rapido: true),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.greenDark,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'PULAR ▸',
                  style: AppTheme.mono(
                    size: 11,
                    weight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _frameEm(double ms) {
    var i = 0;
    for (var k = 0; k < _trocas.length; k++) {
      if (ms >= _trocas[k]) i = k;
    }
    return i;
  }

  Widget _filmeSaque(double w, double h, double largura, double ms) {
    final i = _frameEm(ms);
    // Tremor de 220 ms no impacto, com os mesmos deslocamentos do HTML.
    var tremor = Offset.zero;
    if (ms >= _impacto && ms < _impacto + 220) {
      const passos = [Offset(-7, 4), Offset(6, -5), Offset(-3, 2), Offset.zero];
      tremor = passos[((ms - _impacto) / 55).floor().clamp(0, 3)];
    }
    Widget imagem = Transform.scale(
      scale: 1 + i * .016,
      alignment: const Alignment(0, .1),
      child: Image.asset(
        IntroScreen.frame(i),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: largura,
        height: h,
      ),
    );
    if (w / h >= 3 / 4) {
      imagem = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
          colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
          stops: [0, .09, .91, 1],
        ).createShader(r),
        child: imagem,
      );
    }
    return Positioned(
      left: (w - largura) / 2 + tremor.dx,
      top: tremor.dy,
      width: largura,
      height: h,
      child: imagem,
    );
  }

  /// "RESERVE" em contorno e "sua quadra" em serifa: entram letra a letra e saem no impacto.
  Widget _palavras(double w, double h, double ms) {
    double desloc(int k) {
      if (ms >= _impacto) return -1.1 * _p(ms, _impacto + k * 18, 500, const Cubic(.6, 0, .9, .4));
      return 1.05 * (1 - _p(ms, k * 45, 700, _sobe));
    }

    double opac(int k) => ms >= _impacto ? 1 - _p(ms, _impacto + k * 18, 500) : 1;

    Widget linha(String texto, TextStyle Function() estilo) => FittedBox(
          fit: BoxFit.scaleDown,
          child: ClipRect(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var k = 0; k < texto.length; k++)
                  Opacity(
                    opacity: opac(k),
                    child: FractionalTranslation(
                      translation: Offset(0, desloc(k)),
                      child: Text(texto[k], style: estilo()),
                    ),
                  ),
              ],
            ),
          ),
        );

    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: h * .12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            linha(
              'RESERVE',
              () => AppTheme.display(
                size: math.min(w * .27, h * .5),
                color: Colors.transparent,
                letterSpacing: 0,
                height: .8,
              ).copyWith(
                color: null,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2.5
                  ..color = AppColors.green,
              ),
            ),
            linha(
              'sua quadra',
              () => AppTheme.serif(size: math.min(w * .2, h * .22), color: AppColors.greenDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _marcaAce(double w, double h, double ms) {
    final tamanho = math.min(w * .38, h * .5);
    Widget letra(String l, int k, Color cor) => FractionalTranslation(
          translation: Offset(0, 1.1 * (1 - _p(ms, _marca + k * 70, 750, _sobe))),
          child: Text(
            l,
            style: AppTheme.display(size: tamanho, color: cor, letterSpacing: 0, height: .8),
          ),
        );
    final legenda = _p(ms, _marca + 450, 600, _sobe);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRect(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  letra('A', 0, AppColors.greenDark),
                  letra('C', 1, AppColors.greenDark),
                  letra('E', 2, AppColors.greenDark),
                  letra('.', 3, AppColors.green),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Opacity(
            opacity: legenda,
            child: Transform.translate(
              offset: Offset(0, 10 * (1 - legenda)),
              child: Text(
                'RESERVA DE QUADRAS',
                style: AppTheme.mono(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.greenDark,
                  letterSpacing: 3.9,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cantos, "REC" com timecode, contador de frames e legenda, como um visor de câmera.
class _Hud extends StatelessWidget {
  const _Hud({required this.ms, required this.frame});

  final double ms;
  final int frame;

  @override
  Widget build(BuildContext context) {
    final estilo = AppTheme.mono(
      size: 11,
      weight: FontWeight.w600,
      color: AppColors.greenDark,
      letterSpacing: 1.5,
    );
    final s = ms ~/ 1000;
    final f = ((ms % 1000) / 33.3).floor();
    String dois(int n) => n.toString().padLeft(2, '0');
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _CantosPainter())),
          Positioned(
            left: 20,
            top: 18,
            child: Row(
              children: [
                Opacity(
                  opacity: (ms ~/ 500).isEven ? 1 : 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 10),
                Text('REC 00:${dois(s)}:${dois(f)}', style: estilo),
              ],
            ),
          ),
          Positioned(
            right: 20,
            top: 18,
            child: Text('FRAME 0${frame + 1}/08', style: estilo),
          ),
          Positioned(
            left: 20,
            bottom: 18,
            child: Text('ACE SAIBRO · BACKHAND ×0.25', style: estilo),
          ),
        ],
      ),
    );
  }
}

class _GradePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linha = Paint()
      ..color = const Color(0xCCE6ECE4)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 64) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linha);
    }
    for (double x = 0; x < size.width; x += 64) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linha);
    }
  }

  @override
  bool shouldRepaint(_GradePainter oldDelegate) => false;
}

class _CantosPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const m = 14.0;
    const l = 26.0;
    final p = Paint()
      ..color = AppColors.greenDark
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(m, m + l)
        ..lineTo(m, m)
        ..lineTo(m + l, m)
        ..moveTo(w - m - l, m)
        ..lineTo(w - m, m)
        ..lineTo(w - m, m + l)
        ..moveTo(m, h - m - l)
        ..lineTo(m, h - m)
        ..lineTo(m + l, h - m)
        ..moveTo(w - m - l, h - m)
        ..lineTo(w - m, h - m)
        ..lineTo(w - m, h - m - l),
      p,
    );
  }

  @override
  bool shouldRepaint(_CantosPainter oldDelegate) => false;
}

/// A costura branca da bola, desenhada aos poucos sobre o flood (`i-seam` no HTML).
class _CosturaPainter extends CustomPainter {
  _CosturaPainter(this.progresso);

  final double progresso;

  @override
  void paint(Canvas canvas, Size size) {
    // viewBox 100×100 com preserveAspectRatio "slice": escala pelo maior lado.
    final escala = math.max(size.width, size.height) / 100;
    canvas.save();
    canvas.translate((size.width - 100 * escala) / 2, (size.height - 100 * escala) / 2);
    canvas.scale(escala);
    final caminho = Path()
      ..moveTo(-8, 80)
      ..cubicTo(24, 14, 64, 112, 108, 20);
    final tinta = Paint()
      ..color = Colors.white.withValues(alpha: .92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    for (final parte in caminho.computeMetrics()) {
      canvas.drawPath(parte.extractPath(0, parte.length * progresso), tinta);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CosturaPainter oldDelegate) => oldDelegate.progresso != progresso;
}
