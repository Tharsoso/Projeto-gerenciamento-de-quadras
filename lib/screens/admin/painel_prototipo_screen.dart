import 'package:flutter/material.dart';

class PainelPrototipoScreen extends StatelessWidget {
  const PainelPrototipoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final itens = <_ItemMenu>[
      _ItemMenu(Icons.sports_tennis, 'Quadras', 'Cadastro e inativação (H8)'),
      _ItemMenu(Icons.schedule, 'Horários de funcionamento', 'Abertura e fechamento (H9)'),
      _ItemMenu(Icons.attach_money, 'Preços por faixa', 'Dia útil / fim de semana (H4)'),
      _ItemMenu(Icons.event_busy, 'Bloqueios', 'Manutenção da quadra (H5)'),
      _ItemMenu(Icons.event_available, 'Reservas', 'Consulta e cancelamento (H11, H3)'),
      _ItemMenu(Icons.insert_chart_outlined, 'Faturamento', 'Relatório por período (H12)'),
      _ItemMenu(Icons.beach_access, 'Feriados', 'Calendário anual'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do proprietário'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (ctx, c) {
        final colunas = c.maxWidth > 900 ? 3 : (c.maxWidth > 560 ? 2 : 1);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: colunas,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.4,
            ),
            itemCount: itens.length,
            itemBuilder: (_, i) => _CardMenu(item: itens[i]),
          ),
        );
      }),
    );
  }
}

class _ItemMenu {
  final IconData icone;
  final String titulo;
  final String descricao;
  _ItemMenu(this.icone, this.titulo, this.descricao);
}

class _CardMenu extends StatelessWidget {
  final _ItemMenu item;
  const _CardMenu({required this.item});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${item.titulo}: tela a ser implementada.')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(item.icone, color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.titulo,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(item.descricao,
                        style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
