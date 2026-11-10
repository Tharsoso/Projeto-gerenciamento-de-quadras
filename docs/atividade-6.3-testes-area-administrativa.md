# Atividade 6.3 · Testes automatizados da área administrativa (H3, H4, H5, H7, H8, H9, H11, H12 · RF10–RF23 · RNF05)

Autor: Arthur · Branch: `feat/6.3-testes-area-admin`, criada a partir da `main`.

## 1. O que foi feito

A área administrativa já tinha testes escritos junto com cada módulo (quadras, horários, preços, feriados, bloqueios, cancelamento, agendamentos e faturamento). Esta atividade fez duas coisas: **mapeou** o que cada arquivo cobre em relação aos casos da 6.1 e **completou as lacunas de acesso**, que nenhum módulo testava sozinho.

| Arquivo | O que tem |
|---|---|
| `test/admin_acesso_test.dart` | 24 testes: as 8 rotas `/admin/*` sem login, os 7 módulos do painel, o cartão de cada módulo abrindo sua tela e a expiração por inatividade em cada uma das 8 rotas |
| `docs/atividade-6.1-casos-de-teste.md` | Atualizado com os testes novos (casos CT-H7-11 e CT-H7-12) |

Nenhum código do app foi alterado.

## 2. Lacunas que existiam

- O `login_test.dart` testava a proteção só da rota `/admin`. As outras sete rotas (`/admin/quadras`, `/admin/horarios`, `/admin/bloqueios`, `/admin/precos`, `/admin/feriados`, `/admin/reservas`, `/admin/faturamento`) não tinham teste de "sem login vai para o login".
- A expiração por inatividade (30 minutos, RNF05) também era testada só no painel. Como o controle de inatividade envolve todas as telas administrativas, cada uma precisa ser conferida.
- Só os cartões Reservas e Faturamento do painel eram testados. Os outros cinco não eram.

## 3. Como o novo teste funciona

- **Repositórios falsos:** cada tela administrativa recebe um repositório que devolve uma lista vazia. Isso basta para a tela abrir, e o teste confere apenas o acesso, não o conteúdo do módulo.
- **`AuthFalsa`:** autenticação em memória que começa logada ou não, e `sair()` encerra a sessão, como a real.
- **Um teste por rota:** as rotas ficam numa lista (`rotasAdmin`) e os módulos num mapa (`modulos`, chave do cartão → tela). Um `for` cria um teste para cada item, e o nome do teste diz qual.
- **Inatividade:** o teste avança 30 minutos com `tester.pump(limite)` e confere que a sessão acabou e a mensagem de inatividade aparece.

## 4. Casos cobertos pelo arquivo novo

| Caso (6.1) | Teste | Quantidade |
|---|---|---|
| CT-H7-06 | `$rota sem login vai para o login`, para cada rota `/admin/*` | 8 |
| CT-H7-11 | o painel mostra os sete módulos do proprietário | 1 |
| CT-H7-12 | o cartão `<chave>` abre a tela do módulo, para cada um dos 7 cartões | 7 |
| CT-H7-04, CT-RNF05-01 | 30 min sem interação em `<rota>` encerra a sessão, para cada rota | 8 |

## 5. Cobertura dos casos administrativos

Resumo tirado do documento da 6.1, por história:

| História | Casos | Já com teste em `test/` | A fazer | Arquivos de teste |
|---|---|---|---|---|
| H3 · Cancelar agendamentos | 10 | 9 | 1 | `cancelamento_test.dart` |
| H4 · Tabela de preços e feriados | 11 | 10 | 1 | `feriados_test.dart`, `precos_test.dart` |
| H5 · Bloqueio para manutenção | 7 | 5 | 2 | `bloqueios_test.dart`, `consulta_horarios_test.dart` |
| H7 · Login do proprietário | 12 | 11 | 1 | `admin_acesso_test.dart`, `consulta_horarios_test.dart`, `login_test.dart` |
| H8 · Cadastro e gestão de quadras | 7 | 6 | 1 | `quadras_test.dart` |
| H9 · Horário de funcionamento | 7 | 6 | 1 | `horarios_test.dart` |
| H11 · Consultar agendamentos realizados | 8 | 7 | 1 | `agendamentos_test.dart` |
| H12 · Relatório de locações por período | 8 | 7 | 1 | `faturamento_test.dart` |

Os casos "a fazer" dessas histórias são de regra do banco (verificadas na 6.4, em SQL), de teste do sistema completo (6.4) e de requisito não funcional (6.5, como a senha guardada com hash). Todos os comportamentos de tela da área administrativa têm teste.

## 6. O que ficou de fora

- **Regras do banco** (limite diário, cancelamento só do proprietário, bloqueio sobre reserva, preços sobrepostos): ficam para os testes SQL da 6.4.
- **Sessão expirada por erro do banco** (`NAO_AUTORIZADO`) em cada módulo: já é testada nos arquivos de cada módulo.
- **Largura de tela de 360 px a 1920 px** nas telas administrativas: é medida na 6.5 (RNF12).

## 7. Como conferir

```bash
flutter test test/admin_acesso_test.dart
flutter test
flutter analyze
```

