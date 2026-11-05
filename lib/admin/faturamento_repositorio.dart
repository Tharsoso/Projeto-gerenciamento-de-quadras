import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bloqueio.dart' show dataIso;
import 'quadras_repositorio.dart' show FalhaQuadra;

/// Totais do período, calculados pelo banco (`resumo_faturamento`). Canceladas não
/// entram no faturamento (RF22-RF23).
class ResumoFaturamento {
  const ResumoFaturamento({
    required this.locacoes,
    required this.faturamento,
    required this.canceladas,
  });

  final int locacoes;
  final double faturamento;
  final int canceladas;
}

/// Relatório de locações por período (atividade 5.8 · H12). Só leitura.
abstract class FaturamentoRepositorio {
  /// [telefone] só com dígitos (DDD + 9 + 8); `null` para todos os clientes.
  Future<ResumoFaturamento> resumo(DateTime inicio, DateTime fim, {String? telefone});

  /// Faturamento das reservas confirmadas, somado por dia. Dias sem locação ficam de fora.
  Future<Map<DateTime, double>> porDia(DateTime inicio, DateTime fim, {String? telefone});
}

class SupabaseFaturamentoRepositorio implements FaturamentoRepositorio {
  SupabaseFaturamentoRepositorio(this._client);

  final SupabaseClient _client;

  /// O PostgREST devolve no máximo 1000 linhas por chamada; o período pode ter mais.
  static const _pagina = 1000;

  @override
  Future<ResumoFaturamento> resumo(DateTime inicio, DateTime fim, {String? telefone}) =>
      _tratar(() async {
        final res = await _client.rpc('resumo_faturamento', params: {
          'p_inicio': dataIso(inicio),
          'p_fim': dataIso(fim),
          'p_telefone': telefone,
        });
        final linha = (res as List).cast<Map<String, dynamic>>().first;
        return ResumoFaturamento(
          locacoes: (linha['qtd_locacoes'] as num).toInt(),
          faturamento: (linha['faturamento'] as num).toDouble(),
          canceladas: (linha['qtd_canceladas'] as num).toInt(),
        );
      });

  @override
  Future<Map<DateTime, double>> porDia(DateTime inicio, DateTime fim, {String? telefone}) =>
      _tratar(() async {
        final soma = <DateTime, double>{};
        for (var de = 0;; de += _pagina) {
          var consulta = _client
              .from('reservas')
              .select('data, valor')
              .eq('status', 'confirmada')
              .gte('data', dataIso(inicio))
              .lte('data', dataIso(fim));
          if (telefone != null) consulta = consulta.eq('telefone', telefone);
          final linhas = await consulta.order('id').range(de, de + _pagina - 1);
          for (final l in linhas) {
            final dia = DateTime.parse(l['data'] as String);
            soma[dia] = (soma[dia] ?? 0) + (l['valor'] as num).toDouble();
          }
          if (linhas.length < _pagina) return soma;
        }
      });

  Future<T> _tratar<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on PostgrestException catch (e) {
      throw traduzirErroFaturamento(e);
    } on AuthException {
      throw const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
    } on Exception {
      throw const FalhaQuadra('Não foi possível conectar. Verifique a internet e tente novamente.');
    }
  }
}

/// `hint` do banco: `PERIODO_INVALIDO`, `NAO_AUTORIZADO` (mensagens já em pt-BR).
FalhaQuadra traduzirErroFaturamento(PostgrestException e) {
  if (e.code == '42501' || e.code == 'PGRST301' || e.hint == 'NAO_AUTORIZADO') {
    return const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
  }
  final hint = e.hint;
  if (hint != null && hint.isNotEmpty) return FalhaQuadra(e.message, codigo: hint);
  return const FalhaQuadra('Não foi possível carregar o relatório. Tente novamente.');
}
