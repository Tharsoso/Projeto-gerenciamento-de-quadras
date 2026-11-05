import 'package:supabase_flutter/supabase_flutter.dart';

import '../fuso.dart';
import '../models/bloqueio.dart';
import '../models/quadra.dart';
import 'quadras_repositorio.dart' show FalhaQuadra;

/// Acesso a `bloqueios` (H5 / RF17). As regras ficam no banco (gatilho `validar_bloqueio`):
/// não bloqueia horário passado nem horário com reserva. O gatilho `bloqueios_ocupacao`
/// atualiza `ocupacoes`, e a consulta pública vê o bloqueio em tempo real.
abstract class BloqueiosRepositorio {
  /// Quadras ativas, em ordem de nome (só nelas faz sentido bloquear).
  Future<List<Quadra>> quadrasAtivas();

  /// Bloqueios que ainda não passaram, do mais próximo ao mais distante.
  Future<List<Bloqueio>> futuros();

  /// Horas que ainda dá para bloquear na quadra e data (mesma fonte da consulta pública).
  Future<HorariosBloqueaveis> livres(int quadraId, DateTime data);

  Future<void> bloquear({
    required int quadraId,
    required DateTime data,
    required int hora,
    String? motivo,
  });

  Future<void> desbloquear(int id);
}

class SupabaseBloqueiosRepositorio implements BloqueiosRepositorio {
  SupabaseBloqueiosRepositorio(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Quadra>> quadrasAtivas() => _tratar(() async {
        final linhas = await _client
            .from('quadras')
            .select('id, nome, tipo_piso, descricao, ativa')
            .eq('ativa', true)
            .order('nome');
        return linhas.map(Quadra.fromMap).toList();
      });

  @override
  Future<List<Bloqueio>> futuros() => _tratar(() async {
        final agora = agoraBrasilia();
        final hoje = DateTime(agora.year, agora.month, agora.day);
        final linhas = await _client
            .from('bloqueios')
            .select('id, quadra_id, data, hora_inicio, motivo, quadras(nome)')
            .gte('data', dataIso(hoje))
            .order('data')
            .order('hora_inicio');
        return linhas
            .map(Bloqueio.fromMap)
            // Hoje, só os que ainda não terminaram.
            .where((b) => b.data.isAfter(hoje) || b.hora + 1 > agora.hour)
            .toList();
      });

  @override
  Future<HorariosBloqueaveis> livres(int quadraId, DateTime data) => _tratar(() async {
        final res = await _client.rpc('horarios_do_dia', params: {'p_data': dataIso(data)});
        final daQuadra = (res as List)
            .cast<Map<String, dynamic>>()
            .where((s) => (s['quadra_id'] as num).toInt() == quadraId)
            .toList();
        // 'sem_preco' também pode ser bloqueado: o horário existe, só não tem preço ainda.
        final livres = daQuadra
            .where((s) => s['status'] == 'livre' || s['status'] == 'sem_preco')
            .map((s) => int.parse((s['hora_inicio'] as String).substring(0, 2)))
            .toList();
        return HorariosBloqueaveis(aberta: daQuadra.isNotEmpty, livres: livres);
      });

  @override
  Future<void> bloquear({
    required int quadraId,
    required DateTime data,
    required int hora,
    String? motivo,
  }) =>
      _tratar(() async {
        final m = motivo?.trim();
        await _client.from('bloqueios').insert({
          'quadra_id': quadraId,
          'data': dataIso(data),
          'hora_inicio': '${hora.toString().padLeft(2, '0')}:00',
          'motivo': (m == null || m.isEmpty) ? null : m,
        });
      });

  @override
  Future<void> desbloquear(int id) => _tratar(() async {
        await _client.from('bloqueios').delete().eq('id', id);
      });

  Future<T> _tratar<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on PostgrestException catch (e) {
      throw traduzirErroBloqueio(e);
    } on AuthException {
      throw const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
    } on Exception {
      throw const FalhaQuadra('Não foi possível conectar. Verifique a internet e tente novamente.');
    }
  }
}

/// `hint` do banco: `HORARIO_PASSADO`, `HORARIO_RESERVADO` (mensagens já em pt-BR).
FalhaQuadra traduzirErroBloqueio(PostgrestException e) {
  final hint = e.hint;
  if (hint != null && hint.isNotEmpty) return FalhaQuadra(e.message, codigo: hint);
  // unique (quadra_id, data, hora_inicio): alguém bloqueou o mesmo horário antes.
  if (e.code == '23505') {
    return const FalhaQuadra('Este horário já está bloqueado.', codigo: 'JA_BLOQUEADO');
  }
  if (e.code == '42501' || e.code == 'PGRST301') {
    return const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
  }
  return const FalhaQuadra('Não foi possível salvar o bloqueio. Tente novamente.');
}
