# Atividade 5.5 · Cancelamento de reservas com log (H3 · RF15–RF16 · RNF06)

Autor: Davi · Branch: `feat/5.5-cancelamento`, criada a partir da
`feat/5.4-consulta-agendamentos` do João (PR #10), que ainda não entrou no `main`.

## 1. O que foi feito

Na tela **Reservas** (5.4), cada reserva confirmada que ainda não terminou ganha um botão
**Cancelar**. Ele abre um diálogo com a quadra, o código, a data, a hora, o cliente e o
valor, mais um campo de motivo opcional. Ao confirmar:

- a reserva vira `cancelada`, sem ser apagada (exclusão lógica, RF15);
- o cancelamento fica registrado em `log_cancelamentos` com quem cancelou, quando e o
  motivo (RF16, RNF06);
- o horário volta a ficar livre na consulta pública em tempo real (gatilho em `ocupacoes`);
- a lista recarrega e mostra a reserva como "Cancelada", com o motivo.

Reservas que já terminaram ou que já foram canceladas **não mostram o botão** (H3 alt. 1).
Uma reserva em andamento (que já começou e ainda não acabou) pode ser cancelada, como
sugere a revisão de requisitos, e o diálogo avisa que ela está em andamento.

| Arquivo | O que tem |
|---|---|
| `lib/admin/cancelamento.dart` | `CancelamentoRepositorio`, `SupabaseCancelamentoRepositorio`, `traduzirErroCancelamento`, `podeCancelar`, `emAndamento`, `acoesCancelamento`, o botão e o diálogo |
| `lib/app.dart` | A rota `/admin/reservas` passa `acoes: acoesCancelamento(...)` para a `AgendamentosPage`, e o `App` ganhou o parâmetro `cancelamento` |
| `test/cancelamento_test.dart` | 14 testes |

A tela da 5.4 não mudou: o cancelamento entra pelo parâmetro `acoes` que o João deixou
pronto. O banco também não mudou, porque a `cancelar_reserva` já estava na migration
inicial.

## 2. Conversa com o banco

| Ação | Chamada |
|---|---|
| Cancelar | `rpc('cancelar_reserva', {p_reserva_id, p_motivo})`, com motivo vazio enviado como `null` |
| Recarregar a lista | o `listar` da 5.4 (`reservas` + `log_cancelamentos(motivo)`) |

A `cancelar_reserva` faz tudo numa transação, com a reserva travada (`for update`): confere
o login, o status e o horário, atualiza a reserva e grava o log. O `cancelado_por` é o
`auth.uid()` do proprietário logado.

## 3. Regras e erros

| Situação | Quem barra | O que aparece |
|---|---|---|
| Reserva que já terminou | Tela (sem botão) e banco (`RESERVA_PASSADA`) | Botão escondido |
| Reserva já cancelada (ex.: em outra aba) | Tela (sem botão) e banco (`RESERVA_JA_CANCELADA`) | "Esta reserva já está cancelada.", diálogo fecha e a lista recarrega |
| Reserva não existe mais | Banco (`RESERVA_NAO_ENCONTRADA`) | Mensagem do banco e a lista recarrega |
| Sem internet | Tela | Erro dentro do diálogo, que continua aberto para tentar de novo |
| Sem login | Banco (`NAO_AUTORIZADO`) ou RLS (42501) | "Sua sessão expirou. Entre novamente." e vai para o login |

O botão usa a hora do aparelho para decidir se a reserva já terminou, e o banco confere de
novo com o horário de Brasília (`agora_local()`). Se os dois relógios divergirem, a palavra
final é do banco.

Em tela estreita (menos de 600 px), o botão vira só um ícone para caber na linha.

## 4. Como conferir

1. Na consulta pública, reservar um horário de amanhã (ex.: Saibro 1, 19h).
2. Logado, abrir o painel → RESERVAS. A reserva aparece com o botão "Cancelar".
3. Cancelar com o motivo "Cliente avisou que não vem". Aparece o aviso, e a reserva fica
   "Cancelada" com o motivo.
4. Na consulta pública de amanhã, o horário das 19h da Saibro 1 volta a ficar livre sem
   recarregar a página.
5. Reservas de dias anteriores ou de horários que já terminaram não têm botão.
6. No Supabase (Table Editor → `log_cancelamentos`), a linha nova traz o `reserva_id`, o
   `cancelado_por`, o `cancelado_em` e o motivo.
