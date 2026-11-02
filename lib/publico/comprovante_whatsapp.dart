import '../formatos.dart';
import 'reservas_repositorio.dart';

/// Número do proprietário que recebe o comprovante, só dígitos com DDI: `5531988887777`.
/// Vem do `env.json` (`WHATSAPP_PROPRIETARIO`). Sem ele, o WhatsApp abre e o cliente
/// escolhe para quem enviar (ou guarda para si).
const numeroWhatsAppProprietario = String.fromEnvironment('WHATSAPP_PROPRIETARIO');

/// Texto do comprovante (4.4), igual ao do protótipo.
String mensagemComprovante(ReservaConfirmada r) {
  final inicio = int.parse(r.hora.substring(0, 2));
  final fim = '${(inicio + 1).toString().padLeft(2, '0')}:00';
  return 'Reserva confirmada ✅\n'
      '\n'
      '🎾 Quadra: ${r.quadra}\n'
      '📅 Data: ${formatarData(r.data)}\n'
      '⏰ Horário: ${r.hora} às $fim\n'
      '💰 Valor: ${formatarReal(r.valor)}\n'
      '👤 Nome: ${r.nome}\n'
      '📞 Telefone: ${mascararTelefone(r.telefone)}\n'
      '🔖 Código: ${r.codigo}\n'
      '\n'
      'Obrigado por reservar na Ace Saibro!';
}

/// Link `wa.me` com o comprovante já escrito. Espaços viram `%20` (não `+`), que o
/// WhatsApp mostra certo em todos os aparelhos.
Uri linkComprovante(ReservaConfirmada r, {String numero = numeroWhatsAppProprietario}) {
  final digitos = numero.replaceAll(RegExp(r'\D'), '');
  return Uri.parse('https://wa.me/$digitos?text=${Uri.encodeComponent(mensagemComprovante(r))}');
}
