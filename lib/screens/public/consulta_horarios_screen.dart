import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/horario_slot.dart';
import '../../services/quadras_service.dart';

class ConsultaHorariosScreen extends StatefulWidget {
  const ConsultaHorariosScreen({super.key});

  @override
  State<ConsultaHorariosScreen> createState() => _ConsultaHorariosScreenState();
}

class _ConsultaHorariosScreenState extends State<ConsultaHorariosScreen> {
  late final QuadrasService _service;
  DateTime _dia = _hoje();
  Future<List<HorarioSlot>>? _future;
  RealtimeChannel? _canal;

  static DateTime _hoje() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _service = QuadrasService(Supabase.instance.client);
    _recarregar();
    _canal = _service.assinarOcupacoes(_recarregar);
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
    final f = _service.horariosDoDia(_dia);
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
    );
    if (d != null) {
      setState(() => _dia = DateTime(d.year, d.month, d.day));
      _recarregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reserva de quadras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: 'Área do proprietário',
            onPressed: () => Navigator.of(context).pushNamed('/admin/login'),
          ),
        ],
      ),
      body: Column(
        children: [
          _BarraData(dia: _dia, onTrocar: _escolherData, onHoje: () {
            setState(() => _dia = _hoje());
            _recarregar();
          }),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<HorarioSlot>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _Erro(mensagem: snap.error.toString(), onTentar: _recarregar);
                }
                final slots = snap.data ?? const [];
                if (slots.isEmpty) {
                  return const _Vazio();
                }
                final porQuadra = <String, List<HorarioSlot>>{};
                for (final s in slots) {
                  porQuadra.putIfAbsent(s.quadraNome, () => []).add(s);
                }
                return RefreshIndicator(
                  onRefresh: () async => _recarregar(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: porQuadra.entries
                        .map((e) => _CardQuadra(nome: e.key, slots: e.value, dia: _dia))
                        .toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraData extends StatelessWidget {
  final DateTime dia;
  final VoidCallback onTrocar;
  final VoidCallback onHoje;
  const _BarraData({required this.dia, required this.onTrocar, required this.onHoje});

  @override
  Widget build(BuildContext context) {
    const diasSemana = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];
    final rotulo = '${diasSemana[dia.weekday % 7]} ${_dd(dia.day)}/${_dd(dia.month)}/${dia.year}';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.event, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(rotulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          TextButton(onPressed: onHoje, child: const Text('Hoje')),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onTrocar,
            icon: const Icon(Icons.calendar_month),
            label: const Text('Trocar data'),
          ),
        ],
      ),
    );
  }

  String _dd(int n) => n.toString().padLeft(2, '0');
}

class _CardQuadra extends StatelessWidget {
  final String nome;
  final List<HorarioSlot> slots;
  final DateTime dia;
  const _CardQuadra({required this.nome, required this.slots, required this.dia});

  @override
  Widget build(BuildContext context) {
    final piso = slots.first.tipoPiso;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Chip(
                    label: Text(piso),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots.map((s) => _SlotChip(slot: s, dia: dia, quadra: nome)).toList(),
              ),
              const SizedBox(height: 12),
              const _Legenda(),
            ],
          ),
        ),
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
    final preco = slot.valor != null ? 'R\$ ${slot.valor!.toStringAsFixed(2)}' : '—';
    return Tooltip(
      message: '${slot.horaInicio} · ${cfg.$2} · $preco',
      child: InkWell(
        onTap: slot.livre
            ? () => Navigator.of(context).pushNamed('/reserva', arguments: {
                  'quadraId': slot.quadraId,
                  'quadra': quadra,
                  'data': dia,
                  'hora': slot.horaInicio,
                  'valor': slot.valor,
                })
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cfg.$1.withValues(alpha: 0.12),
            border: Border.all(color: cfg.$1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(slot.horaInicio, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                slot.livre ? preco : cfg.$2,
                style: TextStyle(fontSize: 12, color: cfg.$1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (Color, String) _config(String s) {
    switch (s) {
      case 'livre':
        return (const Color(0xFF2E7D32), 'Livre');
      case 'reservado':
        return (const Color(0xFFC62828), 'Reservado');
      case 'bloqueado':
        return (const Color(0xFF6D4C41), 'Bloqueado');
      case 'passado':
        return (const Color(0xFF9E9E9E), 'Passado');
      case 'sem_preco':
        return (const Color(0xFFEF6C00), 'Sem preço');
      default:
        return (const Color(0xFF607D8B), s);
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
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(t, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        );
    return Wrap(spacing: 12, runSpacing: 6, children: [
      item(const Color(0xFF2E7D32), 'Livre'),
      item(const Color(0xFFC62828), 'Reservado'),
      item(const Color(0xFF6D4C41), 'Bloqueado'),
      item(const Color(0xFF9E9E9E), 'Passado'),
      item(const Color(0xFFEF6C00), 'Sem preço'),
    ]);
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Nenhuma quadra funciona neste dia.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
}

class _Erro extends StatelessWidget {
  final String mensagem;
  final VoidCallback onTentar;
  const _Erro({required this.mensagem, required this.onTentar});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Não foi possível carregar os horários.\n$mensagem',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onTentar, child: const Text('Tentar novamente')),
            ],
          ),
        ),
      );
}
