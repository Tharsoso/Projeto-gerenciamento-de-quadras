import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/quadra.dart';

/// Falha ao salvar ou carregar quadras, já com a mensagem que vai para a tela.
class FalhaQuadra implements Exception {
  const FalhaQuadra(this.mensagem, {this.codigo, this.sessaoExpirada = false});

  final String mensagem;

  /// `hint` do banco (ex.: `QUADRA_NOME_DUPLICADO`), quando houver.
  final String? codigo;

  /// Sem permissão (42501): o proprietário precisa entrar de novo.
  final bool sessaoExpirada;

  @override
  String toString() => mensagem;
}

/// Acesso à tabela `quadras` pela área do proprietário. Não existe excluir:
/// inativar é `ativa = false` (o banco revoga DELETE).
abstract class QuadrasRepositorio {
  /// Todas as quadras, ativas e inativas, em ordem de nome.
  Future<List<Quadra>> listar();

  Future<Quadra> criar(DadosQuadra dados);

  Future<Quadra> atualizar(int id, DadosQuadra dados);
}

class SupabaseQuadrasRepositorio implements QuadrasRepositorio {
  SupabaseQuadrasRepositorio(this._client);

  final SupabaseClient _client;

  static const _colunas = 'id, nome, tipo_piso, descricao, ativa';

  @override
  Future<List<Quadra>> listar() => _tratar(() async {
        final linhas = await _client.from('quadras').select(_colunas).order('nome');
        return linhas.map(Quadra.fromMap).toList();
      });

  @override
  Future<Quadra> criar(DadosQuadra dados) => _tratar(() async {
        final linha =
            await _client.from('quadras').insert(dados.toMap()).select(_colunas).single();
        return Quadra.fromMap(linha);
      });

  @override
  Future<Quadra> atualizar(int id, DadosQuadra dados) => _tratar(() async {
        final linha = await _client
            .from('quadras')
            .update(dados.toMap())
            .eq('id', id)
            .select(_colunas)
            .single();
        return Quadra.fromMap(linha);
      });

  Future<T> _tratar<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on PostgrestException catch (e) {
      throw traduzirErro(e);
    } on AuthException {
      throw const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
    } on Exception {
      throw const FalhaQuadra('Não foi possível conectar. Verifique a internet e tente novamente.');
    }
  }
}

/// Converte o erro do banco seguindo o contrato: `hint` = código estável,
/// `message` = texto em pt-BR para a tela.
FalhaQuadra traduzirErro(PostgrestException e) {
  final hint = e.hint;
  if (hint != null && hint.isNotEmpty) return FalhaQuadra(e.message, codigo: hint);
  // Índice único disparado por duas gravações ao mesmo tempo (o gatilho não viu a outra).
  if (e.code == '23505') {
    return const FalhaQuadra('Já existe uma quadra com este nome.',
        codigo: 'QUADRA_NOME_DUPLICADO');
  }
  if (e.code == '42501' || e.code == 'PGRST301') {
    return const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true);
  }
  // .single() sem linha: o RLS escondeu a quadra (sem login) ou ela não existe.
  if (e.code == 'PGRST116') {
    return const FalhaQuadra('Quadra não encontrada ou sem permissão. Entre novamente.',
        sessaoExpirada: true);
  }
  return const FalhaQuadra('Não foi possível salvar. Tente novamente.');
}
