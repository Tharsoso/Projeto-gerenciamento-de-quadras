# Atividade 5.3 · Horários de funcionamento por quadra (H9 · RF13)

Autor: Davi · Branch: `feat/5.3-horarios` (criada a partir da `feat/5.2-quadras`) ·
Ligar ao login: mesmo passo a passo de [`atividade-5.2-quadras.md`](atividade-5.2-quadras.md).

## 1. O que foi feito

O proprietário define, para cada quadra e cada dia da semana, se abre e em que horário
(horas cheias). Cada hora aberta vira um bloco reservável de 1 hora na consulta pública.
O visual segue a tela "Horários" do protótipo Ace Saibro.

| Arquivo | O que tem |
|---|---|
| `lib/admin/horarios_page.dart` | Tela: um cartão por quadra, 7 dias (seg → dom), interruptor Aberto/Fechado, abertura e fechamento, botão Salvar |
| `lib/admin/horarios_repositorio.dart` | `HorariosRepositorio` (interface) e `SupabaseHorariosRepositorio` |
| `lib/models/funcionamento.dart` | `Intervalo`, `Semana`, `ReservaFutura` e `reservasForaDoHorario` (regra do aviso) |
| `lib/tema/ace_componentes.dart` | Componentes do protótipo, agora compartilhados entre 5.2 e 5.3 (`AceChip`, `AceAlerta`, `AceEstilo`, `aceAviso`, `aceBarraAdmin`) |
| `test/horarios_test.dart` | 12 testes (regra do aviso, salvar, fechar dia, erro, celular 360px) |
| `lib/app.dart` / `lib/main.dart` | Rota `/admin/horarios` (no `app.dart`, protegida pelo login) |
| Painéis | Atalho "Horários de funcionamento" nos dois painéis |

## 2. Conversa com o banco

Tabela `horarios_funcionamento`: uma linha por quadra e dia (`0` = domingo … `6` = sábado,
igual ao `extract(dow)`). **Dia sem linha = fechado.** `fechamento` 22:00 = último bloco
21h–22h; aceita até 24:00.

| Ação | Chamada |
|---|---|
| Carregar | `from('quadras').select(...)` + `from('horarios_funcionamento').select(...)` |
| Abrir / alterar dias | `upsert([...], onConflict: 'quadra_id,dia_semana')` |
| Fechar dias | `delete().eq('quadra_id', id).inFilter('dia_semana', [...])` |
| Aviso de impacto | `from('reservas').select(...).eq('status','confirmada').gte('data', hoje)` |

Só são gravadas as quadras que mudaram (o botão mostra quantas).

## 3. Regras

- **Fechamento antes da abertura:** a linha fica vermelha e o Salvar desliga. O banco
  também recusa (`INTERVALO_INVALIDO`).
- **H9 alternativo:** se o novo horário deixa de fora reservas futuras já confirmadas, a tela
  lista quais são (quadra, dia, hora, cliente) e pergunta. **As reservas continuam
  valendo**, nada é cancelado. Novas reservas só entram no horário novo.
- Horas que passam a abrir e não têm preço aparecem como "sem preço" na consulta até o
  proprietário cadastrar os preços (5.7).
- Quadra recém-criada na 5.2 não tem linha nenhuma, ou seja, fica fechada em todos os dias e
  não aparece na consulta. O cartão avisa isso.

## 4. Login (o mesmo da 5.2)

Sem sessão do Supabase Auth, o RLS deixa só **ler** `horarios_funcionamento`. Salvar
devolve "Sua sessão expirou", e a lista de `reservas` vem vazia, então o aviso de impacto
não aparece. Mas como salvar também falha, nada é gravado sem o aviso. Tudo volta ao normal
quando o `main.dart` rodar o `App` com `SupabaseAutenticacao` (ver a seção 4 da 5.2). Para
testar dentro do `App`: `App(auth: ..., horarios: HorariosFalsos(...))`.

## 5. Como conferir

1. Logado, abrir Horários: Saibro 1 deve vir seg–sex 07:00–22:00 e sáb–dom 08:00–18:00 (seed).
2. Mudar sábado para 08:00–12:00 → o botão mostra "SALVAR (1 QUADRA ALTERADA)" → salvar.
3. Na consulta pública, num sábado, a Saibro 1 deve ir só até o bloco 11h–12h.
4. Reservar a Saibro 1 num sábado às 11h e reduzir o sábado para 08:00–10:00 → aparece o
   aviso com essa reserva. Confirmar → ela continua na agenda.
5. Fechar o domingo → o domingo some da consulta dessa quadra.
