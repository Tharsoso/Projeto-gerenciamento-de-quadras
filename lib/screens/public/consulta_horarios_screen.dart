import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_theme.dart';
import '../../formatos.dart';
import '../../models/horario_slot.dart';
import '../../publico/reservas_repositorio.dart';
import '../../services/quadras_service.dart';
import '../intro_screen.dart';
import '../widgets/tennis_ball.dart';

class ConsultaHorariosScreen extends StatefulWidget {
  /// [servico] permite injetar o acesso aos dados (testes). Sem ele, usa o Supabase
  /// inicializado; se não houver Supabase, a tela abre sem horários.
  const ConsultaHorariosScreen({super.key, this.servico});

  final QuadrasService? servico;

  @override
  State<ConsultaHorariosScreen> createState() => _ConsultaHorariosScreenState();
}

class _ConsultaHorariosScreenState extends State<ConsultaHorariosScreen> {
  late final QuadrasService? _service;
  DateTime _dia = _hoje();

  static QuadrasService? _servicoPadrao() {
    try {
      return QuadrasService(Supabase.instance.client);
    } catch (_) {
      return null;
    }
  }
  Future<List<HorarioSlot>>? _future;
  RealtimeChannel? _canal;

  static DateTime _hoje() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _service = widget.servico ?? _servicoPadrao();
    _recarregar();
    _canal = _service?.assinarOcupacoes(_recarregar);
  }

  @override
  void dispose() {
    final c = _canal;
    if (c != null) {
      Supabase.instance.client.removeChannel(c);
    }
    super.dispose();
  }

  void _recarregar() {
    if (!mounted) return;
    final f = _service?.horariosDoDia(_dia) ?? Future.value(<HorarioSlot>[]);
    setState(() {
      _future = f;
    });
  }

  Future<void> _escolherData() async {
    final hoje = _hoje();
    final d = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: hoje,
      lastDate: hoje.add(const Duration(days: 90)),
      locale: const Locale('pt', 'BR'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.green,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (d != null) {
      setState(() => _dia = DateTime(d.year, d.month, d.day));
      _recarregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: () async => _recarregar(),
        color: AppColors.green,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _AppBar(onLogin: _goLogin)),
            SliverToBoxAdapter(child: _Hero()),
            SliverToBoxAdapter(child: const _Ticker()),
            SliverToBoxAdapter(
              child: _DateBar(
                dia: _dia,
                onHoje: () {
                  setState(() => _dia = _hoje());
                  _recarregar();
                },
                onTrocar: _escolherData,
                onPrev: () {
                  final hoje = _hoje();
                  final n = _dia.subtract(const Duration(days: 1));
                  if (!n.isBefore(hoje)) {
                    setState(() => _dia = n);
                    _recarregar();
                  }
                },
                onNext: () {
                  setState(() => _dia = _dia.add(const Duration(days: 1)));
                  _recarregar();
                },
              ),
            ),
            FutureBuilder<List<HorarioSlot>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.green),
                    ),
                  );
                }
                if (snap.hasError) {
                  return SliverToBoxAdapter(
                    child: _Erro(
                      mensagem: snap.error.toString(),
                      onTentar: _recarregar,
                    ),
                  );
                }
                final slots = snap.data ?? const [];
                if (slots.isEmpty) {
                  return const SliverToBoxAdapter(child: _Vazio());
                }
                final porQuadra = <String, List<HorarioSlot>>{};
                for (final s in slots) {
                  porQuadra.putIfAbsent(s.quadraNome, () => []).add(s);
                }
                final entries = porQuadra.entries.toList();
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  sliver: SliverList.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _CardQuadra(
                      nome: entries[i].key,
                      slots: entries[i].value,
                      dia: _dia,
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: _Legenda()),
            SliverToBoxAdapter(child: _Footer()),
          ],
        ),
      ),
    );
  }

  void _goLogin() => context.go('/login');
}

class _AppBar extends StatelessWidget {
  final VoidCallback onLogin;
  const _AppBar({required this.onLogin});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          const TennisBall(size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Reserva de quadras',
                  style: AppTheme.display(
                    size: 22,
                    letterSpacing: 1,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ACE SAIBRO · AO VIVO',
                  style: AppTheme.mono(
                    size: 10,
                    color: AppColors.muted,
                    letterSpacing: 2.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line, width: 1.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.person_outline, color: AppColors.ink),
              onPressed: onLogin,
              tooltip: 'Área do proprietário',
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final narrow = w < 900;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      child: Flex(
        direction: narrow ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Flexivel(
            narrow: narrow,
            flex: 13,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _PulseDot(),
                    const SizedBox(width: 10),
                    Text(
                      'AGENDA AO VIVO · AMERICA/SÃO PAULO',
                      style: AppTheme.mono(
                        size: 12,
                        color: AppColors.green,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Reserve',
                  style: AppTheme.display(
                    size: (w * 0.12).clamp(60, 150),
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  'sua quadra',
                  style: AppTheme.serif(
                    size: (w * 0.095).clamp(44, 110),
                    color: AppColors.green,
                  ),
                ),
                Text(
                  'EM SEGUNDOS',
                  style: AppTheme.display(
                    size: (w * 0.07).clamp(32, 80),
                    color: Colors.transparent,
                    letterSpacing: 2,
                  ).copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2
                      ..color = AppColors.green,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Text(
                    'Escolha o dia, toque no horário verde e confirme com nome e telefone. Sem cadastro, sem senha — só jogo.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.muted,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20, height: 20),
          _Flexivel(
            narrow: narrow,
            flex: 7,
            child: Align(
              alignment: narrow ? Alignment.center : Alignment.centerRight,
              child: _HeroCard(),
            ),
          ),
        ],
      ),
    );
  }
}

/// `Expanded` só vale no layout horizontal; na coluna (tela estreita, altura livre) quebraria.
class _Flexivel extends StatelessWidget {
  const _Flexivel({required this.narrow, required this.flex, required this.child});

  final bool narrow;
  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      narrow ? child : Expanded(flex: flex, child: child);
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.025,
      child: Container(
        width: 300,
        height: 420,
        decoration: BoxDecoration(
          color: AppColors.green,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppColors.greenDark.withValues(alpha: 0.3),
              offset: const Offset(0, 18),
              blurRadius: 40,
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _CourtLinesPainter()),
            Align(
              alignment: const Alignment(0, -.12),
              child: Container(
                width: 276,
                height: 276,
                decoration: const BoxDecoration(
                  color: AppColors.ball,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const Positioned(
              left: 41,
              bottom: -8,
              width: 218,
              height: 470,
              child: _SaqueEmLoop(),
            ),
            Positioned(
              left: 16,
              top: 14,
              child: Text(
                '● BACKHAND · 0.25×',
                style: AppTheme.mono(
                  size: 10,
                  color: Colors.white,
                  letterSpacing: 2.2,
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 14,
              child: Text(
                'ACE SAIBRO',
                style: AppTheme.mono(
                  size: 10,
                  color: AppColors.ball,
                  letterSpacing: 2.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Os 5 primeiros frames do saque em loop, com os tempos do `startHeroLoop` do HTML.
class _SaqueEmLoop extends StatefulWidget {
  const _SaqueEmLoop();

  @override
  State<_SaqueEmLoop> createState() => _SaqueEmLoopState();
}

class _SaqueEmLoopState extends State<_SaqueEmLoop> {
  static const _tempos = [1100, 240, 200, 170, 800];
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _agendar();
  }

  void _agendar() {
    _timer = Timer(Duration(milliseconds: _tempos[_i]), () {
      setState(() => _i = (_i + 1) % _tempos.length);
      _agendar();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Image.asset(IntroScreen.frame(_i), gaplessPlayback: true, fit: BoxFit.contain);
}

class _CourtLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final r = Rect.fromLTRB(
      size.width * 0.08,
      size.height * 0.08,
      size.width * 0.92,
      size.height * 0.92,
    );
    canvas.drawRect(r, p);
    canvas.drawLine(
      Offset(r.left, r.center.dy),
      Offset(r.right, r.center.dy),
      p,
    );
    canvas.drawLine(
      Offset(r.center.dx, r.top + r.height * 0.2),
      Offset(r.center.dx, r.bottom - r.height * 0.2),
      p,
    );
    canvas.drawLine(
      Offset(r.left + 24, r.top),
      Offset(r.left + 24, r.bottom),
      p,
    );
    canvas.drawLine(
      Offset(r.right - 24, r.top),
      Offset(r.right - 24, r.bottom),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        return SizedBox(
          width: 20,
          height: 20,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 9 + 20 * t,
                height: 9 + 20 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.red.withValues(alpha: (1 - t) * 0.5),
                ),
              ),
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Ticker extends StatefulWidget {
  const _Ticker();
  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const items = [
      'SAIBRO',
      'DURA',
      'GRAMA',
      'SINTÉTICA',
      '07:00 → 22:00',
      'RESERVA EM 1 MINUTO',
      'SEM CADASTRO',
    ];
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < items.length * 2; i++) ...[
          Text(
            items[i % items.length],
            style: AppTheme.display(
              size: 28,
              color: i.isEven ? AppColors.ball : Colors.transparent,
              letterSpacing: 2,
            ).copyWith(
              foreground: i.isOdd
                  ? (Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.5
                    ..color = AppColors.ball)
                  : null,
            ),
          ),
          const SizedBox(width: 22),
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppColors.ball,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 22),
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.greenDark,
        border: Border.symmetric(horizontal: BorderSide(color: Colors.black)),
      ),
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        height: 36,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => OverflowBox(
            maxWidth: double.infinity,
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(-_c.value * 1200, 0),
              child: child,
            ),
          ),
          child: row,
        ),
      ),
    );
  }
}

class _DateBar extends StatelessWidget {
  final DateTime dia;
  final VoidCallback onHoje;
  final VoidCallback onTrocar;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _DateBar({
    required this.dia,
    required this.onHoje,
    required this.onTrocar,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    const dows = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];
    const mons = [
      'JAN',
      'FEV',
      'MAR',
      'ABR',
      'MAI',
      'JUN',
      'JUL',
      'AGO',
      'SET',
      'OUT',
      'NOV',
      'DEZ',
    ];
    final diaSemana = dows[dia.weekday % 7];
    final mes = mons[dia.month - 1];
    final hoje = DateTime.now();
    final isPast = dia.isBefore(DateTime(hoje.year, hoje.month, hoje.day));
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.greenDark,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.greenDark.withValues(alpha: 0.28),
            offset: const Offset(0, 18),
            blurRadius: 40,
          ),
        ],
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Arrow(icon: '‹', onTap: isPast ? null : onPrev),
              const SizedBox(width: 10),
              Text(
                dia.day.toString().padLeft(2, '0'),
                style: AppTheme.display(
                  size: 96,
                  color: AppColors.ball,
                  height: 0.8,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    diaSemana,
                    style: AppTheme.display(
                      size: 36,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$mes ${dia.year}',
                    style: AppTheme.mono(
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              _Arrow(icon: '›', onTap: onNext),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniBtn(
                label: 'HOJE',
                bg: AppColors.ball,
                fg: AppColors.ink,
                onTap: onHoje,
              ),
              const SizedBox(width: 10),
              _MiniBtn(
                label: '📅 TROCAR DATA',
                bg: Colors.transparent,
                fg: Colors.white,
                border: true,
                onTap: onTrocar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  final String icon;
  final VoidCallback? onTap;
  const _Arrow({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.25 : 1,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Text(
            icon,
            style: const TextStyle(color: Colors.white, fontSize: 28, height: 1),
          ),
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final bool border;
  final VoidCallback onTap;
  const _MiniBtn({
    required this.label,
    required this.bg,
    required this.fg,
    this.border = false,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: border
              ? Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5)
              : null,
        ),
        child: Text(
          label,
          style: AppTheme.mono(
            size: 12,
            color: fg,
            letterSpacing: 1.4,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CardQuadra extends StatelessWidget {
  final String nome;
  final List<HorarioSlot> slots;
  final DateTime dia;
  const _CardQuadra({required this.nome, required this.slots, required this.dia});

  @override
  Widget build(BuildContext context) {
    final piso = slots.first.tipoPiso;
    final livres = slots.where((s) => s.livre).length;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      nome.toUpperCase(),
                      style: AppTheme.display(
                        size: 44,
                        color: AppColors.ink,
                        letterSpacing: 0.5,
                        height: 0.9,
                      ),
                    ),
                    _PisoChip(piso: piso),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$livres',
                    style: AppTheme.display(
                      size: 40,
                      color: AppColors.green,
                      letterSpacing: 0,
                      height: 0.9,
                    ),
                  ),
                  Text(
                    'LIVRES',
                    style: AppTheme.mono(
                      size: 11,
                      color: AppColors.muted,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: slots
                .map((s) => _SlotChip(slot: s, dia: dia, quadra: nome))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PisoChip extends StatelessWidget {
  final String piso;
  const _PisoChip({required this.piso});
  @override
  Widget build(BuildContext context) {
    const bgs = {
      'saibro': Color(0xFFFBE9E0),
      'dura': Color(0xFFE3EBF6),
      'grama': Color(0xFFE4F2D8),
      'sintetica': Color(0xFFEDE7F6),
    };
    const fgs = {
      'saibro': Color(0xFFA4400F),
      'dura': Color(0xFF1F4E8C),
      'grama': Color(0xFF2F6B12),
      'sintetica': Color(0xFF5B3FA0),
    };
    final color = fgs[piso] ?? AppColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgs[piso] ?? AppColors.greenTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            piso[0].toUpperCase() + piso.substring(1),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  final HorarioSlot slot;
  final DateTime dia;
  final String quadra;
  const _SlotChip({required this.slot, required this.dia, required this.quadra});

  @override
  Widget build(BuildContext context) {
    final cfg = _config(slot.status);
    final preco = slot.valor != null
        ? formatarReal(slot.valor!)
        : '—';
    final isLivre = slot.livre;
    return InkWell(
      onTap: isLivre
          ? () => context.push(
                '/reserva',
                extra: HorarioEscolhido(
                  quadraId: slot.quadraId,
                  quadra: quadra,
                  data: dia,
                  hora: slot.horaInicio,
                  valor: slot.valor,
                ),
              )
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 92,
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isLivre ? AppColors.green : cfg.$1.withValues(alpha: 0.1),
          border: Border.all(
            color: isLivre ? Colors.transparent : cfg.$1.withValues(alpha: 0.3),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLivre
              ? [
                  const BoxShadow(
                    color: AppColors.greenDark,
                    offset: Offset(0, 2),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              slot.horaInicio,
              style: AppTheme.mono(
                size: 17,
                color: isLivre ? Colors.white : cfg.$1,
                weight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isLivre ? preco : cfg.$2,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isLivre ? AppColors.ball : cfg.$1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  (Color, String) _config(String s) {
    switch (s) {
      case 'livre':
        return (AppColors.green, 'Livre');
      case 'reservado':
        return (AppColors.red, 'Reservado');
      case 'bloqueado':
        return (AppColors.brown, 'Bloqueado');
      case 'passado':
        return (AppColors.gray, 'Passou');
      case 'sem_preco':
        return (AppColors.orange, 'Sem preço');
      default:
        return (AppColors.muted, s);
    }
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda();
  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            const SizedBox(width: 8),
            Text(t,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 10,
        children: [
          item(AppColors.green, 'Livre'),
          item(AppColors.redTint, 'Reservado'),
          item(AppColors.brownTint, 'Bloqueado'),
          item(AppColors.grayTint, 'Passou'),
          item(AppColors.orangeTint, 'Sem preço'),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 60),
      color: AppColors.greenDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bora\njogar.',
            style: AppTheme.display(
              size: (MediaQuery.sizeOf(context).width * 0.12).clamp(60, 140),
              color: AppColors.ball,
              height: 0.8,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ACE SAIBRO · CSI405 UFOP 2026/2\nRESERVAS DE 1 HORA · MÁX. 2 POR DIA POR TELEFONE\nDADOS ANONIMIZADOS APÓS 12 MESES (LGPD)',
            style: AppTheme.mono(
              size: 11,
              color: Colors.white.withValues(alpha: 0.65),
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              const TennisBall(size: 60),
              const SizedBox(height: 16),
              Text(
                'FECHADA NESTE DIA',
                style: AppTheme.display(
                  size: 32,
                  color: AppColors.ink,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nenhuma quadra funciona neste dia da semana. Escolha outra data.',
                style: TextStyle(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _Erro extends StatelessWidget {
  final String mensagem;
  final VoidCallback onTentar;
  const _Erro({required this.mensagem, required this.onTentar});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 48, color: AppColors.red),
              const SizedBox(height: 12),
              Text(
                'Erro ao carregar',
                style: AppTheme.display(
                  size: 32,
                  color: AppColors.ink,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onTentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
}
