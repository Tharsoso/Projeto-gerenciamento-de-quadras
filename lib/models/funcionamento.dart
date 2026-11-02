/// Abertura e fechamento de um dia, em horas cheias (0–24). `fechamento` 22 significa
/// que o último bloco reservável é 21h–22h.
class Intervalo {
  const Intervalo(this.abertura, this.fechamento);

  final int abertura;
  final int fechamento;

  bool get valido => fechamento > abertura;

  bool contem(int hora) => hora >= abertura && hora < fechamento;

  /// Lê `"07:00:00"` (formato do `time` no PostgREST).
  static int horaDe(String texto) => int.parse(texto.substring(0, 2));

  /// `"07:00"`; 24 vira `"24:00"`, que o `time` do Postgres aceita.
  static String textoDe(int hora) => '${hora.toString().padLeft(2, '0')}:00';

  @override
  bool operator ==(Object other) =>
      other is Intervalo && other.abertura == abertura && other.fechamento == fechamento;

  @override
  int get hashCode => Object.hash(abertura, fechamento);

  @override
  String toString() => '${textoDe(abertura)}–${textoDe(fechamento)}';
}

/// Dias de uma quadra: chave = dia da semana (0 = domingo … 6 = sábado, igual ao
/// `extract(dow)` do banco). Dia ausente = fechado.
typedef Semana = Map<int, Intervalo>;

/// Ordem de exibição (segunda primeiro) e nomes.
const ordemDias = [1, 2, 3, 4, 5, 6, 0];
const nomesDias = {
  0: 'Domingo',
  1: 'Segunda',
  2: 'Terça',
  3: 'Quarta',
  4: 'Quinta',
  5: 'Sexta',
  6: 'Sábado',
};
const siglasDias = {0: 'dom', 1: 'seg', 2: 'ter', 3: 'qua', 4: 'qui', 5: 'sex', 6: 'sáb'};

/// Dia da semana no padrão do banco a partir de uma data do Dart (segunda = 1 … domingo = 7).
int diaSemanaDe(DateTime data) => data.weekday % 7;

/// Reserva confirmada que ainda vai acontecer (só o necessário para avisar o impacto).
class ReservaFutura {
  const ReservaFutura({
    required this.quadraId,
    required this.data,
    required this.hora,
    required this.nomeCliente,
  });

  final int quadraId;
  final DateTime data;
  final int hora;
  final String nomeCliente;
}

/// H9 alternativo: reservas futuras que ficariam fora do novo horário. Elas **não** são
/// canceladas (o banco não mexe nelas); a tela só avisa o proprietário.
List<ReservaFutura> reservasForaDoHorario(
    List<ReservaFutura> reservas, Map<int, Semana> novoHorario) {
  return reservas.where((r) {
    final semana = novoHorario[r.quadraId];
    if (semana == null) return false; // quadra não foi alterada
    final intervalo = semana[diaSemanaDe(r.data)];
    return intervalo == null || !intervalo.contem(r.hora);
  }).toList()
    ..sort((a, b) {
      final c = a.data.compareTo(b.data);
      return c != 0 ? c : a.hora.compareTo(b.hora);
    });
}
