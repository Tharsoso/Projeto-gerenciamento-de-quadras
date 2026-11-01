import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../widgets/tennis_ball.dart';

class PainelPrototipoScreen extends StatelessWidget {
  const PainelPrototipoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hr = DateTime.now().hour;
    final saud = hr < 12 ? 'Bom dia' : hr < 18 ? 'Boa tarde' : 'Boa noite';
    final itens = <_Mod>[
      _Mod(Icons.sports_tennis, 'QUADRAS', 'Cadastro e inativação (H8)', 'Quadras ativas'),
      _Mod(Icons.schedule, 'HORÁRIOS', 'Abertura e fechamento (H9)', 'Seg a Dom'),
      _Mod(Icons.attach_money, 'PREÇOS', 'Dia útil / fim de semana (H4)', 'Faixas'),
      _Mod(Icons.event_busy, 'BLOQUEIOS', 'Manutenção da quadra (H5)', 'Horários'),
      _Mod(Icons.event_available, 'RESERVAS', 'Consulta e cancelamento (H11, H3)', 'Hoje'),
      _Mod(Icons.insert_chart_outlined, 'FATURAMENTO', 'Relatório por período (H12)', 'No mês'),
      _Mod(Icons.beach_access, 'FERIADOS', 'Calendário anual', 'Em 2026'),
    ];
    return Scaffold(
      backgroundColor: AppColors.surf,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _AppBar()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_dia()} · ${_dataBr()}',
                          style: AppTheme.mono(
                            size: 12,
                            color: AppColors.green,
                            letterSpacing: 2.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$saud,',
                      style: AppTheme.display(
                        size: 72,
                        color: AppColors.ink,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'proprietário.',
                      style: AppTheme.serif(
                        size: 56,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              sliver: SliverLayoutBuilder(
                builder: (ctx, c) {
                  final cols = c.crossAxisExtent > 900
                      ? 3
                      : c.crossAxisExtent > 600
                          ? 2
                          : 1;
                  return SliverGrid.builder(
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: cols == 1 ? 2.2 : 1.35,
                    ),
                    itemCount: itens.length + 1,
                    itemBuilder: (_, i) {
                      if (i == itens.length) return _InfoCard();
                      return _ModCard(item: itens[i], index: i + 1);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dia() {
    const n = ['DOMINGO', 'SEGUNDA', 'TERÇA', 'QUARTA', 'QUINTA', 'SEXTA', 'SÁBADO'];
    return n[DateTime.now().weekday % 7];
  }

  String _dataBr() {
    final d = DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: AppColors.greenDark,
      child: Row(
        children: [
          const TennisBall(size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'PAINEL DO PROPRIETÁRIO',
              style: AppTheme.display(
                size: 20,
                color: Colors.white,
                letterSpacing: 1.5,
                height: 1,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (_) => false,
            ),
          ),
        ],
      ),
    );
  }
}

class _Mod {
  final IconData icone;
  final String titulo;
  final String descricao;
  final String rodape;
  _Mod(this.icone, this.titulo, this.descricao, this.rodape);
}

class _ModCard extends StatefulWidget {
  final _Mod item;
  final int index;
  const _ModCard({required this.item, required this.index});
  @override
  State<_ModCard> createState() => _ModCardState();
}

class _ModCardState extends State<_ModCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final palette = widget.index % 3;
    final bubBg = palette == 0
        ? AppColors.greenTint
        : palette == 1
            ? const Color(0xFFFBF9C4)
            : const Color(0xFFFBE9E0);
    final bubFg = palette == 0
        ? AppColors.green
        : palette == 1
            ? const Color(0xFF6B6A00)
            : AppColors.clay;
    final hovered = _hover;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: hovered ? AppColors.green : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.line),
          boxShadow: hovered
              ? [
                  BoxShadow(
                    color: AppColors.greenDark.withValues(alpha: 0.3),
                    offset: const Offset(0, 18),
                    blurRadius: 40,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.item.titulo}: tela a ser implementada.'),
              backgroundColor: AppColors.ink,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 14,
                top: -8,
                child: Text(
                  widget.index.toString().padLeft(2, '0'),
                  style: AppTheme.display(
                    size: 130,
                    color: Colors.transparent,
                    letterSpacing: 0,
                  ).copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2
                      ..color = hovered
                          ? AppColors.ball.withValues(alpha: 0.5)
                          : AppColors.greenTint2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: hovered ? AppColors.ball : bubBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        widget.item.icone,
                        color: hovered ? AppColors.greenDark : bubFg,
                        size: 30,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.item.titulo,
                      style: AppTheme.display(
                        size: 32,
                        color: hovered ? Colors.white : AppColors.ink,
                        letterSpacing: 0.5,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.item.descricao,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: hovered
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          widget.item.rodape.toUpperCase(),
                          style: AppTheme.mono(
                            size: 11,
                            color: hovered ? AppColors.ball : AppColors.green,
                            letterSpacing: 1.4,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        AnimatedSlide(
                          duration: const Duration(milliseconds: 220),
                          offset: hovered ? const Offset(0.3, 0) : Offset.zero,
                          child: Icon(
                            Icons.chevron_right,
                            color: hovered ? AppColors.ball : AppColors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.greenDark,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REGRAS DO SISTEMA',
            style: AppTheme.display(
              size: 28,
              color: AppColors.ball,
              letterSpacing: 1,
              height: 0.9,
            ),
          ),
          const SizedBox(height: 10),
          for (final t in const [
            'Reservas de 1 hora cheia (07:00, 08:00…)',
            'Máx. 2 reservas/dia por telefone',
            'Reserva sem login: nome + telefone',
            'Fim de semana vale em feriados',
            'Dados anonimizados após 12 meses (LGPD)',
            'Fuso America/São Paulo',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· $t',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
