/// Linha de `reservas` vista pelo proprietário (H11 / RF14). Depois de 12 meses o banco
/// anonimiza nome e telefone (LGPD); valor e data ficam para os relatórios.
class Agendamento {
  const Agendamento({
    required this.id,
    required this.quadraId,
    required this.quadraNome,
    required this.data,
    required this.hora,
    required this.nome,
    required this.telefone,
    required this.valor,
    required this.cancelada,
    required this.anonimizada,
    this.motivoCancelamento,
  });

  final int id;
  final int quadraId;
  final String quadraNome;
  final DateTime data;
  final int hora;
  final String nome;

  /// Só dígitos; `null` depois da anonimização.
  final String? telefone;
  final double valor;
  final bool cancelada;
  final bool anonimizada;
  final String? motivoCancelamento;

  /// Código mostrado ao cliente na confirmação: `R0042`.
  String get codigo => 'R${id.toString().padLeft(4, '0')}';

  factory Agendamento.fromMap(Map<String, dynamic> m) {
    final log = m['log_cancelamentos'];
    final motivos = log is List ? log.cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
    return Agendamento(
      id: (m['id'] as num).toInt(),
      quadraId: (m['quadra_id'] as num).toInt(),
      quadraNome: (m['quadras'] as Map?)?['nome'] as String? ?? 'Quadra',
      data: DateTime.parse(m['data'] as String),
      hora: int.parse((m['hora_inicio'] as String).substring(0, 2)),
      nome: m['nome_cliente'] as String,
      telefone: m['telefone'] as String?,
      valor: (m['valor'] as num).toDouble(),
      cancelada: m['status'] == 'cancelada',
      anonimizada: m['anonimizada'] as bool? ?? false,
      motivoCancelamento: motivos.isEmpty ? null : motivos.last['motivo'] as String?,
    );
  }
}

/// Filtros da consulta de agendamentos. [busca] com dígitos procura no telefone;
/// com letras, no nome do cliente.
class FiltroAgendamentos {
  const FiltroAgendamentos({
    required this.inicio,
    required this.fim,
    this.quadraId,
    this.busca = '',
  });

  final DateTime inicio;
  final DateTime fim;
  final int? quadraId;
  final String busca;

  FiltroAgendamentos copiar({DateTime? inicio, DateTime? fim, int? Function()? quadraId, String? busca}) =>
      FiltroAgendamentos(
        inicio: inicio ?? this.inicio,
        fim: fim ?? this.fim,
        quadraId: quadraId != null ? quadraId() : this.quadraId,
        busca: busca ?? this.busca,
      );
}
