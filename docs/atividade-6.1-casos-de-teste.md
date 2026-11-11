# Atividade 6.1 · Especificação de casos de teste (H1–H12 · RF01–RF23 · RNF)

Autor: Arthur · Branch: `feat/6.1-casos-de-teste`, criada a partir da `main`.

## 1. O que foi feito

Este documento lista os **casos de teste** do sistema, um conjunto para cada história de usuário (H1 a H12) do Documento de Visão (versão 1.0, 29/set/26), mais um bloco para os requisitos não funcionais. Para cada caso há o que fazer, o resultado esperado, a prioridade e **onde ele é verificado**: em um teste automatizado que já existe em `test/` ou na task que ainda vai verificá-lo (6.2 a 6.7).

Ele serve de base para as outras tasks da frente de qualidade:

| Task | O que usa deste documento |
|---|---|
| 6.2 | Casos da área pública: já cobertos por `consulta_horarios_test.dart` e `sucesso_test.dart` |
| 6.3 | Casos da área administrativa: já cobertos por `admin_acesso_test.dart` e pelos testes de cada módulo |
| 6.4 | Regras do banco: `supabase/testes/reservas.sql`. Jornadas entre telas: `jornadas_test.dart`. Teste do sistema completo (manual): casos marcados com "a fazer na 6.4 (sistema)" |
| 6.5 | Casos de requisitos não funcionais (seção 5): `responsividade_test.dart`, `contraste_test.dart`, `supabase/testes/desempenho.sql` e as medições manuais de `atividade-6.5-testes-nao-funcionais.md` |
| 6.7 | O roteiro de aceitação com o proprietário parte dos cenários principais de cada H |

## 2. Como os casos foram derivados

1. **Cenários do Documento de Visão (seção 4.3):** cada cenário principal e alternativo virou um caso, com o mesmo texto "Dado / Quando / Então".
2. **Requisitos funcionais e não funcionais:** cada RF (RF01 a RF23) e cada RNF listado tem pelo menos um caso (matriz da seção 6).
3. **Casos de borda e de erro:** valores-limite (limite de 2 reservas por dia, fechamento às 22h exclusivo, reserva das 23h que termina à meia-noite, período de mais de 62 dias) e entradas inválidas (telefone sem o 9 ou sem DDD, nome curto, período invertido, sem conexão, sessão expirada).
4. **Comportamento já implementado:** os testes existentes em `test/` e as regras das migrations em `supabase/migrations/` foram lidos para registrar o que cada um já verifica.

## 3. Como ler as tabelas

- **ID:** `CT-H<história>-<número>`. Os casos de requisitos não funcionais usam `CT-RNF<número>-<número>`.
- **Tipo:** *Principal* (caminho feliz), *Alternativo* (variação prevista no Documento de Visão), *Erro* (entrada ou situação inválida) e *Borda* (valor-limite ou situação rara).
- **Prioridade:** parte da prioridade do requisito (Must = Alta, Should = Média, Could = Baixa) e pode baixar um nível em casos de borda raros.
- **Verificação:** o arquivo de teste que já cobre o caso (com o começo do nome do teste) ou a task que vai cobri-lo. Um caso pode ter as duas coisas: parte já testada (por exemplo, na tela) e parte a fazer (por exemplo, no banco).

## 4. Casos de teste por história

### H1 · Consultar quadras e horários (RF01, RF02, RF03)

| ID | Tipo | Dado / Quando | Resultado esperado | Prio. | Verificação |
|---|---|---|---|---|---|
| CT-H1-01 | Principal | Dado que o cliente acessa a consulta, quando escolhe a data de hoje | Vê as quadras ativas e os blocos de 1 hora (livres com preço) | Alta | `consulta_horarios_test.dart` ("mostra as quadras do dia…")<br>`supabase/testes/reservas.sql` |
| CT-H1-02 | Alternativo | Quando tenta escolher uma data passada | O sistema impede: a seta "‹" não volta para antes de hoje e o calendário abre só a partir de hoje | Alta | `consulta_horarios_test.dart` ("a seta ‹ não volta…")<br>a fazer na 6.4 (sistema) |
| CT-H1-03 | Borda | Quando consulta o dia de hoje | Horários que já passaram aparecem como "passado" e não podem ser reservados | Alta | `supabase/testes/reservas.sql` |
| CT-H1-04 | Erro | Quando um horário está reservado ou bloqueado | Ele não aparece como livre | Alta | `consulta_horarios_test.dart` ("horário reservado, bloqueado e passado…")<br>`supabase/testes/reservas.sql` |
| CT-H1-05 | Erro | Quando uma quadra está inativa | Ela não aparece na consulta | Alta | `supabase/testes/reservas.sql` |
| CT-H1-06 | Principal | Quando toca em um horário livre | Abre a reserva já com quadra, data, hora e valor | Alta | `consulta_horarios_test.dart` ("tocar em um horário livre…") |
| CT-H1-07 | Borda | Quando escolhe um dia em que nenhuma quadra funciona | Mostra "FECHADA NESTE DIA" e a orientação de escolher outra data | Média | `consulta_horarios_test.dart` ("dia sem quadras…") |
| CT-H1-08 | Erro | Quando a consulta falha (sem conexão) | Mostra "Erro ao carregar" e o botão "Tentar novamente" | Média | `consulta_horarios_test.dart` ("falha na consulta…") |
| CT-H1-09 | Principal | Quando a consulta não deve expor dados de clientes | A resposta da consulta não traz nome nem telefone | Alta | `supabase/testes/reservas.sql`<br>manual: curl com a anon key (seção 8 da 6.5) |
| CT-H1-10 | Principal | Quando troca de dia pelas setas ou pelo botão HOJE | A consulta recarrega para o dia escolhido | Alta | `consulta_horarios_test.dart` ("a seta ‹ não volta…")<br>`consulta_horarios_test.dart` ("o botão HOJE volta…") |
| CT-H1-11 | Principal | Quando outro cliente reserva enquanto a consulta está aberta | A consulta recarrega sozinha e o horário deixa de ser livre | Alta | `consulta_horarios_test.dart` ("quando o Realtime avisa…")<br>manual: ST-04 da 6.4 (tempo até a tela) |

### H2 · Agendar horário sem login (RF04, RF05, RF06, RF08, RF20)

| ID | Tipo | Dado / Quando | Resultado esperado | Prio. | Verificação |
|---|---|---|---|---|---|
| CT-H2-01 | Principal | Dado que clicou em um horário livre, quando informa nome e telefone corretos | Confirma a reserva e exibe quadra, data, horário, valor e o código | Alta | `reserva_test.dart` ("dados válidos reservam e abrem a confirmação…")<br>`sucesso_test.dart` ("a tela de sucesso mostra o código…")<br>`supabase/testes/reservas.sql` |
| CT-H2-02 | Alternativo | Quando informa telefone sem o 9 ou sem DDD | Exige a correção e não envia ao banco | Alta | `reserva_test.dart` ("nome curto e telefone inválido não chegam ao banco…")<br>`supabase/testes/reservas.sql` |
| CT-H2-03 | Erro | Quando deixa o nome vazio ou com menos de 3 caracteres | Exige o nome completo e não envia ao banco | Alta | `reserva_test.dart` ("nome curto e telefone inválido não chegam ao banco…")<br>`supabase/testes/reservas.sql` |
| CT-H2-04 | Borda | Quando digita o telefone | A máscara (DD) 9XXXX-XXXX é aplicada durante a digitação | Média | `reserva_test.dart` ("telefone recebe a máscara ao digitar…") |
| CT-H2-05 | Erro | Quando outro cliente reserva o mesmo horário antes | Avisa para escolher outro horário (nunca duas reservas no mesmo horário) | Alta | `reserva_test.dart` ("horário tomado por outro cliente…")<br>`jornadas_test.dart` ("dois clientes disputam o mesmo horário…")<br>`supabase/testes/reservas.sql` |
| CT-H2-06 | Erro | Quando está sem conexão | Mostra a mensagem e deixa tentar de novo | Média | `reserva_test.dart` ("sem conexão mostra a mensagem…") |
| CT-H2-07 | Borda | Quando toca duas vezes seguidas em confirmar | Só uma reserva é criada | Alta | `reserva_test.dart` ("dois toques seguidos…") |
| CT-H2-08 | Borda | Quando abre /reserva sem ter escolhido um horário | Volta para a home | Média | `reserva_test.dart` ("abrir /reserva sem horário…") |
| CT-H2-09 | Principal | Quando a reserva é criada | O valor vem do banco e fica gravado na reserva | Média | `supabase/testes/reservas.sql` |
| CT-H2-10 | Principal | Quando o cliente não está logado | Consegue reservar mesmo assim (papel anônimo) | Alta | `supabase/testes/reservas.sql` |
| CT-H2-11 | Erro | Quando o horário escolhido já passou | A reserva é recusada | Alta | `supabase/testes/reservas.sql` |
| CT-H2-12 | Principal | Quando abre a tela de reserva | Mostra o aviso LGPD (para que servem os dados e por quanto tempo ficam) | Média | `reserva_test.dart` ("a tela de reserva diz para que servem os dados…") |
| CT-H2-13 | Borda | Quando abre /sucesso sem ter feito a reserva | Volta para a home | Média | `sucesso_test.dart` ("abrir /sucesso sem ter feito a reserva…") |
| CT-H2-14 | Principal | Quando toca em "Ver outros horários" na confirmação | Volta para a home | Média | `sucesso_test.dart` (""Ver outros horários" volta para a home…") |
| CT-H2-15 | Erro | Quando o horário não é de hora cheia (por exemplo 10:30) | A reserva é recusada | Média | `supabase/testes/reservas.sql` |

### H3 · Cancelar agendamentos (RF15, RF16)

| ID | Tipo | Dado / Quando | Resultado esperado | Prio. | Verificação |
|---|---|---|---|---|---|
| CT-H3-01 | Principal | Dado que o proprietário abre uma reserva futura, quando solicita o cancelamento | A reserva é cancelada logicamente e o horário volta a ficar livre | Alta | `cancelamento_test.dart` ("cancela com motivo e a lista mostra a reserva cancelada…")<br>`jornadas_test.dart` ("cliente reserva, o proprietário vê a reserva e a cancela…")<br>`supabase/testes/reservas.sql` |
| CT-H3-02 | Principal | Quando cancela sem informar o motivo | Cancela do mesmo jeito (o motivo é opcional) | Média | `cancelamento_test.dart` ("sem motivo também cancela…") |
| CT-H3-03 | Alternativo | Quando a reserva já terminou ou já está cancelada | O botão de cancelar não aparece (e o banco também recusa) | Alta | `cancelamento_test.dart` ("botão só nas reservas que ainda dá para cancelar…")<br>`supabase/testes/reservas.sql` |
| CT-H3-04 | Borda | Quando a reserva está em andamento | Pode ser cancelada e o diálogo avisa que está em andamento | Média | `cancelamento_test.dart` ("reserva em andamento avisa no diálogo…") |
| CT-H3-05 | Borda | Quando a reserva é das 23h | Termina à meia-noite do dia seguinte e só pode ser cancelada até lá | Média | `cancelamento_test.dart` ("reserva das 23h termina à meia-noite…") |
| CT-H3-06 | Alternativo | Quando escolhe "Manter reserva" no diálogo | Fecha o diálogo sem cancelar | Média | `cancelamento_test.dart` (""Manter reserva" fecha sem cancelar…") |
| CT-H3-07 | Erro | Quando a reserva já foi cancelada em outra aba | Avisa e recarrega a lista | Média | `cancelamento_test.dart` ("já cancelada por outra aba…")<br>`supabase/testes/reservas.sql` |
| CT-H3-08 | Erro | Quando está sem internet no diálogo | O diálogo continua aberto para tentar de novo | Média | `cancelamento_test.dart` ("sem internet…") |
| CT-H3-09 | Principal | Quando o cancelamento é feito | Fica registrado em log com data e motivo | Média | `supabase/testes/reservas.sql` |
| CT-H3-10 | Erro | Quando quem cancela não é o proprietário (ou a sessão expirou) | O banco recusa e a tela manda para o login | Alta | `cancelamento_test.dart` ("NAO_AUTORIZADO e 42501…")<br>`supabase/testes/reservas.sql` |
| CT-H3-11 | Erro | Quando tenta cancelar uma reserva que não existe | O banco recusa com o aviso de reserva não encontrada | Média | `supabase/testes/reservas.sql` |

### H4 · Tabela de preços e feriados (RF18, RF19, RF20, RF21)

| ID | Tipo | Dado / Quando | Resultado esperado | Prio. | Verificação |
|---|---|---|---|---|---|
| CT-H4-01 | Principal | Dado que o proprietário cadastra R$ 60 até 18h e R$ 90 das 18h às 22h | A tabela é salva | Média | `precos_test.dart` ("cenário principal: cadastra 60 até 18h…") |
| CT-H4-02 | Alternativo | Quando cadastra faixas que se sobrepõem (08h–18h e 17h–22h) | Barra o salvar e aponta as horas que se sobrepõem | Média | `precos_test.dart` ("sobreposição desliga o salvar…")<br>`supabase/testes/reservas.sql` |
| CT-H4-03 | Alternativo | Quando deixa um horário de funcionamento sem preço (lacuna) | Barra ao salvar e mostra qual horário ficou sem preço | Média | `precos_test.dart` ("remover a faixa noturna mostra a lacuna…")<br>`supabase/testes/reservas.sql` |
| CT-H4-04 | Alternativo | Quando sobe o preço de um tipo de dia que já tem reservas | Avisa quantas reservas mantêm o valor antigo | Média | `precos_test.dart` ("subir o noturno avisa quantas reservas…") |
| CT-H4-05 | Erro | Quando informa valor vazio, zero ou fim antes do início | Não salva e mostra o motivo | Média | `precos_test.dart` ("valor vazio, zero e fim antes do início…") |
| CT-H4-06 | Principal | Quando cadastra um feriado | O feriado entra na lista do ano | Baixa | `feriados_test.dart` ("cadastra feriado…") |
| CT-H4-07 | Erro | Quando cadastra feriado com descrição curta ou data repetida | Não salva | Baixa | `feriados_test.dart` ("descrição curta e data repetida…") |
| CT-H4-08 | Alternativo | Quando remove um feriado | Ele sai da lista | Baixa | `feriados_test.dart` ("remover tira da lista…") |
| CT-H4-09 | Principal | Quando um feriado cai em dia útil | Usa a tabela de preços de fim de semana e a reserva é marcada como feriado | Média | `precos_test.dart` ("feriado em dia útil usa a tabela de fim de semana…")<br>`supabase/testes/reservas.sql` |
| CT-H4-10 | Principal | Quando o preço muda depois de uma reserva feita | O valor já gravado na reserva não muda; reservas novas usam o preço novo | Média | `supabase/testes/reservas.sql` |
| CT-H4-11 | Erro | Quando quem altera preços não é o proprietário | O banco recusa e a tela manda para o login | Média | `precos_test.dart` ("NAO_AUTORIZADO = sessão expirada…")<br>`supabase/testes/reservas.sql` |

### H5 · Bloqueio para manutenção (RF17, RF03)

| ID | Tipo | Dado / Quando | Resultado esperado | Prio. | Verificação |
|---|---|---|---|---|---|
| CT-H5-01 | Principal | Dado que o proprietário bloqueia um horário livre com motivo | O horário some da tela do cliente | Alta | `bloqueios_test.dart` ("bloqueia um horário livre com motivo…")<br>`consulta_horarios_test.dart` ("horário reservado, bloqueado e passado…")<br>`supabase/testes/reservas.sql` |
| CT-H5-02 | Erro | Quando um cliente tenta reservar um horário bloqueado | A reserva é recusada | Alta | `supabase/testes/reservas.sql` |
| CT-H5-03 | Alternativo | Quando o proprietário remove o bloqueio | O horário volta a ficar livre | Média | `bloqueios_test.dart` ("remover libera o horário…")<br>`supabase/testes/reservas.sql` |
| CT-H5-04 | Alternativo | Quando tenta bloquear um horário que já tem reserva | O banco recusa e pede para cancelar a reserva antes | Média | `bloqueios_test.dart` ("reserva feita no meio do caminho…")<br>`supabase/testes/reservas.sql` |
| CT-H5-05 | Erro | Quando tenta bloquear um horário que já passou | O banco recusa | Baixa | `supabase/testes/reservas.sql` |
| CT-H5-06 | Borda | Quando a quadra está fechada no dia escolhido | O botão de salvar fica desligado | Baixa | `bloqueios_test.dart` ("quadra fechada no dia desliga o salvar…") |
| CT-H5-07 | Erro | Quando tenta bloquear um horário já bloqueado | Avisa que já está bloqueado | Baixa | `bloqueios_test.dart` ("unique = já bloqueado…") |

### H6 · Comprovante via WhatsApp (RF09, RNF10)

| ID | Tipo | Dado / Quando | Resultado esperado | Prio. | Verificação |
|---|---|---|---|---|---|
| CT-H6-01 | Principal | Dado que a reserva foi concluída, quando clica no botão do WhatsApp | Abre o WhatsApp (link wa.me) com o texto pronto | Baixa | `comprovante_test.dart` ("botão abre o WhatsApp com o comprovante…") |
| CT-H6-02 | Principal | Quando a mensagem é montada | Traz código, quadra, data, hora, valor, nome e telefone da reserva | Baixa | `comprovante_test.dart` ("mensagem traz todos os dados da reserva…") |
| CT-H6-03 | Alternativo | Quando o WhatsApp não abre ou o link é fechado | Continua na tela e avisa para anotar o código; o cliente pode clicar de novo | Baixa | `comprovante_test.dart` ("se o WhatsApp não abrir…") |
| CT-H6-04 | Borda | Quando o link é gerado | Vai para o número do proprietário, com o texto codificado; sem número configurado, o cliente escolhe o contato | Baixa | `comprovante_test.dart` ("link wa.me vai para o número…") |
| CT-H6-05 | Borda | Quando a reserva é às 21h | A mensagem mostra "21:00 às 22:00" | Baixa | `comprovante_test.dart` ("reserva às 21:00 termina às 22:00…") |
| CT-H6-06 | Principal | Quando o cliente não usa o link do WhatsApp | A reserva continua concluída e com o código visível | Média | `sucesso_test.dart` ("a tela de sucesso mostra o código…")<br>a fazer na 6.7 |

### H7 · Login do proprietário (RF10, RF11, RNF05)

| ID | Tipo | Dado / Quando | Resultado esperado | Prio. | Verificação |
|---|---|---|---|---|---|
| CT-H7-01 | Principal | Dado que está na tela de login, quando informa e-mail e senha válidos | Abre o painel do proprietário | Alta | `login_test.dart` ("login válido abre o painel…") |
| CT-H7-02 | Alternativo | Quando informa e-mail ou senha inválidos | Mostra mensagem genérica (sem dizer qual dado errou) | Alta | `login_test.dart` ("credenciais inválidas mostram mensagem genérica…") |
| CT-H7-03 | Erro | Quando deixa os campos vazios | Não tenta entrar | Média | `login_test.dart` ("campos vazios não tentam entrar…") |
| CT-H7-04 | Alternativo | Dado que ficou inativo por 30 minutos, quando tenta uma ação | A sessão é encerrada | Alta | `login_test.dart` ("30 min sem interação encerra a sessão…")<br>`admin_acesso_test.dart` ("30 min sem interação em…") |
| CT-H7-05 | Borda | Quando interage antes dos 30 minutos | A contagem de inatividade recomeça | Média | `login_test.dart` ("interação reinicia a contagem…") |
| CT-H7-06 | Alternativo | Quando acessa uma rota /admin sem estar logado | É levado para o login (todas as rotas /admin/*) | Alta | `login_test.dart` ("acesso direto a /admin sem login…")<br>`admin_acesso_test.dart` ("sem login vai para o login…") |
| CT-H7-07 | Borda | Quando já está logado e abre /login | Vai direto para o painel | Baixa | `login_test.dart` ("logado em /login vai direto para o painel…") |
| CT-H7-08 | Principal | Quando clica em Sair | A sessão é encerrada | Alta | `login_test.dart` ("botão Sair encerra a sessão…") |
| CT-H7-09 | Principal | Quando a senha é guardada | É guardada com hash (bcrypt/Argon2), nunca em texto puro | Alta | manual: conferir no Supabase Auth (seção 8 da 6.5) |
| CT-H7-10 | Principal | Dado que está na home pública, quando toca no ícone "Área do proprietário" | Vai para a tela de login | Média | `consulta_horarios_test.dart` ("o ícone da área do proprietário…") |
| CT-H7-11 | Principal | Quando o proprietário abre o painel | Mostra os sete módulos: quadras, horários, preços, bloqueios, reservas, faturamento e feriados | Alta | `admin_acesso_test.dart` ("o painel mostra os sete módulos…") |
| CT-H7-12 | Principal | Quando toca em um módulo do painel | Abre a tela daquele módulo | Alta | `admin_acesso_test.dart` ("abre a tela do módulo…") |

### H8 · Cadastro e gestão de quadras (RF12)

| ID | Tipo | Dado / Quando | Resultado esperado | Prio. | Verificação |
|---|---|---|---|---|---|
| CT-H8-01 | Principal | Dado que informa nome e piso, quando salva | A quadra é criada e fica ativa para os clientes | Alta | `quadras_test.dart` ("cria uma quadra nova…")<br>a fazer na 6.4 (sistema) |
| CT-H8-02 | Erro | Quando deixa o nome vazio | Não chega ao banco | Média | `quadras_test.dart` ("nome vazio não chega ao banco…") |
| CT-H8-03 | Alternativo | Quando usa um nome que já existe (sem diferenciar maiúsculas) | Mostra o erro no campo | Média | `quadras_test.dart` ("nome duplicado mostra o erro no campo…")<br>`supabase/testes/reservas.sql` |
| CT-H8-04 | Principal | Quando edita ou inativa uma quadra sem reservas futuras | A alteração é salva | Alta | `quadras_test.dart` ("edita e inativa uma quadra…")<br>`supabase/testes/reservas.sql` |
| CT-H8-05 | Alternativo | Quando inativa uma quadra com reserva futura | Impede e pede o cancelamento prévio | Alta | `quadras_test.dart` ("não inativa com reservas futuras…")<br>`supabase/testes/reservas.sql` |
| CT-H8-06 | Erro | Quando uma quadra está inativa | Não aceita reservas e some da consulta pública | Alta | `supabase/testes/reservas.sql` |
| CT-H8-07 | Principal | Quando abre a lista de quadras | Mostra ativas e inativas com piso e situação | Média | `quadras_test.dart` ("lista ativas e inativas…") |

### H9 · Horário de funcionamento (RF13)

| ID | Tipo | Dado / Quando | Resultado esperado | Prio. | Verificação |
|---|---|---|---|---|---|
| CT-H9-01 | Principal | Dado que define 07h–22h, quando salva | Gera blocos de 1 hora (15 blocos, das 07h às 21h) | Alta | `horarios_test.dart` ("altera o sábado e salva só a quadra alterada…")<br>`supabase/testes/reservas.sql` |
| CT-H9-02 | Alternativo | Quando reduz o horário e isso atinge reserva futura | Avisa o impacto e mantém as reservas antigas se o proprietário confirmar | Alta | `horarios_test.dart` ("reduzir com reserva futura avisa…") |
| CT-H9-03 | Alternativo | Quando desiste no aviso de impacto | Nada é gravado | Média | `horarios_test.dart` ("desistir no aviso de impacto…") |
| CT-H9-04 | Erro | Quando o fechamento é antes da abertura | Bloqueia o salvar | Alta | `horarios_test.dart` ("fechamento antes da abertura bloqueia o salvar…")<br>`supabase/testes/reservas.sql` |
| CT-H9-05 | Borda | Quando tenta reservar no horário de fechamento (22h) | Fica fora: o fechamento é exclusivo | Alta | `horarios_test.dart` ("fechamento é exclusivo…")<br>`supabase/testes/reservas.sql` |
| CT-H9-06 | Alternativo | Quando fecha um dia da semana | O dia sai da semana gravada e não há horários nem reservas nele | Média | `horarios_test.dart` ("fechar um dia tira ele da semana gravada…")<br>`supabase/testes/reservas.sql` |
| CT-H9-07 | Borda | Quando reserva na primeira e na última hora | 06h é recusada; 21h (última hora) é aceita | Média | `supabase/testes/reservas.sql` |

### H10 · Limite de 2 horários por dia por cliente (RF07)

| ID | Tipo | Dado / Quando | Resultado esperado | Prio. | Verificação |
|---|---|---|---|---|---|
| CT-H10-01 | Principal | Dado que o telefone tem 1 reserva no dia, quando tenta a 2ª | Cria normalmente | Alta | `jornadas_test.dart` ("o mesmo telefone reserva 2 horários no dia…")<br>`supabase/testes/reservas.sql` |
| CT-H10-02 | Alternativo | Quando tenta a 3ª reserva no mesmo dia | Impede e alerta sobre o limite | Alta | `reserva_test.dart` ("limite de 2 por dia avisa…")<br>`jornadas_test.dart` ("o mesmo telefone reserva 2 horários no dia…")<br>`supabase/testes/reservas.sql` |
| CT-H10-03 | Borda | Quando o mesmo telefone reserva em outro dia | Pode reservar (o limite vale por dia) | Alta | `supabase/testes/reservas.sql` |
| CT-H10-04 | Borda | Quando uma das 2 reservas do dia foi cancelada | A reserva cancelada não conta e a 3ª passa a ser aceita | Alta | `jornadas_test.dart` ("o proprietário cancela uma reserva e o telefone volta a poder reservar…")<br>`supabase/testes/reservas.sql` |
| CT-H10-05 | Borda | Quando o telefone é digitado com formatos diferentes | (31) 99999-0010 e 31999990010 contam como o mesmo cliente | Média | `supabase/testes/reservas.sql` |

### H11 · Consultar agendamentos realizados (RF14)

| ID | Tipo | Dado / Quando | Resultado esperado | Prio. | Verificação |
|---|---|---|---|---|---|
| CT-H11-01 | Principal | Dado que seleciona a data no painel, quando busca | Lista os agendamentos detalhados (confirmados e cancelados) | Alta | `agendamentos_test.dart` ("lista confirmadas e canceladas do período…")<br>`jornadas_test.dart` ("cliente reserva, o proprietário vê a reserva e a cancela…") |
| CT-H11-02 | Alternativo | Quando filtra por telefone | Restringe a lista ao cliente (a busca espera parar de digitar) | Alta | `agendamentos_test.dart` ("busca por telefone espera parar de digitar…") |
| CT-H11-03 | Alternativo | Quando filtra por quadra | Mostra só aquela quadra, inclusive se estiver inativa | Média | `agendamentos_test.dart` ("filtra por quadra, incluindo as inativas…") |
| CT-H11-04 | Borda | Quando não há reservas no período | Mostra o aviso para ajustar os filtros | Baixa | `agendamentos_test.dart` ("sem reservas mostra o aviso…") |
| CT-H11-05 | Erro | Quando o período está invertido | Não consulta e avisa | Média | `agendamentos_test.dart` ("período invertido não consulta e avisa…") |
| CT-H11-06 | Principal | Quando a reserva tem mais de 12 meses | Os dados aparecem anonimizados (sem nome nem telefone) | Alta | `agendamentos_test.dart` ("dados anonimizados não mostram nome nem telefone…") |
| CT-H11-07 | Erro | Quando a consulta falha ou a sessão expirou | Mostra o erro com "tentar de novo" ou manda para o login | Média | `agendamentos_test.dart` ("erro de conexão mostra a mensagem…")<br>`agendamentos_test.dart` ("sessão expirada manda para o login…") |
| CT-H11-08 | Principal | Quando uma reserva foi cancelada | A consulta mostra o motivo do cancelamento | Média | `supabase/testes/reservas.sql` |

### H12 · Relatório de locações por período (RF22, RF23)

| ID | Tipo | Dado / Quando | Resultado esperado | Prio. | Verificação |
|---|---|---|---|---|---|
| CT-H12-01 | Principal | Dado que informa o período, quando gera o relatório | Exibe as locações e o faturamento total | Alta | `faturamento_test.dart` ("mostra locações, faturamento e canceladas do mês…")<br>`supabase/testes/reservas.sql` |
| CT-H12-02 | Alternativo | Dado que existem cancelamentos no período | Eles não entram no somatório do faturamento | Alta | `supabase/testes/reservas.sql` |
| CT-H12-03 | Alternativo | Quando filtra por telefone completo | Mostra só as locações daquele cliente | Média | `faturamento_test.dart` ("filtra por telefone completo…")<br>`supabase/testes/reservas.sql` |
| CT-H12-04 | Erro | Quando informa telefone incompleto | Avisa e não consulta | Média | `faturamento_test.dart` ("telefone incompleto avisa e não consulta…") |
| CT-H12-05 | Erro | Quando o período está invertido | Não consulta e avisa | Média | `faturamento_test.dart` ("período invertido não consulta e avisa…")<br>`supabase/testes/reservas.sql` |
| CT-H12-06 | Borda | Quando o período não tem locações | Mostra o aviso no lugar do gráfico | Baixa | `faturamento_test.dart` ("sem locações mostra o aviso…") |
| CT-H12-07 | Borda | Quando o período tem mais de 62 dias | O gráfico mostra só os últimos 62 dias; a tabela e o gráfico mostram os mesmos valores | Baixa | `faturamento_test.dart` ("período longo mostra só os últimos 62 dias…") |
| CT-H12-08 | Erro | Quando quem consulta não é o proprietário | O banco recusa e a tela manda para o login | Alta | `faturamento_test.dart` ("sessão expirada manda para o login…")<br>`supabase/testes/reservas.sql` |

## 5. Requisitos não funcionais

| ID | RNF | Dado / Quando | Resultado esperado | Prio. | Verificação |
|---|---|---|---|---|---|
| CT-RNF04-01 | RNF04 | Visitante anônimo tenta ler reservas | Nenhum nome ou telefone é visível | Alta | `supabase/testes/reservas.sql`<br>manual: curl com a anon key (seção 8 da 6.5) |
| CT-RNF04-02 | RNF04 | Reserva com mais de 12 meses | Dados pessoais anonimizados e motivo de cancelamento apagado | Alta | `agendamentos_test.dart` ("dados anonimizados…")<br>`supabase/testes/lgpd.sql` |
| CT-RNF05-01 | RNF05 | 30 minutos sem interação | Sessão expira (ver CT-H7-04) | Alta | `login_test.dart` ("30 min sem interação…")<br>`admin_acesso_test.dart` ("30 min sem interação em…") |
| CT-RNF08-01 | RNF08 | Outro cliente reserva ou o proprietário bloqueia um horário | A consulta aberta reflete a mudança em até 5 segundos | Alta | `consulta_horarios_test.dart` ("quando o Realtime avisa…")<br>`supabase/testes/desempenho.sql` ("parte do banco…")<br>manual: ST-04 da 6.4 (tempo até a tela) |
| CT-RNF10-01 | RNF10 | Reserva concluída sem usar o link do WhatsApp | A reserva vale do mesmo jeito (ver CT-H6-06) | Média | `sucesso_test.dart` ("a tela de sucesso mostra o código…")<br>a fazer na 6.7 |
| CT-RNF11-01 | RNF11 | Abrir o sistema nas 2 últimas versões de Chrome, Firefox, Edge e Safari | Consulta, reserva e login funcionam | Média | manual: roteiro da seção 6 da 6.5 |
| CT-RNF12-01 | RNF12 | Telas entre 360 px e 1920 px | Sem rolagem horizontal e utilizáveis | Alta | `agendamentos_test.dart` ("cabe na tela de um celular…")<br>`bloqueios_test.dart` ("cabe em celular (360px)…")<br>`horarios_test.dart` ("cabe em celular (360px)…")<br>`responsividade_test.dart` ("cabe em…")<br>manual: preços, feriados e faturamento (seção 4 da 6.5) |
| CT-RNF13-01 | RNF13 | Disponibilidade do sistema no mês | Pelo menos 99% | Baixa | manual: monitoramento (seção 7 da 6.5) |
| CT-RNF14-01 | RNF14 | Backup diário do banco | Retenção de 30 dias e teste de restauração mensal | Média | `.github/workflows/backup.yml`<br>`.github/workflows/restauracao.yml`<br>manual: execuções na aba Actions (seção 7 da 6.5) |
| CT-RNF15-01 | RNF15 | Datas, horas e valores | Fuso America/Sao_Paulo, interface em pt-BR e valores no formato R$ 0,00 | Média | `fuso_test.dart` ("é sempre UTC−3…")<br>`fuso_test.dart` ("moeda e data no formato brasileiro…") |
| CT-RNF16-01 | RNF16 | Relatório de 12 meses | Gerado em até 5 segundos | Média | `supabase/testes/desempenho.sql` ("CT-RNF16-01…")<br>manual: tempo na tela (seção 5 da 6.5) |
| CT-RNF17-01 | RNF17 | Rodar flutter test --coverage e flutter analyze | Cobertura mínima de 70% e 0 erros no analyze | Média | `.github/workflows/ci.yml` ("flutter analyze…")<br>manual: cobertura com flutter test --coverage (seção 9 da 6.5) |
| CT-RNF18-01 | RNF18 | Contraste das cores e tamanho dos botões | Contraste WCAG 2.1 AA e áreas de toque de pelo menos 48x48 px | Média | `contraste_test.dart` ("contraste de pelo menos 4,5:1…")<br>manual: área de toque e Lighthouse (seção 3 da 6.5) |

## 6. Matriz de rastreabilidade

### 6.1 História → casos → testes existentes

| História | Casos | Já com teste em `test/` | Manual ou a fazer | Arquivos de teste existentes |
|---|---|---|---|---|
| H1 · Consultar quadras e horários | 11 | 11 | 0 | `consulta_horarios_test.dart`, `supabase/testes/reservas.sql` |
| H2 · Agendar horário sem login | 15 | 15 | 0 | `jornadas_test.dart`, `reserva_test.dart`, `sucesso_test.dart`, `supabase/testes/reservas.sql` |
| H3 · Cancelar agendamentos | 11 | 11 | 0 | `cancelamento_test.dart`, `jornadas_test.dart`, `supabase/testes/reservas.sql` |
| H4 · Tabela de preços e feriados | 11 | 11 | 0 | `feriados_test.dart`, `precos_test.dart`, `supabase/testes/reservas.sql` |
| H5 · Bloqueio para manutenção | 7 | 7 | 0 | `bloqueios_test.dart`, `consulta_horarios_test.dart`, `supabase/testes/reservas.sql` |
| H6 · Comprovante via WhatsApp | 6 | 6 | 0 | `comprovante_test.dart`, `sucesso_test.dart` |
| H7 · Login do proprietário | 12 | 11 | 1 | `admin_acesso_test.dart`, `consulta_horarios_test.dart`, `login_test.dart` |
| H8 · Cadastro e gestão de quadras | 7 | 7 | 0 | `quadras_test.dart`, `supabase/testes/reservas.sql` |
| H9 · Horário de funcionamento | 7 | 7 | 0 | `horarios_test.dart`, `supabase/testes/reservas.sql` |
| H10 · Limite de 2 horários por dia por cliente | 5 | 5 | 0 | `jornadas_test.dart`, `reserva_test.dart`, `supabase/testes/reservas.sql` |
| H11 · Consultar agendamentos realizados | 8 | 8 | 0 | `agendamentos_test.dart`, `jornadas_test.dart`, `supabase/testes/reservas.sql` |
| H12 · Relatório de locações por período | 8 | 8 | 0 | `faturamento_test.dart`, `supabase/testes/reservas.sql` |
| **Total (H1–H12)** | **108** | **107** | **1** | |
| Requisitos não funcionais | 13 | 11 | 2 | |

Um caso conta como "já com teste" quando pelo menos um teste existente o verifica. Vários ainda têm uma parte a fazer (por exemplo, a regra no banco), indicada na coluna Verificação da seção 4.

### 6.2 Requisito → casos

| Requisito | Casos |
|---|---|
| RF01 | CT-H1-01, CT-H1-06, CT-H1-07, CT-H1-08, CT-H1-10 |
| RF02 | CT-H1-02 |
| RF03 | CT-H1-03, CT-H1-04, CT-H1-05, CT-H1-09, CT-H1-11, CT-H5-01, CT-H5-02, CT-H8-06 |
| RF04 | CT-H2-01, CT-H2-06, CT-H2-08, CT-H2-10, CT-H2-11, CT-H2-15 |
| RF05 | CT-H2-02, CT-H2-03, CT-H2-04 |
| RF06 | CT-H2-05, CT-H2-07 |
| RF07 | CT-H10-01, CT-H10-02, CT-H10-03, CT-H10-04, CT-H10-05 |
| RF08 | CT-H2-01, CT-H2-13, CT-H2-14 |
| RF09 | CT-H6-01, CT-H6-02, CT-H6-03, CT-H6-04, CT-H6-05 |
| RF10 | CT-H7-01, CT-H7-02, CT-H7-03, CT-H7-06, CT-H7-07, CT-H7-10, CT-H7-11, CT-H7-12 |
| RF11 | CT-H7-04, CT-H7-05, CT-H7-08 |
| RF12 | CT-H8-01, CT-H8-02, CT-H8-03, CT-H8-04, CT-H8-05, CT-H8-06, CT-H8-07 |
| RF13 | CT-H9-01, CT-H9-02, CT-H9-03, CT-H9-04, CT-H9-05, CT-H9-06, CT-H9-07 |
| RF14 | CT-H11-01, CT-H11-02, CT-H11-03, CT-H11-04, CT-H11-05, CT-H11-07, CT-H11-08 |
| RF15 | CT-H3-01, CT-H3-02, CT-H3-03, CT-H3-04, CT-H3-05, CT-H3-06, CT-H3-07, CT-H3-08, CT-H3-10, CT-H3-11 |
| RF16 | CT-H3-09, CT-H11-08 |
| RF17 | CT-H5-01, CT-H5-03, CT-H5-04, CT-H5-05, CT-H5-06, CT-H5-07 |
| RF18 | CT-H4-01, CT-H4-05, CT-H4-11 |
| RF19 | CT-H4-02, CT-H4-03 |
| RF20 | CT-H2-09, CT-H4-04, CT-H4-10 |
| RF21 | CT-H4-06, CT-H4-07, CT-H4-08, CT-H4-09 |
| RF22 | CT-H12-01, CT-H12-02, CT-H12-05, CT-H12-06, CT-H12-07, CT-H12-08 |
| RF23 | CT-H12-03, CT-H12-04 |
| RNF04 | CT-H2-12, CT-H11-06, CT-RNF04-01, CT-RNF04-02 |
| RNF05 | CT-H7-04, CT-H7-05, CT-H7-09, CT-RNF05-01 |
| RNF08 | CT-RNF08-01 |
| RNF10 | CT-H6-03, CT-H6-06, CT-RNF10-01 |
| RNF11 | CT-RNF11-01 |
| RNF12 | CT-RNF12-01 |
| RNF13 | CT-RNF13-01 |
| RNF14 | CT-RNF14-01 |
| RNF15 | CT-RNF15-01 |
| RNF16 | CT-RNF16-01 |
| RNF17 | CT-RNF17-01 |
| RNF18 | CT-RNF18-01 |

Todos os RF de RF01 a RF23 e os 12 RNF do Documento de Visão têm pelo menos um caso.

## 7. Observações encontradas ao montar a especificação

1. **Rótulos trocados nos testes de reserva.** O `reserva_test.dart` chama o teste da reserva válida de "(H1)", mas no Documento de Visão a consulta é H1, a reserva é H2 e o limite diário é H10. Vale renomear para o rastreio bater com este documento.
2. **RNF fora do documento.** O código e a documentação citam RNF06 (log de cancelamento) e RNF07 (valor congelado na reserva), que não estão na tabela da seção 5 do Documento de Visão. Os dois comportamentos têm casos aqui (CT-H3-09 e CT-H4-10), mas o documento precisa ser atualizado.
3. **Premissa em aberto.** O Documento de Visão ainda traz "Há um único usuário administrador [Validar com o grupo]". O teste de aceitação (6.7) conta com um só proprietário.
4. **Responsividade ampliada na 6.5.** O RNF12 pede de 360 px a 1920 px, e os testes de cada tela usavam só 360 px. O `responsividade_test.dart` passou a conferir 6 telas em 4 larguras; as telas de preços, feriados e faturamento são conferidas à mão. A home em 360 px está ignorada no teste automático até ser conferida no navegador (a fonte de teste é mais larga que a real).
5. **Cobertura de testes ainda sem número.** O RNF17 pede cobertura mínima de 70%. O `flutter analyze` já é verificado no CI, mas a cobertura só passa a ser medida com `flutter test --coverage` (procedimento na seção 9 da 6.5).
6. **Contraste abaixo do mínimo em dois estados.** Os chips "Passou" (2,76:1) e "Sem preço" (3,34:1) ficam abaixo de 4,5:1 (RNF18). Detalhes e sugestão na seção 3 da 6.5.
7. **Home sem teste, resolvido na 6.2.** A consulta pública não tinha teste de horários porque o `assinarOcupacoes` do `QuadrasService` não podia ser trocado por um falso. A 6.2 tornou o retorno opcional (`RealtimeChannel?`) e criou `consulta_horarios_test.dart`.

## 8. Como conferir

1. Cada história tem pelo menos um caso *Principal* e um *Alternativo*: confira as tabelas da seção 4.
2. Todo requisito aparece na seção 6.2.
3. Os testes existentes citados na coluna Verificação estão em `test/` e rodam com `flutter test`.

