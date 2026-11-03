import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_theme.dart';
import '../auth/autenticacao.dart';
import '../screens/widgets/tennis_ball.dart';

/// Painel do proprietário. Visual do protótipo Ace Saibro: cards numerados dos módulos.
/// Módulos sem rota aparecem como "Em breve" até a atividade deles (5.x) entrar.
class PainelPage extends StatelessWidget {
  const PainelPage({super.key, required this.auth});

  final Autenticacao auth;

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final saudacao = agora.hour < 12 ? 'Bom dia' : agora.hour < 18 ? 'Boa tarde' : 'Boa noite';
    final modulos = <_Modulo>[
      _Modulo(Icons.sports_tennis, 'QUADRAS', 'Cadastro, edição e inativação das quadras.',
          chave: const Key('painel-quadras'), rota: '/admin/quadras'),
      _Modulo(Icons.schedule, 'HORÁRIOS', 'Abertura e fechamento por dia da semana.',
          chave: const Key('painel-horarios'), rota: '/admin/horarios'),
      _Modulo(Icons.attach_money, 'PREÇOS', 'Valores de dia útil e fim de semana.',
          chave: const Key('painel-precos'), rota: '/admin/precos'),
      _Modulo(Icons.event_busy, 'BLOQUEIOS', 'Reserve horários para manutenção.',
          chave: const Key('painel-bloqueios'), rota: '/admin/bloqueios'),
      const _Modulo(Icons.event_available, 'RESERVAS', 'Veja, filtre e cancele reservas.'),
      const _Modulo(Icons.insert_chart_outlined, 'FATURAMENTO', 'Relatório por período.'),
      _Modulo(Icons.beach_access, 'FERIADOS', 'Calendário anual de feriados.',
          chave: const Key('painel-feriados'), rota: '/admin/feriados'),
    ];

    return Scaffold(
      backgroundColor: AppColors.surf,
      appBar: AppBar(
        backgroundColor: AppColors.greenDark,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const TennisBall(size: 30),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Painel do proprietário',
                overflow: TextOverflow.ellipsis,
                style: AppTheme.display(
                  size: 22,
                  color: Colors.white,
                  letterSpacing: 1.5,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('painel-sair'),
            tooltip: 'Sair',
            onPressed: auth.sair,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                _dataExtenso(agora),
                style: AppTheme.mono(size: 12, color: AppColors.green, letterSpacing: 2.4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('$saudacao,',
              style: AppTheme.display(size: 64, color: AppColors.ink, letterSpacing: 0.5)),
          Text('proprietário.', style: AppTheme.serif(size: 52, color: AppColors.green)),
          const SizedBox(height: 14),
          const Text(
            'Agenda do dia (em construção)',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final colunas = c.maxWidth > 900 ? 3 : c.maxWidth > 560 ? 2 : 1;
              final largura = (c.maxWidth - 14 * (colunas - 1)) / colunas;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (var i = 0; i < modulos.length; i++)
                    SizedBox(
                      width: largura,
                      child: _CartaoModulo(modulo: modulos[i], numero: i + 1),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _dataExtenso(DateTime d) {
    const dias = ['DOMINGO', 'SEGUNDA', 'TERÇA', 'QUARTA', 'QUINTA', 'SEXTA', 'SÁBADO'];
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dias[d.weekday % 7]} · ${dois(d.day)}/${dois(d.month)}/${d.year}';
  }
}

class _Modulo {
  const _Modulo(this.icone, this.titulo, this.descricao, {this.chave, this.rota});

  final IconData icone;
  final String titulo;
  final String descricao;
  final Key? chave;

  /// Sem rota, o módulo ainda não existe e aparece como "Em breve".
  final String? rota;
}

class _CartaoModulo extends StatelessWidget {
  const _CartaoModulo({required this.modulo, required this.numero});

  final _Modulo modulo;
  final int numero;

  @override
  Widget build(BuildContext context) {
    final ativo = modulo.rota != null;
    final cartao = Container(
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.line),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: -8,
            child: Text(
              numero.toString().padLeft(2, '0'),
              style: AppTheme.display(size: 96, color: Colors.transparent, height: 1).copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2
                  ..color = AppColors.greenTint2,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.greenTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(modulo.icone, color: AppColors.green, size: 30),
              ),
              const SizedBox(height: 28),
              Text(modulo.titulo,
                  style: AppTheme.display(size: 32, color: AppColors.ink, height: 0.9)),
              const SizedBox(height: 6),
              Text(modulo.descricao,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14)),
              const SizedBox(height: 10),
              Text(
                ativo ? 'ABRIR' : 'EM BREVE',
                style: AppTheme.mono(
                  size: 12,
                  weight: FontWeight.w600,
                  color: ativo ? AppColors.green : AppColors.gray,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (!ativo) return Opacity(opacity: 0.6, child: cartao);
    return InkWell(
      key: modulo.chave,
      borderRadius: BorderRadius.circular(30),
      onTap: () => context.go(modulo.rota!),
      child: cartao,
    );
  }
}
