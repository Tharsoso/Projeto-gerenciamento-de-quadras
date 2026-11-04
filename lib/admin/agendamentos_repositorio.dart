import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/agendamento.dart';
import '../models/bloqueio.dart' show dataIso;
import '../models/quadra.dart';
import 'quadras_repositorio.dart' show FalhaQuadra;

/// Consulta de agendamentos pelo proprietário (atividade 5.4 · H11 · RF14). Só leitura:
/// o RLS libera `select` em `reservas` para o usuário logado; cancelar é da 5.5.
abstract class AgendamentosRepositorio {
  /// Todas as quadras, inclusive inativas (para o filtro achar reservas antigas).
  Future<List<Quadra>> quadras();

  /// Reservas do período, em ordem de data e hora. Traz no máximo [limite] linhas.
  Future<List<Agendamento>> listar(FiltroAgendamentos filtro);

  static const limite = 500;
}

class SupabaseAgendamentosRepositorio implements AgendamentosRepositorio {
  SupabaseAgendamentosRepositorio(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Quadra>> quadras() => _tratar(() async {
        final linhas =
            await _client.from('quadras').select('id, nome, tipo_piso, descricao, ativa').order('nome');
        return linhas.map(Quadra.fromMap).toList();
      });

  @override
  Future<List<Agendamento>> listar(FiltroAgendamentos filtro) => _tratar(() async {
        var consulta = _client
            .from('reservas')
            .select('id, quadra_id, data, hora_inicio, nome_cliente, telefone, valor, status, '
                'anonimizada, quadras(nome), log_cancelamentos(motivo)')
            .gte('data', dataIso(filtro.inicio))
            .lte('data', dataIso(filtro.fim));
        if (filtro.quadraId != null) consulta = consulta.eq('quadra_id', filtro.quadraId!);
        final busca = filtro.busca.trim();
        final digitos = busca.replaceAll(RegExp(r'\D'), '');
        if (digitos.isNotEmpty) {
          consulta = consulta.like('telefone', '%$digitos%');
        } else if (busca.isNotEmpty) {
          // Vírgula e parênteses têm sentido na sintaxe do PostgREST; ficam de fora.
          final limpa = busca.replaceAll(RegExp(r'[,()%_*]'), ' ').trim();
          if (limpa.isNotEmpty) consulta = consulta.ilike('nome_cliente', '%$limpa%');
        }
        final linhas = await consulta
            .order('data')
            .order('hora_inicio')
            .limit(AgendamentosRepositorio.limite);
        return linhas.map(Agendamento.fromMap).toList();
      });

  Future<T> _tratar<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on PostgrestException catch (e) {
      throw traduzirErroAgendamentos(e);
    } on AuthException {
      throw const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
    } on Exception {
      throw const FalhaQuadra('Não foi possível conectar. Verifique a internet e tente novamente.');
    }
  }
}

FalhaQuadra traduzirErroAgendamentos(PostgrestException e) {
  if (e.code == '42501' || e.code == 'PGRST301') {
    return const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
  }
  final hint = e.hint;
  if (hint != null && hint.isNotEmpty) return FalhaQuadra(e.message, codigo: hint);
  return const FalhaQuadra('Não foi possível carregar as reservas. Tente novamente.');
}
