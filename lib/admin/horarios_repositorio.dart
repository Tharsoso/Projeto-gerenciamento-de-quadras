import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/funcionamento.dart';
import '../models/quadra.dart';
import 'quadras_repositorio.dart' show FalhaQuadra;

/// Acesso a `horarios_funcionamento` (H9 / RF13). Uma linha por quadra e dia;
/// dia sem linha = fechado. Erros chegam como [FalhaQuadra] (mesmo formato da 5.2).
abstract class HorariosRepositorio {
  /// Todas as quadras (ativas e inativas), em ordem de nome.
  Future<List<Quadra>> quadras();

  /// Horário atual de cada quadra. Quadra sem nenhuma linha aparece com semana vazia.
  Future<Map<int, Semana>> funcionamento();

  /// Reservas confirmadas de hoje em diante nas quadras informadas.
  Future<List<ReservaFutura>> reservasFuturas(Set<int> quadraIds);

  /// Grava a semana inteira de uma quadra: abre/altera os dias presentes e fecha os demais.
  Future<void> salvar(int quadraId, Semana semana);
}

class SupabaseHorariosRepositorio implements HorariosRepositorio {
  SupabaseHorariosRepositorio(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Quadra>> quadras() => _tratar(() async {
        final linhas = await _client
            .from('quadras')
            .select('id, nome, tipo_piso, descricao, ativa')
            .order('nome');
        return linhas.map(Quadra.fromMap).toList();
      });

  @override
  Future<Map<int, Semana>> funcionamento() => _tratar(() async {
        final linhas = await _client
            .from('horarios_funcionamento')
            .select('quadra_id, dia_semana, abertura, fechamento');
        final mapa = <int, Semana>{};
        for (final l in linhas) {
          final semana = mapa.putIfAbsent((l['quadra_id'] as num).toInt(), () => {});
          semana[(l['dia_semana'] as num).toInt()] = Intervalo(
            Intervalo.horaDe(l['abertura'] as String),
            Intervalo.horaDe(l['fechamento'] as String),
          );
        }
        return mapa;
      });

  @override
  Future<List<ReservaFutura>> reservasFuturas(Set<int> quadraIds) => _tratar(() async {
        if (quadraIds.isEmpty) return const [];
        final agora = DateTime.now();
        final hoje = DateTime(agora.year, agora.month, agora.day);
        final linhas = await _client
            .from('reservas')
            .select('quadra_id, data, hora_inicio, nome_cliente')
            .eq('status', 'confirmada')
            .gte('data', _dataIso(hoje))
            .inFilter('quadra_id', quadraIds.toList());
        return linhas
            .map((l) => ReservaFutura(
                  quadraId: (l['quadra_id'] as num).toInt(),
                  data: DateTime.parse(l['data'] as String),
                  hora: Intervalo.horaDe(l['hora_inicio'] as String),
                  nomeCliente: l['nome_cliente'] as String,
                ))
            // Hoje, só as que ainda não terminaram.
            .where((r) => r.data.isAfter(hoje) || r.hora + 1 > agora.hour)
            .toList();
      });

  @override
  Future<void> salvar(int quadraId, Semana semana) => _tratar(() async {
        final tabela = _client.from('horarios_funcionamento');
        if (semana.isNotEmpty) {
          await tabela.upsert(
            [
              for (final e in semana.entries)
                {
                  'quadra_id': quadraId,
                  'dia_semana': e.key,
                  'abertura': Intervalo.textoDe(e.value.abertura),
                  'fechamento': Intervalo.textoDe(e.value.fechamento),
                },
            ],
            onConflict: 'quadra_id,dia_semana',
          );
        }
        final fechados = [for (var d = 0; d < 7; d++) if (!semana.containsKey(d)) d];
        if (fechados.isNotEmpty) {
          await tabela.delete().eq('quadra_id', quadraId).inFilter('dia_semana', fechados);
        }
      });

  Future<T> _tratar<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on PostgrestException catch (e) {
      throw traduzirErroHorario(e);
    } on AuthException {
      throw const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
    } on Exception {
      throw const FalhaQuadra('Não foi possível conectar. Verifique a internet e tente novamente.');
    }
  }

  static String _dataIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

FalhaQuadra traduzirErroHorario(PostgrestException e) {
  final hint = e.hint;
  if (hint != null && hint.isNotEmpty) return FalhaQuadra(e.message, codigo: hint);
  if (e.code == '42501' || e.code == 'PGRST301') {
    return const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
  }
  // Checks da tabela (hora quebrada, fechamento <= abertura) sem passar pelo gatilho.
  if (e.code == '23514') {
    return const FalhaQuadra('Horário inválido: use horas cheias e feche depois de abrir.',
        codigo: 'INTERVALO_INVALIDO');
  }
  return const FalhaQuadra('Não foi possível salvar os horários. Tente novamente.');
}
