import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bloqueio.dart' show dataIso;
import 'quadras_repositorio.dart' show FalhaQuadra;

/// Feriado (H4 alternativo 3 / RF21): nesse dia vale a tabela de fim de semana, mesmo
/// caindo num dia útil. A tabela `feriados` tem `data` como chave.
class Feriado {
  const Feriado({required this.data, required this.descricao});

  final DateTime data;
  final String descricao;

  factory Feriado.fromMap(Map<String, dynamic> m) => Feriado(
        data: DateTime.parse(m['data'] as String),
        descricao: m['descricao'] as String,
      );
}

/// CRUD direto na tabela `feriados` (o RLS só deixa o proprietário escrever).
abstract class FeriadosRepositorio {
  /// Todos os feriados, em ordem de data.
  Future<List<Feriado>> listar();

  Future<void> adicionar(DateTime data, String descricao);

  Future<void> remover(DateTime data);
}

class SupabaseFeriadosRepositorio implements FeriadosRepositorio {
  SupabaseFeriadosRepositorio(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Feriado>> listar() => _tratar(() async {
        final linhas = await _client.from('feriados').select('data, descricao').order('data');
        return linhas.map(Feriado.fromMap).toList();
      });

  @override
  Future<void> adicionar(DateTime data, String descricao) => _tratar(() async {
        await _client
            .from('feriados')
            .insert({'data': dataIso(data), 'descricao': descricao.trim()});
      });

  @override
  Future<void> remover(DateTime data) => _tratar(() async {
        await _client.from('feriados').delete().eq('data', dataIso(data));
      });

  Future<T> _tratar<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on PostgrestException catch (e) {
      throw traduzirErroFeriado(e);
    } on AuthException {
      throw const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
    } on Exception {
      throw const FalhaQuadra('Não foi possível conectar. Verifique a internet e tente novamente.');
    }
  }
}

FalhaQuadra traduzirErroFeriado(PostgrestException e) {
  // Chave primária: já existe feriado nessa data.
  if (e.code == '23505') {
    return const FalhaQuadra('Já existe um feriado nesta data.', codigo: 'FERIADO_DUPLICADO');
  }
  // check length(trim(descricao)) > 0
  if (e.code == '23514') {
    return const FalhaQuadra('Informe a descrição do feriado.', codigo: 'DESCRICAO_INVALIDA');
  }
  if (e.code == '42501' || e.code == 'PGRST301') {
    return const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
  }
  final hint = e.hint;
  if (hint != null && hint.isNotEmpty) return FalhaQuadra(e.message, codigo: hint);
  return const FalhaQuadra('Não foi possível salvar o feriado. Tente novamente.');
}
