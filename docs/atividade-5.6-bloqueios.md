# Atividade 5.6 · Bloqueio de horários para manutenção (H5 · RF17)

Autor: Davi · Branch: `feat/5.6-bloqueios` (criada a partir da `feat/5.3-horarios`, que
ainda não entrou no `main`).

## 1. O que foi feito

O proprietário bloqueia um horário livre de uma quadra (manutenção, evento) e desbloqueia
quando quiser. O horário bloqueado aparece em **marrom** na consulta pública, em tempo real,
e não pode ser reservado. O visual segue a tela "Bloqueios" do protótipo Ace Saibro.

| Arquivo | O que tem |
|---|---|
| `lib/admin/bloqueios_page.dart` | Tela: bloqueios futuros, botão "Novo bloqueio" e diálogo (quadra, data, hora livre, motivo) |
| `lib/admin/bloqueios_repositorio.dart` | `BloqueiosRepositorio` (interface), `SupabaseBloqueiosRepositorio` e `traduzirErroBloqueio` |
| `lib/models/bloqueio.dart` | `Bloqueio`, `HorariosBloqueaveis`, `dataIso`, `dataBr` |
| `lib/tema/ace_cores.dart` | Novas cores `marrom` / `marromClaro` (`--brown` do protótipo) |
| `lib/tema/ace_componentes.dart` | `AceChip` agora encolhe com reticências em vez de estourar |
| `lib/app.dart` | Rota `/admin/bloqueios` (exige login) e parâmetro `bloqueios` no `App` |
| `lib/admin/painel_page.dart` | O módulo "BLOQUEIOS" do painel deixou de ser "Em breve" |
| `test/bloqueios_test.dart` | 11 testes |

## 2. Conversa com o banco

| Ação | Chamada |
|---|---|
| Listar | `from('bloqueios').select('id, quadra_id, data, hora_inicio, motivo, quadras(nome)').gte('data', hoje)` |
| Horas livres | `rpc('horarios_do_dia', {p_data})`, filtrando a quadra e `status` `livre` ou `sem_preco` |
| Quadras | `from('quadras').select(...).eq('ativa', true)` |
| Bloquear | `from('bloqueios').insert({quadra_id, data, hora_inicio, motivo})` |
| Desbloquear | `from('bloqueios').delete().eq('id', id)` |

As horas livres vêm da **mesma função da consulta pública** (`horarios_do_dia`), então o
diálogo oferece exatamente o que o cliente veria como livre: dentro do funcionamento (5.3),
sem reserva, sem bloqueio e que ainda não passou. Hora "sem preço" também pode ser bloqueada.

Depois do `insert`/`delete`, o gatilho `bloqueios_ocupacao` atualiza `ocupacoes`, e a
consulta pública (que assina essa tabela no Realtime) muda sozinha.

## 3. Regras e erros

| Situação | Quem barra | O que aparece |
|---|---|---|
| Horário que já passou | Banco (`HORARIO_PASSADO`) e a lista de horas | "Não é possível bloquear um horário que já passou." |
| Horário com reserva (H5 alt.) | Banco (`HORARIO_RESERVADO`) e a lista de horas | "Existe um agendamento neste horário. Cancele a reserva do cliente antes de realizar o bloqueio." |
| Mesmo horário bloqueado duas vezes | Banco (`unique`, 23505) | "Este horário já está bloqueado." |
| Quadra fechada no dia | Tela | "A quadra está fechada neste dia da semana." e Salvar desligado |
| Sem login | RLS (42501) | "Sua sessão expirou. Entre novamente." e vai para o login |

Se uma reserva entrar entre a busca das horas e o clique em "Bloquear horário", o banco
recusa. A tela mostra o erro, mantém o diálogo aberto e recarrega as horas livres.

Para liberar um horário reservado, o proprietário precisa primeiro cancelar a reserva
(5.5, depois da 5.4 do João).

## 4. Como conferir

1. Logado, abrir o painel → BLOQUEIOS → "Novo bloqueio".
2. Escolher Saibro 1, amanhã, 10:00–11:00, motivo "Manutenção do piso" → Bloquear.
3. Em outra aba, na consulta pública de amanhã, o bloco 10h da Saibro 1 fica marrom, sem
   precisar recarregar.
4. Fazer uma reserva às 11h e abrir "Novo bloqueio" para o mesmo dia: 11:00 não aparece
   entre as horas livres.
5. Remover o bloqueio das 10h → o bloco volta a ficar livre na consulta pública.
