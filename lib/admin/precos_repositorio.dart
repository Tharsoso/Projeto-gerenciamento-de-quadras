import 'package:supabase_flutter/supabase_flutter.dart';

import '../fuso.dart';
import '../models/bloqueio.dart' show dataIso;
import '../models/funcionamento.dart';
import '../models/preco.dart';
import '../models/quadra.dart';
import 'quadras_repositorio.dart' show FalhaQuadra;

/// Tabela de preços por quadra (H4 / RF18–RF20). A tabela só é gravada pela função
/// `salvar_faixas_preco`, que valida sobreposição e lacunas (RF19). O valor de cada
/// reserva é congelado pelo `criar_reserva` no momento do agendamento (RF20).
abstract class PrecosRepositorio {
  /// Todas as quadras (ativas e inativas), em ordem de nome.
  Future<List<Quadra>> quadras();

  /// Horário de funcionamento de cada quadra (define as horas que precisam de preço).
  Future<Map<int, Semana>> funcionamento();

  /// Tabela atual de cada quadra. Quadra sem preço aparece com listas vazias.
  Future<Map<int, TabelaPrecos>> tabelas();

  /// Reservas confirmadas de hoje em diante na quadra, com o valor gravado.
  Future<List<ReservaComValor>> reservasFuturas(int quadraId);

  /// Datas dos feriados (`aaaa-mm-dd`), para saber qual tabela cada reserva usou.
  Future<Set<String>> feriados();

  /// Substitui todas as faixas do tipo de dia da quadra.
  Future<void> salvar(int quadraId, TipoDia tipo, List<FaixaPreco> faixas);
}

class SupabasePrecosRepositorio implements PrecosRepositorio {
  SupabasePrecosRepositorio(this._client);

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
  Future<Map<int, TabelaPrecos>> tabelas() => _tratar(() async {
        final linhas = await _client
            .from('faixas_preco')
            .select('quadra_id, tipo_dia, hora_inicio, hora_fim, valor')
            .order('hora_inicio');
        final mapa = <int, TabelaPrecos>{};
        for (final l in linhas) {
          final tabela = mapa.putIfAbsent((l['quadra_id'] as num).toInt(),
              () => {TipoDia.util: [], TipoDia.fimDeSemana: []});
          tabela[TipoDia.deValor(l['tipo_dia'] as String)]!.add(FaixaPreco.fromMap(l));
        }
        return mapa;
      });

  @override
  Future<List<ReservaComValor>> reservasFuturas(int quadraId) => _tratar(() async {
        final agora = agoraBrasilia();
        final hoje = DateTime(agora.year, agora.month, agora.day);
        final linhas = await _client
            .from('reservas')
            .select('data, hora_inicio, valor')
            .eq('quadra_id', quadraId)
            .eq('status', 'confirmada')
            .gte('data', dataIso(hoje));
        return linhas
            .map((l) => ReservaComValor(
                  data: DateTime.parse(l['data'] as String),
                  hora: Intervalo.horaDe(l['hora_inicio'] as String),
                  valor: (l['valor'] as num).toDouble(),
                ))
            .where((r) => r.data.isAfter(hoje) || r.hora + 1 > agora.hour)
            .toList();
      });

  @override
  Future<Set<String>> feriados() => _tratar(() async {
        final linhas = await _client.from('feriados').select('data');
        return {for (final l in linhas) l['data'] as String};
      });

  @override
  Future<void> salvar(int quadraId, TipoDia tipo, List<FaixaPreco> faixas) => _tratar(() async {
        await _client.rpc('salvar_faixas_preco', params: {
          'p_quadra_id': quadraId,
          'p_tipo_dia': tipo.valor,
          'p_faixas': [for (final f in faixas) f.toJson()],
        });
      });

  Future<T> _tratar<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on PostgrestException catch (e) {
      throw traduzirErroPreco(e);
    } on AuthException {
      throw const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
    } on Exception {
      throw const FalhaQuadra('Não foi possível conectar. Verifique a internet e tente novamente.');
    }
  }
}

/// `hint` do banco: `FAIXA_SOBREPOSTA`, `FAIXA_LACUNA`, `INTERVALO_INVALIDO`,
/// `TIPO_DIA_INVALIDO`, `QUADRA_INDISPONIVEL`, `NAO_AUTORIZADO` (mensagens já em pt-BR).
FalhaQuadra traduzirErroPreco(PostgrestException e) {
  final hint = e.hint;
  if (hint == 'NAO_AUTORIZADO') {
    return FalhaQuadra(e.message, codigo: hint, sessaoExpirada: true);
  }
  if (hint != null && hint.isNotEmpty) return FalhaQuadra(e.message, codigo: hint);
  if (e.code == '42501' || e.code == 'PGRST301') {
    return const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
  }
  // Checks da tabela (valor <= 0, hora quebrada).
  if (e.code == '23514') {
    return const FalhaQuadra('Faixa inválida: use horas cheias e valores maiores que zero.',
        codigo: 'INTERVALO_INVALIDO');
  }
  return const FalhaQuadra('Não foi possível salvar os preços. Tente novamente.');
}
