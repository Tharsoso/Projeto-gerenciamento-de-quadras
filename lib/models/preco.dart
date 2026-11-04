import 'funcionamento.dart';

/// Tabela de preço de uma quadra (H4 / RF18). `fimDeSemana` vale para sábado, domingo
/// **e feriados** (RF21). Mesmos valores do check de `faixas_preco.tipo_dia`.
enum TipoDia {
  util('util', 'Dia útil', 'seg–sex'),
  fimDeSemana('fim_de_semana', 'Fim de semana e feriado', 'sáb, dom e feriados');

  const TipoDia(this.valor, this.rotulo, this.dias);

  /// Texto gravado no banco.
  final String valor;
  final String rotulo;
  final String dias;

  static TipoDia deValor(String v) => v == 'util' ? util : fimDeSemana;

  /// Igual à função `tipo_dia()` do banco.
  static TipoDia daData(DateTime data, Set<String> feriadosIso) {
    final dow = diaSemanaDe(data);
    final iso = '${data.year.toString().padLeft(4, '0')}-'
        '${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
    return (dow == 0 || dow == 6 || feriadosIso.contains(iso)) ? fimDeSemana : util;
  }
}

/// Faixa `[inicio, fim)` em horas cheias, com o valor de 1 hora em reais.
class FaixaPreco {
  const FaixaPreco(this.inicio, this.fim, this.valor);

  final int inicio;
  final int fim;
  final double valor;

  bool contem(int hora) => hora >= inicio && hora < fim;

  factory FaixaPreco.fromMap(Map<String, dynamic> m) => FaixaPreco(
        Intervalo.horaDe(m['hora_inicio'] as String),
        Intervalo.horaDe(m['hora_fim'] as String),
        (m['valor'] as num).toDouble(),
      );

  /// Formato que `salvar_faixas_preco` espera em `p_faixas`.
  Map<String, dynamic> toJson() => {
        'hora_inicio': Intervalo.textoDe(inicio),
        'hora_fim': Intervalo.textoDe(fim),
        'valor': valor,
      };

  @override
  bool operator ==(Object other) =>
      other is FaixaPreco && other.inicio == inicio && other.fim == fim && other.valor == valor;

  @override
  int get hashCode => Object.hash(inicio, fim, valor);

  @override
  String toString() => '${Intervalo.textoDe(inicio)}–${Intervalo.textoDe(fim)} R\$ $valor';
}

/// Tabela de uma quadra: uma lista de faixas para cada tipo de dia.
typedef TabelaPrecos = Map<TipoDia, List<FaixaPreco>>;

/// Horas que a tabela do tipo de dia precisa cobrir (igual à checagem de lacuna da
/// `salvar_faixas_preco`): dia útil cobre o funcionamento de seg–sex; fim de semana cobre
/// o funcionamento de **todos** os dias, porque feriado pode cair num dia útil.
Set<int> horasACobrir(Semana semana, TipoDia tipo) => {
      for (final e in semana.entries)
        if (tipo == TipoDia.fimDeSemana || (e.key >= 1 && e.key <= 5))
          for (var h = e.value.abertura; h < e.value.fechamento; h++) h,
    };

/// Lê o valor digitado ("60", "60,5", "1.234,56", "90.00"). Devolve null se não for um
/// número com até 2 casas decimais.
double? lerValor(String texto) {
  var t = texto.trim().replaceAll(RegExp(r'^R\$\s*'), '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    t = t.replaceAll('.', ''); // "1.200" = mil e duzentos
  }
  if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(t)) return null;
  return double.parse(t);
}

/// Valor para o campo de texto: 60 → "60,00".
String textoValor(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

/// Faixa como está na tela: o valor ainda é texto e pode estar inválido.
class FaixaEditada {
  const FaixaEditada(this.inicio, this.fim, this.valorTexto);

  final int inicio;
  final int fim;
  final String valorTexto;
}

/// Resultado da validação de uma aba (RF19). [erros] vazio = pode salvar.
class ValidacaoFaixas {
  const ValidacaoFaixas({
    required this.erros,
    required this.lacunas,
    required this.sobrepostas,
  });

  final List<String> erros;

  /// Horas de funcionamento sem nenhuma faixa.
  final Set<int> lacunas;

  /// Horas cobertas por mais de uma faixa.
  final Set<int> sobrepostas;

  bool get valida => erros.isEmpty;
}

String _h(int h) => '${h.toString().padLeft(2, '0')}h';

/// Mesmas regras da `salvar_faixas_preco`, para avisar antes de enviar. O banco valida de
/// novo; a mensagem dele é a que vale se algo escapar daqui.
ValidacaoFaixas validarFaixas(List<FaixaEditada> faixas, Set<int> cobrir) {
  final erros = <String>[];
  for (var i = 0; i < faixas.length; i++) {
    final f = faixas[i];
    if (f.fim <= f.inicio) {
      erros.add('Faixa ${i + 1}: o fim (${_h(f.fim)}) precisa ser depois do início (${_h(f.inicio)}).');
    }
    final v = lerValor(f.valorTexto);
    if (v == null || v <= 0) {
      erros.add('Faixa ${i + 1}: informe um valor maior que R\$ 0,00.');
    }
  }

  final validas = [for (final f in faixas) if (f.fim > f.inicio) f]
    ..sort((a, b) => a.inicio.compareTo(b.inicio));
  final sobrepostas = <int>{};
  for (var i = 0; i < validas.length; i++) {
    for (var j = i + 1; j < validas.length; j++) {
      final a = validas[i], b = validas[j];
      if (a.inicio < b.fim && b.inicio < a.fim) {
        erros.add('As faixas ${_h(a.inicio)}–${_h(a.fim)} e ${_h(b.inicio)}–${_h(b.fim)} se sobrepõem.');
        final ini = a.inicio > b.inicio ? a.inicio : b.inicio;
        final fim = a.fim < b.fim ? a.fim : b.fim;
        for (var h = ini; h < fim; h++) {
          sobrepostas.add(h);
        }
      }
    }
  }

  final lacunas = {
    for (final h in cobrir)
      if (!validas.any((f) => h >= f.inicio && h < f.fim)) h,
  };
  // Agrupa horas seguidas: "Sem preço entre 18h e 20h".
  final ordenadas = lacunas.toList()..sort();
  for (var i = 0; i < ordenadas.length;) {
    var j = i;
    while (j + 1 < ordenadas.length && ordenadas[j + 1] == ordenadas[j] + 1) {
      j++;
    }
    erros.add('Sem preço entre ${_h(ordenadas[i])} e ${_h(ordenadas[j] + 1)}: as faixas precisam '
        'cobrir todo o horário de funcionamento.');
    i = j + 1;
  }
  return ValidacaoFaixas(erros: erros, lacunas: lacunas, sobrepostas: sobrepostas);
}

/// Reserva confirmada futura com o valor que foi gravado nela (RNF07).
class ReservaComValor {
  const ReservaComValor({required this.data, required this.hora, required this.valor});

  final DateTime data;
  final int hora;
  final double valor;
}

/// H4 alternativo 2: quantas reservas futuras do tipo de dia alterado teriam outro preço
/// com a nova tabela. Elas **não** mudam (o valor fica gravado na reserva); a tela só informa.
int reservasComValorAnterior(
  List<ReservaComValor> reservas,
  TipoDia tipo,
  List<FaixaPreco> novas,
  Set<String> feriadosIso,
) {
  return reservas.where((r) {
    if (TipoDia.daData(r.data, feriadosIso) != tipo) return false;
    final faixa = novas.where((f) => f.contem(r.hora));
    return faixa.isEmpty || faixa.first.valor != r.valor;
  }).length;
}
