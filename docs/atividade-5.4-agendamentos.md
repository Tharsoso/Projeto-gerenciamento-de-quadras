# Atividade 5.4 · Consulta de agendamentos realizados (H11 · RF14)

Autor: João · Branch: `feat/5.4-consulta-agendamentos` · Para: Davi (cancelamento da 5.5)

## 1. O que foi feito

O proprietário consulta as reservas pelo card **Reservas** do painel (`/admin/reservas`),
filtrando por período, quadra e telefone ou nome. A tela só lê: cancelar é da 5.5. O visual
segue o protótipo **Ace Saibro** (tela "Reservas" da área admin) e usa os componentes de
`lib/tema/ace_componentes.dart`.

| Arquivo | O que tem |
|---|---|
| `lib/admin/agendamentos_page.dart` | Tela: filtros, resumo, lista e o ponto de encaixe `acoes` |
| `lib/admin/agendamentos_repositorio.dart` | `AgendamentosRepositorio` (interface), `SupabaseAgendamentosRepositorio` (real) e `traduzirErroAgendamentos` |
| `lib/models/agendamento.dart` | `Agendamento` (linha de `reservas`) e `FiltroAgendamentos` |
| `test/agendamentos_test.dart` | 13 testes com um repositório falso que aplica os filtros como o banco |
| `lib/app.dart` | Rota `/admin/reservas` dentro do `ShellRoute` (exige login) e parâmetro `agendamentos` |
| `lib/admin/painel_page.dart` | Card "Reservas" ativado |

### Conversa com o banco

O RLS (`proprietario le reservas`) libera `select` em `reservas` para o usuário logado.

| Ação | Chamada |
|---|---|
| Quadras do filtro | `from('quadras').select(...).order('nome')`, inclusive inativas |
| Listar | `from('reservas').select('id, quadra_id, data, hora_inicio, nome_cliente, telefone, valor, status, anonimizada, quadras(nome), log_cancelamentos(motivo)')` com `gte/lte('data')`, ordem por data e hora, no máximo 500 linhas |
| Filtro de quadra | `.eq('quadra_id', id)` |
| Busca com números | `.like('telefone', '%31999%')` |
| Busca com letras | `.ilike('nome_cliente', '%maria%')` |

O motivo do cancelamento vem de `log_cancelamentos(motivo)` e aparece na linha da reserva
cancelada. Reservas anonimizadas (`anonimizada = true`, após 12 meses) aparecem como
"Anonimizado (LGPD)" com o telefone mascarado.

| Erro | Onde aparece |
|---|---|
| Sem conexão | Alerta vermelho com "Tentar de novo" |
| `42501` ou `PGRST301` (sem login) | Volta para o login ("Sua sessão expirou") |
| Data inicial depois da final | Alerta, sem consultar o banco |

## 2. Para o Davi: encaixar o cancelamento (5.5)

A `AgendamentosPage` recebe um parâmetro opcional `acoes`, chamado para cada reserva da lista.
O widget que ele devolver aparece no fim da linha. Não precisa mexer na tela nem no repositório
da 5.4.

```dart
typedef AcoesAgendamento = Widget? Function(
    BuildContext context, Agendamento agendamento, VoidCallback recarregar);
```

- `agendamento`: a reserva da linha (`id`, `cancelada`, `data`, `hora`, `codigo`...).
- `recarregar`: chame depois de cancelar, para a lista buscar de novo e mostrar "Cancelada"
  com o motivo.
- Devolva `null` para não mostrar nada na linha (por exemplo, reserva já cancelada ou que já
  terminou; o banco recusa com `RESERVA_JA_CANCELADA` e `RESERVA_PASSADA`).

### Sugestão de ligação no `app.dart`

```dart
GoRoute(
  path: '/admin/reservas',
  builder: (context, state) => AgendamentosPage(
    repositorio: widget.agendamentos ??
        SupabaseAgendamentosRepositorio(Supabase.instance.client),
    aoVoltar: () => context.go('/admin'),
    aoSessaoExpirada: _expirarSessao,
    acoes: (context, a, recarregar) => a.cancelada
        ? null
        : BotaoCancelarReserva(agendamento: a, aoCancelar: recarregar), // widget da 5.5
  ),
),
```

O `BotaoCancelarReserva` (nome livre) abre o diálogo de motivo do protótipo e chama
`rpc('cancelar_reserva', params: {'p_reserva_id': a.id, 'p_motivo': motivo})`.

### Depois de ligar

- Em `lib/admin/painel_page.dart`, voltar a descrição do card Reservas para
  "Veja, filtre e cancele reservas." (hoje está "Veja e filtre as reservas por período.").
- O teste `ações extras aparecem em cada reserva (encaixe da 5.5)` em
  `test/agendamentos_test.dart` mostra como passar `acoes` num teste.

## 3. Como conferir

1. `flutter test`: os 13 testes de `test/agendamentos_test.dart` passam.
2. Rodar o app, entrar como proprietário e abrir **Reservas** no painel.
3. Conferir que aparecem as reservas de 7 dias atrás até 14 dias à frente.
4. Filtrar por uma quadra e por um telefone (só números) e conferir a lista.
