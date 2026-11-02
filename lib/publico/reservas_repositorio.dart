import 'package:supabase_flutter/supabase_flutter.dart';

/// Horário livre escolhido na consulta, levado até a tela de reserva.
class HorarioEscolhido {
  const HorarioEscolhido({
    required this.quadraId,
    required this.quadra,
    required this.data,
    required this.hora,
    required this.valor,
  });

  final int quadraId;
  final String quadra;
  final DateTime data;

  /// Hora cheia no formato `HH:mm`.
  final String hora;
  final double? valor;
}

/// Reserva gravada, com os dados que o banco confirmou.
class ReservaConfirmada {
  const ReservaConfirmada({
    required this.id,
    required this.quadra,
    required this.data,
    required this.hora,
    required this.valor,
    required this.nome,
    required this.telefone,
  });

  final int id;
  final String quadra;
  final DateTime data;
  final String hora;
  final double valor;
  final String nome;
  final String telefone;

  /// Código mostrado ao cliente: `R0042`.
  String get codigo => 'R${id.toString().padLeft(4, '0')}';
}

/// Falha ao reservar, já com a mensagem que vai para a tela.
class FalhaReserva implements Exception {
  const FalhaReserva(this.mensagem, {this.codigo});

  final String mensagem;

  /// `hint` do banco (ex.: `LIMITE_DIARIO`, `HORARIO_OCUPADO`), quando houver.
  final String? codigo;

  @override
  String toString() => mensagem;
}

/// Criação de reservas pela área pública, sem login (H1). As regras ficam no banco.
abstract class ReservasRepositorio {
  /// Lança [FalhaReserva] se o banco recusar ou não houver conexão.
  Future<ReservaConfirmada> criar({
    required HorarioEscolhido horario,
    required String nome,
    required String telefone,
  });
}

class SupabaseReservasRepositorio implements ReservasRepositorio {
  SupabaseReservasRepositorio(this._client);

  final SupabaseClient _client;

  @override
  Future<ReservaConfirmada> criar({
    required HorarioEscolhido horario,
    required String nome,
    required String telefone,
  }) async {
    final d = horario.data;
    final dataIso = '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      final resposta = await _client.rpc('criar_reserva', params: {
        'p_quadra_id': horario.quadraId,
        'p_data': dataIso,
        'p_hora_inicio': horario.hora,
        'p_nome': nome,
        'p_telefone': telefone,
      });
      final linha = (resposta as List).cast<Map<String, dynamic>>().first;
      return ReservaConfirmada(
        id: linha['id'] as int,
        quadra: linha['quadra_nome'] as String,
        data: d,
        hora: (linha['hora_inicio'] as String).substring(0, 5),
        valor: (linha['valor'] as num).toDouble(),
        nome: nome,
        telefone: telefone,
      );
    } on PostgrestException catch (e) {
      throw traduzirErroReserva(e);
    } on Exception {
      throw const FalhaReserva('Não foi possível conectar. Verifique a internet e tente novamente.');
    }
  }
}

/// Converte o erro do banco seguindo o contrato: `hint` = código estável,
/// `message` = texto em pt-BR para a tela.
FalhaReserva traduzirErroReserva(PostgrestException e) {
  final hint = e.hint;
  if (hint != null && hint.isNotEmpty) return FalhaReserva(e.message, codigo: hint);
  return const FalhaReserva('Não foi possível concluir a reserva. Tente novamente.');
}
