# Atividade 5.8 · Relatório de locações por período (H12 · RF22-RF23)

Autor: João · Branch: `feat/5.8-relatorio-faturamento`

## 1. O que foi feito

O proprietário abre **Faturamento** no painel (`/admin/faturamento`) e vê, para o período
escolhido, as locações confirmadas, o faturamento total, as canceladas e o faturamento de
cada dia. Pode filtrar por um telefone. O visual segue a tela "Faturamento" do protótipo
**Ace Saibro**.

| Arquivo | O que tem |
|---|---|
| `lib/admin/faturamento_page.dart` | Tela: filtros, os três indicadores, gráfico por dia e visão em tabela |
| `lib/admin/faturamento_repositorio.dart` | `FaturamentoRepositorio` (interface), `SupabaseFaturamentoRepositorio` (real) e `traduzirErroFaturamento` |
| `test/faturamento_test.dart` | 16 testes com um repositório falso que soma como o banco |
| `lib/formatos.dart` | `formatarReal` agora com separador de milhar (`R$ 1.470,00`) |
| `lib/app.dart` | Rota `/admin/faturamento` dentro do `ShellRoute` (exige login) e parâmetro `faturamento` |
| `lib/admin/painel_page.dart` | Card "Faturamento" ativado |

### Conversa com o banco

| Dado | Chamada |
|---|---|
| Totais (locações, faturamento, canceladas) | `rpc('resumo_faturamento', {p_inicio, p_fim, p_telefone})`; canceladas não entram no faturamento |
| Faturamento por dia | `from('reservas').select('data, valor').eq('status', 'confirmada')` no período, somado no app; lê de 1000 em 1000 linhas (limite do PostgREST) |

| Erro | Onde aparece |
|---|---|
| `PERIODO_INVALIDO` ou data inicial depois da final | Alerta, sem consultar o banco |
| `NAO_AUTORIZADO`, `42501` (sem login) | Volta para o login ("Sua sessão expirou") |
| Sem conexão | Alerta vermelho com "Tentar de novo" |

## 2. Decisões

- **Período inicial:** do dia 1º do mês até hoje, como no protótipo.
- **Telefone:** só filtra com o número completo (DDD + 9 + 8 dígitos), porque o banco compara
  o telefone inteiro. Número incompleto mostra aviso e não consulta.
- **Gráfico:** uma coluna por dia, no máximo os últimos 62 dias do período (os totais continuam
  valendo para o período todo). O valor de cada dia aparece ao passar o mouse e na opção
  "Ver como tabela"; o maior dia leva o valor escrito acima da coluna.
- **Cor das colunas:** `AceCores.verdeMedio`, que passa na checagem de contraste e de
  luminosidade para gráficos (o verde-escuro da marca ficou escuro demais para marcas de dado).

## 3. Como conferir

1. `flutter test`: os 16 testes de `test/faturamento_test.dart` passam.
2. Entrar como proprietário e abrir **Faturamento** no painel.
3. Conferir os totais do mês com a tela **Reservas** (5.4), usando o mesmo período.
4. Filtrar por um telefone completo e conferir que os números mudam.
