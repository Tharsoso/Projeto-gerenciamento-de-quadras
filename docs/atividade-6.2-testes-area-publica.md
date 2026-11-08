# Atividade 6.2 · Testes automatizados da área pública (H1, H2, H6 · RF01–RF09 · RNF08, RNF10)

Autor: Arthur · Branch: `feat/6.2-testes-area-publica`, criada a partir da `main`.

## 1. O que foi feito

Dois arquivos de teste novos cobrem o que a área pública ainda não tinha: a **home com os horários** (consulta, H1) e a **tela de confirmação** da reserva (H2 e H6). Os casos vêm do documento da 6.1 (`docs/atividade-6.1-casos-de-teste.md`).

| Arquivo | O que tem |
|---|---|
| `test/consulta_horarios_test.dart` | 9 testes da home: quadras e preços do dia, horários que não abrem reserva, toque em horário livre, setas e botão HOJE, dia sem quadras, erro de conexão, atualização por Realtime e ícone do proprietário |
| `test/sucesso_test.dart` | 3 testes da confirmação: código visível sem usar o WhatsApp, "Ver outros horários" e proteção da rota `/sucesso` |
| `lib/services/quadras_service.dart` | Uma mudança de uma palavra (seção 2), que permite trocar o serviço por um falso nos testes |

O restante da área pública já era coberto por `reserva_test.dart` (formulário, validações, limite diário, horário tomado) e `comprovante_test.dart` (mensagem e link do WhatsApp).

## 2. Mudança no código

A home recebe o serviço de dados pelo parâmetro `servico`, mas o método `assinarOcupacoes` devolvia sempre um `RealtimeChannel`, que não dá para falsificar num teste. Ele passou a poder devolver `null`:

```dart
// antes
RealtimeChannel assinarOcupacoes(void Function() onChange) {
// depois
RealtimeChannel? assinarOcupacoes(void Function() onChange) {
```

Nada muda para quem usa o app: o serviço real continua devolvendo o canal. A tela já conferia `if (c != null)` antes de remover o canal, então só o serviço falso devolve `null`.

## 3. Como os testes funcionam

- **Serviço falso (`QuadrasServiceFalso`):** devolve os horários que cada teste escolhe, anota os dias pedidos e guarda a função que a tela registra para o Realtime. Para simular "outro cliente reservou", o teste muda a resposta e chama essa função.
- **Roteador mínimo:** a home é aberta num `GoRouter` com `/reserva` e `/login` de mentira, que só mostram o que receberam. Assim o teste confere para onde a home levou e com quais dados.
- **Sem `pumpAndSettle()`:** a home tem animações que não terminam. Os testes usam `pump()` e `pump(Duration(...))`.
- **Dia de hoje:** vem de `agoraBrasilia()`, como a própria tela, e os dias são comparados por ano, mês e dia.

## 4. Casos cobertos

| Caso (6.1) | Teste |
|---|---|
| CT-H1-01 | `consulta_horarios_test.dart`: mostra as quadras do dia com os horários e os preços |
| CT-H1-02 | `consulta_horarios_test.dart`: a seta ‹ não volta para antes de hoje e a seta › avança o dia |
| CT-H1-04, CT-H5-01 | `consulta_horarios_test.dart`: horário reservado, bloqueado e passado não abrem a reserva |
| CT-H1-06 | `consulta_horarios_test.dart`: tocar em um horário livre abre a reserva com os dados escolhidos |
| CT-H1-07 | `consulta_horarios_test.dart`: dia sem quadras mostra "fechada neste dia" |
| CT-H1-08 | `consulta_horarios_test.dart`: falha na consulta mostra o erro e deixa tentar de novo |
| CT-H1-10 | `consulta_horarios_test.dart`: o botão HOJE volta para o dia de hoje |
| CT-H1-11, RNF08 | `consulta_horarios_test.dart`: quando o Realtime avisa uma mudança, a consulta recarrega sozinha |
| CT-H7-10 | `consulta_horarios_test.dart`: o ícone da área do proprietário leva ao login |
| CT-H6-06, CT-RNF10-01 | `sucesso_test.dart`: a tela de sucesso mostra o código mesmo sem usar o WhatsApp |
| CT-H2-14 | `sucesso_test.dart`: "Ver outros horários" volta para a home |
| CT-H2-13 | `sucesso_test.dart`: abrir /sucesso sem ter feito a reserva volta para a home |

## 5. O que ficou de fora

- **Calendário "TROCAR DATA":** a tela abre o seletor de datas a partir de hoje (`firstDate`), mas esse seletor depende dos textos em português e não foi testado aqui. Entra no teste do sistema da 6.4.
- **Tempo de até 5 segundos (RNF08):** o teste confere que a tela recarrega ao receber o aviso. O tempo real da mudança no banco até a tela é medido na 6.5.

## 6. Como conferir

```bash
flutter test test/consulta_horarios_test.dart
flutter test test/sucesso_test.dart
flutter test
flutter analyze
```
