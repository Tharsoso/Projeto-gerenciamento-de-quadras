class HorarioSlot {
  final int quadraId;
  final String quadraNome;
  final String tipoPiso;
  final String horaInicio;
  final double? valor;
  final String status;

  HorarioSlot({
    required this.quadraId,
    required this.quadraNome,
    required this.tipoPiso,
    required this.horaInicio,
    required this.valor,
    required this.status,
  });

  factory HorarioSlot.fromMap(Map<String, dynamic> m) => HorarioSlot(
        quadraId: (m['quadra_id'] as num).toInt(),
        quadraNome: m['quadra_nome'] as String,
        tipoPiso: m['tipo_piso'] as String,
        horaInicio: (m['hora_inicio'] as String).substring(0, 5),
        valor: m['valor'] == null ? null : (m['valor'] as num).toDouble(),
        status: m['status'] as String,
      );

  bool get livre => status == 'livre';
}
