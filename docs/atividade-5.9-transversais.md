# Atividade 5.9 · Requisitos transversais: LGPD, backup e localização (RNF04 · RNF14 · RNF15)

Autor: Davi · Branch: `feat/5.9-transversais`, criada a partir do `main` depois do PR #12 (5.8).

Esta atividade não cria uma tela nova. Ela fecha três requisitos que valem para o sistema
inteiro. Antes de começar, uma parte deles já estava pronta: o `agora_local()` do banco, a
anonimização agendada com pg_cron, o `formatarReal` e o app em pt-BR. Este documento lista
**todas** as regras, inclusive as que já existiam, para cada uma ter dono e teste.

## 1. Regras

### RNF15 · Fuso, idioma e moeda

| # | Regra | Onde | Teste |
|---|---|---|---|
| F1 | "Agora" e "hoje" no app são sempre o horário de **Brasília**, e não o fuso do aparelho. O app pega o relógio do aparelho em UTC e subtrai 3 horas | `lib/fuso.dart` (`agoraBrasilia`, `hojeBrasilia`) | `test/fuso_test.dart` |
| F2 | O deslocamento é fixo, **UTC−3**, porque o Brasil não tem horário de verão desde 2019 (Decreto 9.772/2019). Se o horário de verão voltar, a mudança fica só em `lib/fuso.dart` | `lib/fuso.dart` | `test/fuso_test.dart` |
| F3 | Nenhuma tela ou repositório chama `DateTime.now()` direto: todos usam `agoraBrasilia()`/`hojeBrasilia()` | todo o `lib/` | `test/fuso_test.dart` varre o `lib/` |
| F4 | Quem decide de verdade se um horário já passou é o banco, com `agora_local()` (`America/Sao_Paulo`). O app só usa o horário para esconder botões e escolher o dia inicial | migration inicial | já coberto pelos erros `HORARIO_PASSADO`/`RESERVA_PASSADA` |
| F5 | Interface em pt-BR: o `MaterialApp` só aceita `pt_BR` e carrega as traduções do Material (calendário, botões) | `lib/app.dart` | `test/fuso_test.dart` (o calendário mostra os meses em português) |
| F6 | Valores exibidos no formato `R$ 1.234,56` sempre pelo `formatarReal`. Ficam de fora só os campos de digitação de preço (`60,00`, sem `R$`) e o eixo do gráfico do faturamento (`R$ 1,5 mil`) | `lib/formatos.dart` | `test/fuso_test.dart` |
| F7 | Datas exibidas como `dd/mm/aaaa` pelo `formatarData` | `lib/formatos.dart` | `test/fuso_test.dart` |

### RNF04 · LGPD

| # | Regra | Onde | Teste |
|---|---|---|---|
| L1 | A tela de reserva explica **para que** o nome e o telefone são usados e **por quanto tempo** ficam guardados: "Usamos seu nome e telefone só para identificar a reserva e falar com você sobre ela. Eles são apagados (anonimizados) 12 meses depois da data da reserva." | `lib/screens/public/reserva_screen.dart` | `test/reserva_test.dart` |
| L2 | A consulta pública nunca lê nome nem telefone: o `anon` só lê `ocupacoes` e as tabelas de configuração | RLS da migration inicial | já coberto |
| L3 | Todo dia, as reservas com **data anterior a hoje − 12 meses** (em Brasília) são anonimizadas: o nome vira "Cliente anonimizado", o telefone fica `null` e `anonimizada = true`. Valor, data e status continuam, porque o relatório de faturamento precisa deles | `anonimizar_reservas_antigas()` | `supabase/testes/lgpd.sql` |
| L4 | **(nova)** A anonimização também apaga o **motivo do cancelamento** dessas reservas, porque é texto livre e pode citar o cliente ("João avisou que viajou") | migration `20261105120000_lgpd_motivo_cancelamento.sql` | `supabase/testes/lgpd.sql` |
| L5 | A função roda pelo pg_cron todo dia às `0 3 * * *`. O pg_cron do Supabase usa UTC, então ela roda à **meia-noite de Brasília** | migration inicial | conferência manual (seção 4) |
| L6 | Uma reserva anonimizada aparece no painel como "Anonimizado (LGPD)", com o telefone mascarado | `agendamentos_page.dart` (5.4) | `test/agendamentos_test.dart` |
| L7 | Depois de **restaurar** um backup, é obrigatório rodar `select public.anonimizar_reservas_antigas();`, porque um backup antigo pode trazer de volta dados que já tinham sido anonimizados | procedimento da seção 3 | `restauracao.yml` roda a função e confere |

### RNF14 · Backup

| # | Regra | Onde |
|---|---|---|
| B1 | Backup **diário** às 03:30 de Brasília (06:30 UTC), pelo GitHub Actions. Também dá para rodar na mão (`workflow_dispatch`) | `.github/workflows/backup.yml` |
| B2 | O backup inclui o esquema `public` inteiro (estrutura e dados) e os dados de `auth.users`/`auth.identities` (o login do proprietário, que `log_cancelamentos.cancelado_por` referencia) | `supabase/backup/backup.sh` |
| B3 | O repositório é **público**, então o arquivo é **cifrado com age** para uma chave pública antes de sair do runner. O job de backup só tem a chave pública e não consegue abrir nenhum backup. A chave privada fica só no secret usado pelo teste de restauração e no gerenciador de senhas de quem cuida do sistema | `backup.yml` |
| B4 | Junto do dump vão um `manifesto.txt` com a contagem de linhas de cada tabela e um `permissoes.txt` com as permissões dos papéis da API, tirados na mesma foto (snapshot) do dump e sem nenhum dado pessoal. O manifesto também é mostrado no resumo do job | `backup.sh` |
| B5 | O backup fica guardado como artefato do Actions por **30 dias** (`retention-days: 30`). Depois disso, o GitHub apaga | `backup.yml` |
| B6 | Sem a chave pública configurada, o backup **falha**. Um backup em texto aberto num repositório público seria vazamento de dados (LGPD) | `backup.sh` |
| B7 | Teste de restauração **mensal** (dia 1, 04:00 de Brasília) e manual. Ele baixa o backup mais recente, decifra, restaura num Postgres do Supabase (mesma versão 17) dentro do runner, roda a anonimização (L7) e confere: (a) as contagens batem com o manifesto; (b) as permissões de `anon`/`authenticated`/`service_role` são as mesmas do backup; (c) `horarios_do_dia` responde; (d) nenhuma reserva com mais de 12 meses continua com telefone; (e) o `supabase/testes/lgpd.sql` passa no banco restaurado. Se qualquer item falhar, o job falha e o GitHub avisa por e-mail | `.github/workflows/restauracao.yml` + `supabase/backup/restaurar.sh` |
| B8 | A conexão usa a URL do **Session pooler** do Supabase. A conexão direta só tem IPv6, e os runners do GitHub não têm IPv6 | secret `SUPABASE_DB_URL` |
| B9 | Falha em backup agendado gera e-mail do GitHub para quem mexeu por último no `cron` do workflow. Workflows agendados de repositório público são desligados depois de 60 dias sem commits; isso não chega a acontecer até a entrega (06/12) | observação |

Por que não usar só o backup do próprio Supabase: a retenção dele depende do plano e fica
abaixo de 30 dias, e não temos como agendar e conferir um teste de restauração por conta
própria. O backup do Actions é gratuito, fica no repositório e o teste roda sozinho.

## 2. O que mudou

| Arquivo | O que tem |
|---|---|
| `lib/fuso.dart` | `agoraBrasilia()`, `hojeBrasilia()` e o `relogioUtc` que os testes trocam (F1, F2) |
| 9 telas e repositórios em `lib/admin` e `lib/screens/public` | `DateTime.now()` virou `agoraBrasilia()` (F3) |
| `lib/screens/public/reserva_screen.dart` | Aviso de finalidade e prazo dos dados (L1), em `avisoLgpdReserva` |
| `supabase/migrations/20261105120000_lgpd_motivo_cancelamento.sql` | Anonimização também apaga o motivo do cancelamento (L4) e limpa os já anonimizados |
| `supabase/testes/lgpd.sql` | Teste SQL de L3 e L4, numa transação desfeita no fim |
| `supabase/backup/backup.sh` | Dump do `public` e do `auth`, manifesto e permissões na mesma foto, cifra com age (B2–B6) |
| `supabase/backup/restaurar.sh` | Decifra, restaura (modos `teste` e `projeto-novo`), anonimiza (L7) e confere (B7) |
| `supabase/backup/permissoes.sql` | Lista as permissões de `anon`/`authenticated`/`service_role` por objeto |
| `.github/workflows/backup.yml` | Backup diário, artefato de 30 dias (B1, B5) |
| `.github/workflows/restauracao.yml` | Teste mensal de restauração (B7) |
| `.github/workflows/banco.yml` | Em PR que mexe em `supabase/`, aplica as migrations e o seed num Postgres do Supabase e roda `supabase/testes/*.sql` |
| `test/fuso_test.dart` | 8 testes (F1–F3, F5–F7) |
| `test/reserva_test.dart` | +1 teste (L1) |

**Atenção ao juntar com a 5.5:** o `lib/admin/cancelamento.dart` usa `DateTime.now` como
relógio padrão. Quando as duas branches estiverem na `main`, o teste F3 vai reprovar até
trocar para `agoraBrasilia`. A troca é de uma linha:
`final relogio = agora ?? agoraBrasilia;`.

### O que o teste local mostrou

O backup e a restauração foram testados com a imagem `supabase/postgres:17.11.0.007`, a
mesma que os workflows usam. Primeiro rodaram as migrations e o seed num banco; depois o
backup foi restaurado em outro banco vazio, nos dois modos. Três problemas apareceram e
foram corrigidos:

1. **Permissões (o mais grave).** O `pg_restore` comum deixava o `anon` com INSERT,
   UPDATE e DELETE em `reservas` e com EXECUTE em `cancelar_reserva`. O Supabase dá tudo a
   `anon`/`authenticated` em cada objeto novo (*default privileges*), e o `pg_dump` grava
   as permissões supondo o padrão do Postgres, então nunca tira o que sobra. Por isso a
   restauração agora roda em duas passadas: primeiro os objetos; depois as permissões dos
   papéis da API são zeradas; por último entram as permissões do backup. O
   `permissoes.txt` confere o resultado. Também foi feita uma checagem de mutação: sem a
   etapa que zera as permissões, o teste de restauração reprova.
2. O dump traz `CREATE SCHEMA public` e os `DEFAULT ACL` da plataforma. Os dois já existem
   no destino, e só o `supabase_admin` pode alterá-los, então ficam de fora.
3. No Supabase, o `postgres` não é superusuário: o modo `teste` conecta como
   `supabase_admin` (dono do `auth` na imagem), e o `projeto-novo` não usa
   `--disable-triggers`.

## 3. Como restaurar um backup (procedimento)

Use quando o banco de produção for perdido ou corrompido. Leva uns 10 minutos.

1. No GitHub: **Actions → Backup do banco**, abrir a execução do dia que você quer
   restaurar e baixar o artefato `backup-banco` (é um `.zip` com o `.tar.gz.age` dentro).
2. Criar um **projeto novo** no Supabase, na mesma região e com Postgres 17, **sem rodar
   as migrations**: o backup já traz a estrutura.
3. Pegar a URL do **Session pooler** do projeto novo (botão *Connect*) e rodar, numa
   máquina com `psql`/`pg_restore` 17 ou mais novo e com o `age`:

   ```bash
   unzip backup-banco.zip
   DESTINO_URL='postgresql://postgres.<ref>:<senha>@aws-0-<regiao>.pooler.supabase.com:5432/postgres' \
     supabase/backup/restaurar.sh projeto-novo gqt-AAAA-MM-DD-HHMM.tar.gz.age
   ```

   O script pede a chave privada: cole a linha `AGE-SECRET-KEY-1...` do gerenciador de
   senhas e tecle **Ctrl+D**. Ela não fica gravada em disco.
4. O script restaura, roda a anonimização (L7), reagenda o pg_cron e mostra uma conferência.
   Ela só pode terminar com "Restauração conferida: tudo ok".
5. Trocar `SUPABASE_URL` e a chave publicável do app para os do projeto novo e publicar.
   Trocar também o secret `SUPABASE_DB_URL` do repositório.
6. Em **Authentication → URL Configuration**, cadastrar de novo as URLs do app, porque as
   configurações do Auth não estão no banco.

O que **não** volta com o backup: as configurações do Auth (URLs, cadastro público
desligado), as chaves da API (o projeto novo tem outras) e o agendamento no pg_cron, que o
passo 4 recria.

## 4. Configuração (passo a passo)

Só o **Tharsos**, que é admin do repositório, consegue criar secrets. O par de chaves pode
ser gerado por quem for guardar a chave privada.

1. **Gerar o par de chaves do age** (uma vez, numa máquina confiável):

   ```bash
   age-keygen -o chave-backup.txt
   ```

   A linha `# public key: age1...` é a **chave pública**. A linha `AGE-SECRET-KEY-1...` é a
   **privada**: guarde no gerenciador de senhas e depois apague o arquivo
   (`shred -u chave-backup.txt`). Sem ela, nenhum backup abre.
2. **URL do banco:** no Supabase, **Connect → Session pooler**, copiar a URI e trocar
   `[YOUR-PASSWORD]` pela senha do banco. Não use a *Direct connection*: ela só tem IPv6,
   e os runners do GitHub não têm IPv6 (B8).
3. **No GitHub:** *Settings → Secrets and variables → Actions*:
   - aba **Secrets** → `SUPABASE_DB_URL` = URI do passo 2;
   - aba **Secrets** → `BACKUP_AGE_CHAVE` = a linha `AGE-SECRET-KEY-1...`;
   - aba **Variables** → `BACKUP_AGE_PUBLICA` = a chave `age1...` (não é segredo).
4. **Aplicar a migration nova** (L4), como manda o README: `npx supabase db push`, com
   aviso no grupo.
5. **Primeira execução:** *Actions → Backup do banco → Run workflow*. Quando terminar,
   *Actions → Teste de restauração do backup → Run workflow*. Os dois precisam ficar
   verdes. O resumo do backup mostra as contagens de cada tabela.
6. **Conferir o pg_cron** (L5), no *SQL Editor* do Supabase:

   ```sql
   select jobname, schedule, active from cron.job;
   ```

   Tem que aparecer `anonimizar-reservas | 0 3 * * * | t`. Se não aparecer, rodar o bloco
   `do $$ ... cron.schedule ... $$` do fim da migration inicial.

## 5. Como conferir

1. **Fuso:** mudar o fuso do computador para Lisboa (UTC+0) e abrir o app depois das
   21:00 de Brasília. A consulta pública continua abrindo no dia de hoje de Brasília, e
   não no dia seguinte. A saudação do painel segue o horário de Brasília.
2. **LGPD:** abrir uma reserva pela consulta pública. Abaixo do telefone aparece o aviso
   de finalidade e prazo.
3. **Backup e restauração:** passos 5 e 6 da seção 4.
4. **Testes:** `flutter test` (125 testes, 9 novos). Para os testes SQL, com Docker:

   ```bash
   docker run -d --name gqt-pg -e POSTGRES_PASSWORD=postgres -p 55432:5432 supabase/postgres:17.11.0.007
   for f in supabase/migrations/*.sql supabase/seed.sql supabase/testes/*.sql; do
     psql postgresql://postgres:postgres@localhost:55432/postgres -v ON_ERROR_STOP=1 -q -f "$f"
   done
   ```
