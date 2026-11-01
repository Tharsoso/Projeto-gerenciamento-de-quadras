/// Valor em reais no formato brasileiro: `R$ 60,00` (RNF07).
String formatarReal(double valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

/// Data no formato brasileiro: `dd/mm/aaaa`.
String formatarData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Telefone só com dígitos para exibição: `31999990000` vira `(31) 99999-0000`.
String mascararTelefone(String digitos) {
  final s = digitos.length > 11 ? digitos.substring(0, 11) : digitos;
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i == 0) b.write('(');
    if (i == 2) b.write(') ');
    if (i == 7) b.write('-');
    b.write(s[i]);
  }
  return b.toString();
}
