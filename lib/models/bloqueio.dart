/// Linha de `bloqueios` (H5 / RF17): um bloco de 1 hora de uma quadra reservado para
/// manutenção. Bloquear = insert; desbloquear = delete.
class Bloqueio {
  const Bloqueio({
    required this.id,
    required this.quadraId,
    required this.quadraNome,
    required this.data,
    required this.hora,
    required this.motivo,
  });

  final int id;
  final int quadraId;
  final String quadraNome;
  final DateTime data;
  final int hora;
  final String? motivo;

  factory Bloqueio.fromMap(Map<String, dynamic> m) => Bloqueio(
        id: (m['id'] as num).toInt(),
        quadraId: (m['quadra_id'] as num).toInt(),
        quadraNome: (m['quadras'] as Map?)?['nome'] as String? ?? 'Quadra',
        data: DateTime.parse(m['data'] as String),
        hora: int.parse((m['hora_inicio'] as String).substring(0, 2)),
        motivo: m['motivo'] as String?,
      );
}

/// Resultado da busca de horários que podem ser bloqueados numa data.
class HorariosBloqueaveis {
  const HorariosBloqueaveis({required this.aberta, required this.livres});

  /// `false` quando a quadra não funciona nesse dia (ou está inativa).
  final bool aberta;

  /// Horas ainda livres (sem reserva, sem bloqueio e que não passaram).
  final List<int> livres;
}

String dataIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String dataBr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
