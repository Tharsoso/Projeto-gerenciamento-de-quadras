import 'dart:ui';

/// Valores aceitos pelo check de `quadras.tipo_piso` no banco.
enum TipoPiso {
  saibro('saibro', 'Saibro', Color(0xFFFBE9E0), Color(0xFFA4400F)),
  dura('dura', 'Dura', Color(0xFFE3EBF6), Color(0xFF1F4E8C)),
  grama('grama', 'Grama', Color(0xFFE4F2D8), Color(0xFF2F6B12)),
  sintetica('sintetica', 'Sintética', Color(0xFFEDE7F6), Color(0xFF5B3FA0));

  const TipoPiso(this.valor, this.rotulo, this.fundo, this.cor);

  /// Texto gravado no banco.
  final String valor;
  final String rotulo;

  /// Cores do chip do piso, iguais às do protótipo.
  final Color fundo;
  final Color cor;

  static TipoPiso deValor(String v) =>
      values.firstWhere((p) => p.valor == v, orElse: () => TipoPiso.saibro);
}

/// Linha da tabela `quadras` (H8 / RF12).
class Quadra {
  const Quadra({
    required this.id,
    required this.nome,
    required this.tipoPiso,
    required this.descricao,
    required this.ativa,
  });

  final int id;
  final String nome;
  final TipoPiso tipoPiso;
  final String? descricao;
  final bool ativa;

  factory Quadra.fromMap(Map<String, dynamic> m) => Quadra(
        id: (m['id'] as num).toInt(),
        nome: m['nome'] as String,
        tipoPiso: TipoPiso.deValor(m['tipo_piso'] as String),
        descricao: m['descricao'] as String?,
        ativa: m['ativa'] as bool,
      );
}

/// O que a tela envia ao criar ou editar uma quadra.
class DadosQuadra {
  const DadosQuadra({
    required this.nome,
    required this.tipoPiso,
    required this.descricao,
    required this.ativa,
  });

  final String nome;
  final TipoPiso tipoPiso;
  final String? descricao;
  final bool ativa;

  Map<String, dynamic> toMap() => {
        'nome': nome.trim(),
        'tipo_piso': tipoPiso.valor,
        'descricao': (descricao == null || descricao!.trim().isEmpty) ? null : descricao!.trim(),
        'ativa': ativa,
      };
}
