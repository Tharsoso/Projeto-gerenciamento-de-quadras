# Atividade 6.4 · Testes de integração e de sistema (H1–H12 · RF01–RF23 · RNF04, RNF08)

Autor: Arthur · Branch: `feat/6.4-testes-integracao-sistema`, criada a partir da `main`.

## 1. O que foi feito

Os testes das tasks 6.2 e 6.3 olham uma tela de cada vez. Esta atividade verifica as partes **funcionando juntas**, em três níveis:

| Parte | Arquivo | O que verifica |
|---|---|---|
| A. Jornadas entre telas | `test/jornadas_test.dart` | O app inteiro montado, com um banco em memória: o que o cliente reserva é o que o proprietário vê e cancela |
| B. Regras do banco | `supabase/testes/reservas.sql` | As regras que ficam no PostgreSQL (limite diário, horário ocupado, cancelamento, bloqueio, preços, relatório) |
| C. Teste do sistema | Seção 4 deste documento | O sistema real, com o Supabase, usado como um usuário usaria (manual, com registro de resultado) |

Nenhum código do app foi alterado.

## 2. Parte A · Jornadas entre telas

Quatro testes percorrem o fluxo inteiro, passando por área pública, login e área administrativa:

| Teste | Casos (6.1) |
|---|---|
| Cliente reserva, o proprietário vê a reserva e a cancela | CT-H2-01, CT-H3-01, CT-H11-01 |
| Dois clientes disputam o mesmo horário e o segundo é avisado | CT-H2-05 |
| O mesmo telefone reserva 2 horários no dia e a 3ª é recusada | CT-H10-01, CT-H10-02 |
| O proprietário cancela uma reserva e o telefone volta a poder reservar | CT-H3-01, CT-H10-04 |

**Como funciona:** o `BancoFalso` guarda as reservas em uma lista e serve as três pontas do app (reservar, consultar e cancelar). Ele repete as regras de horário ocupado e de limite de 2 por dia. As regras de verdade são testadas na parte B.

## 3. Parte B · Regras do banco em SQL

`supabase/testes/reservas.sql` segue o mesmo modelo do `lgpd.sql`: roda numa **transação e desfaz tudo no fim**, e falha com `TESTE FALHOU [caso]: ...` se alguma regra não valer.

- Cria a própria quadra de teste (`ZZ QA Quadra`), com horário e preços. Não depende do `seed.sql`.
- Usa datas a cerca de 400 dias no futuro, para não esbarrar em reservas reais.
- Cada verificação aprovada imprime `OK  CT-...`, com o ID do caso da 6.1. No fim, mostra `TODOS OS CASOS PASSARAM`.
- Cobre 55 verificações, que correspondem a 50 casos da 6.1.

| Assunto | Casos (6.1) |
|---|---|
| Consulta de horários | CT-H1-01, CT-H1-03, CT-H1-04, CT-H1-05, CT-H1-09, CT-H9-01 |
| Reserva e validações | CT-H2-01, CT-H2-02, CT-H2-03, CT-H2-05, CT-H2-09, CT-H2-10, CT-H2-11, CT-H2-15 |
| Limite diário | CT-H10-01 a CT-H10-05 |
| Cancelamento | CT-H3-01, CT-H3-03, CT-H3-07, CT-H3-09, CT-H3-10, CT-H3-11 |
| Bloqueios | CT-H5-01 a CT-H5-05 |
| Quadras e horários de funcionamento | CT-H8-03 a CT-H8-06, CT-H9-04 a CT-H9-07 |
| Preços e feriados | CT-H4-02, CT-H4-03, CT-H4-09, CT-H4-10, CT-H4-11 |
| Relatório e consulta do proprietário | CT-H11-08, CT-H12-01, CT-H12-02, CT-H12-03, CT-H12-05, CT-H12-08 |
| Privacidade | CT-RNF04-01 |

**Como rodar** (use sempre um banco de **testes**):

```bash
psql "URL-DO-BANCO-DE-TESTES" -v ON_ERROR_STOP=1 -f supabase/testes/reservas.sql
```

Também dá para colar o arquivo inteiro no SQL Editor do painel do Supabase do projeto de testes, ou rodar contra o banco local do Supabase CLI.

### Registro das execuções

| Data | Banco | Quem rodou | Resultado |
|---|---|---|---|
| | | | |

## 4. Parte C · Teste do sistema (manual)

**Ambiente:** o projeto de testes do Supabase (URL e anon key com o Davi) e o app rodando como no README:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=<url do projeto de testes> \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

Nunca use o banco de produção com dados reais de clientes.

### Roteiro

| ID | Casos (6.1) | Passos | Resultado esperado |
|---|---|---|---|
| ST-01 | CT-H8-01, CT-H9-01, CT-H4-01, CT-H1-01 | Entrar como proprietário. Em Quadras, criar "Teste Sistema 1". Em Horários, definir 07h–22h. Em Preços, definir R$ 60 para dia útil e R$ 100 para fim de semana. Abrir a home | A quadra aparece na home com os blocos de 1 hora e os preços certos |
| ST-02 | CT-H1-02 | Na home, tentar voltar antes de hoje com a seta ‹ e abrir o calendário em "Trocar data" | A seta não volta antes de hoje e o calendário não deixa escolher dia passado |
| ST-03 | CT-H1-06, CT-H2-01, CT-H6-01, CT-H6-06 | Tocar em um horário livre. Informar nome e telefone válidos e confirmar. Tocar no botão do WhatsApp | A confirmação mostra quadra, data, hora, valor e código; o WhatsApp abre com o texto pronto; a reserva vale mesmo sem usar o link |
| ST-04 | CT-H1-11, CT-RNF08-01 | Abrir a home em duas janelas. Reservar um horário em uma. Contar quantos segundos até o horário aparecer como reservado na outra, sem recarregar | O horário muda sozinho em até 5 segundos |
| ST-05 | CT-H10-01, CT-H10-02 | Com o mesmo telefone, reservar 3 horários no mesmo dia | A 1ª e a 2ª funcionam; a 3ª mostra o aviso de limite e continua no formulário |
| ST-06 | CT-H5-01, CT-H5-03 | Em Bloqueios, bloquear um horário livre. Conferir na home. Remover o bloqueio e conferir de novo | O horário bloqueado some da lista de livres; depois de desbloquear, volta a ficar livre |
| ST-07 | CT-H3-01, CT-H3-09, CT-H11-08, CT-H1-04 | Em Reservas, cancelar uma reserva futura com motivo. Conferir a lista e a home | A reserva continua na lista como cancelada, com o motivo; o horário volta a ficar livre na home |
| ST-08 | CT-H12-01, CT-H12-02, CT-H12-03 | Em Faturamento, gerar o relatório do período das reservas de teste, com e sem filtro de telefone | Mostra as locações e o faturamento; a reserva cancelada não entra na soma; o filtro restringe ao cliente |
| ST-09 | CT-H7-01, CT-H7-02, CT-H7-08 | Tentar entrar com senha errada. Entrar com os dados certos. Clicar em Sair | A senha errada mostra mensagem genérica; os dados certos abrem o painel; Sair encerra a sessão |
| ST-10 | CT-H8-04, CT-H8-05 | Cancelar as reservas de teste e inativar a quadra "Teste Sistema 1" | Com reserva futura, a quadra não inativa; depois de cancelar, ela inativa e some da home |

### Registro das execuções

| ID | Data | Quem executou | Resultado (passou / falhou) | Evidência (print) | Observação |
|---|---|---|---|---|---|
| ST-01 | | | | | |
| ST-02 | | | | | |
| ST-03 | | | | | |
| ST-04 | | | | Tempo medido: ___ s | |
| ST-05 | | | | | |
| ST-06 | | | | | |
| ST-07 | | | | | |
| ST-08 | | | | | |
| ST-09 | | | | | |
| ST-10 | | | | | |

### Defeitos encontrados

| N.º | Em qual ST | O que aconteceu | Resultado esperado | Quem avisou |
|---|---|---|---|---|
| | | | | |

## 5. Como conferir

```bash
flutter test test/jornadas_test.dart
flutter test
flutter analyze
```

E, no banco de testes, o `reservas.sql` da seção 3.
