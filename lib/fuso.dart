/// Horário de Brasília para o app inteiro (RNF15, regras F1–F3 da atividade 5.9).
///
/// O Brasil não tem horário de verão desde 2019 (Decreto 9.772/2019), então Brasília é
/// sempre UTC−3. Se isso mudar, a regra muda só aqui.
library;

const Duration deslocamentoBrasilia = Duration(hours: -3);

/// Relógio usado pelo app. Os testes trocam para um instante fixo.
DateTime Function() relogioUtc = () => DateTime.now().toUtc();

/// "Agora" em Brasília, independente do fuso configurado no aparelho.
///
/// Devolve um `DateTime` local (não UTC) com os campos de Brasília, o mesmo formato das
/// datas e horas que vêm do banco (`date` + `time` sem fuso).
DateTime agoraBrasilia([DateTime? utc]) {
  final b = (utc ?? relogioUtc()).toUtc().add(deslocamentoBrasilia);
  return DateTime(
    b.year,
    b.month,
    b.day,
    b.hour,
    b.minute,
    b.second,
    b.millisecond,
  );
}

/// "Hoje" em Brasília, à meia-noite.
DateTime hojeBrasilia([DateTime? utc]) {
  final a = agoraBrasilia(utc);
  return DateTime(a.year, a.month, a.day);
}
