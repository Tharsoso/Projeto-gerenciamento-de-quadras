# Atividade 5.7 · Tabela de preços e feriados (H4 · RF18–RF21)

Autor: Davi · Branch: `feat/5.7-precos-feriados` (criada a partir do `main`, depois do PR #9).

## 1. O que foi feito

Agora o proprietário tem duas telas novas no painel:

- **Preços:** para cada quadra, uma tabela de **dia útil** (seg–sex) e uma de **fim de
  semana e feriado**. Cada tabela tem faixas de horário com o valor da hora (ex.: R$ 60 das
  07h às 18h e R$ 90 das 18h às 22h). A tela não deixa salvar faixas que se sobrepõem nem
  horário de funcionamento sem preço (RF19).
- **Feriados:** calendário por ano. Num feriado vale a tabela de fim de semana, mesmo que
  ele caia num dia útil (RF21).

O valor de cada reserva já fica gravado nela pelo `criar_reserva` (RF20, RNF07). Por isso
mudar a tabela de preços ou um feriado **não muda** as reservas já feitas. O visual segue
as telas "Preços por faixa" e "Feriados" do protótipo Ace Saibro.

| Arquivo | O que tem |
|---|---|
| `lib/models/preco.dart` | `TipoDia`, `FaixaPreco`, `validarFaixas` (sobreposição, lacuna e valor), `horasACobrir`, `lerValor`, `reservasComValorAnterior` |
| `lib/admin/precos_repositorio.dart` | `PrecosRepositorio` (interface), `SupabasePrecosRepositorio` e `traduzirErroPreco` |
| `lib/admin/precos_page.dart` | Tela: seletor de quadra, abas, linhas de faixa, linha do tempo das horas e lista de problemas |
| `lib/admin/feriados_repositorio.dart` | `Feriado`, `FeriadosRepositorio`, `SupabaseFeriadosRepositorio` e `traduzirErroFeriado` |
| `lib/admin/feriados_page.dart` | Tela: abas por ano, lista, "Novo feriado" (data e descrição) e remover |
| `lib/app.dart` | Rotas `/admin/precos` e `/admin/feriados` (exigem login) e parâmetros `precos` e `feriados` no `App` |
| `lib/admin/painel_page.dart` | Os módulos "PREÇOS" e "FERIADOS" deixaram de ser "Em breve" |
| `test/precos_test.dart` | 20 testes (7 de regra, 10 de tela, 3 de erro) |
| `test/feriados_test.dart` | 8 testes |

Não houve mudança no banco: a tabela, a função e o RLS já estavam na migration inicial.

## 2. Conversa com o banco

| Ação | Chamada |
|---|---|
| Quadras | `from('quadras').select(...)`, incluindo as inativas |
| Funcionamento | `from('horarios_funcionamento').select(...)`, para saber quais horas precisam de preço |
| Tabelas | `from('faixas_preco').select('quadra_id, tipo_dia, hora_inicio, hora_fim, valor')` |
| Salvar uma aba | `rpc('salvar_faixas_preco', {p_quadra_id, p_tipo_dia, p_faixas})`, que troca todas as faixas daquele tipo de dia |
| Aviso de reservas | `from('reservas').select('data, hora_inicio, valor').eq('status','confirmada')` da quadra, mais `from('feriados').select('data')` |
| Feriados | `from('feriados')`: `select` / `insert {data, descricao}` / `delete().eq('data', …)` |

`faixas_preco` só aceita escrita pela `salvar_faixas_preco`. Essa função valida tudo de novo
no servidor. A validação da tela usa as **mesmas regras**, só para avisar antes de enviar.

## 3. Regras e erros

| Situação | Quem barra | O que aparece |
|---|---|---|
| Faixas sobrepostas (H4 alt. 1: 08h–18h e 17h–22h) | Tela e banco (`FAIXA_SOBREPOSTA`) | "As faixas 08h–18h e 17h–22h se sobrepõem.", hora em vermelho e Salvar desligado |
| Hora de funcionamento sem preço | Tela e banco (`FAIXA_LACUNA`) | "Sem preço entre 18h e 22h…", hora listrada em laranja e Salvar desligado |
| Fim antes do início | Tela e banco (`INTERVALO_INVALIDO`) | "Faixa 2: o fim (12h) precisa ser depois do início (12h)." |
| Valor vazio, zero ou com mais de 2 casas | Tela e banco (check `valor > 0`) | "Faixa 1: informe um valor maior que R$ 0,00." |
| Feriado repetido | Tela e banco (chave primária, 23505) | "Já existe um feriado nesta data." |
| Descrição com menos de 3 letras | Tela (o banco só exige que não esteja vazia) | "Informe a descrição (mínimo de 3 letras)." |
| Sem login | RLS (42501) ou `NAO_AUTORIZADO` | "Sua sessão expirou. Entre novamente." e vai para o login |

**Quais horas precisam de preço:**
- **Dia útil:** a união do funcionamento de segunda a sexta.
- **Fim de semana:** a união do funcionamento de **todos os dias**, porque um feriado
  pode cair num dia útil. Com o seed (seg–sex 07h–22h, sáb–dom 08h–18h), a tabela de fim de
  semana precisa cobrir 07h–22h. A aba explica isso na tela.

**H4 alt. 2 (reservas futuras):** depois de salvar, a tela conta as reservas confirmadas
futuras da quadra **do tipo de dia alterado** cujo valor gravado é diferente do novo preço.
Feriados contam como fim de semana. Exemplo de aviso: "Preços de dia útil da Saibro 1
salvos. 12 reservas futuras mantêm o valor anterior." As reservas não são alteradas.

Cada aba é salva separadamente. Uma alteração que ainda não foi salva aparece com um ponto
amarelo na quadra e um "•" na aba. Ela fica guardada ao trocar de quadra ou de aba.

## 4. Como conferir

1. Logado, abrir o painel → PREÇOS → Saibro 1 → Dia útil.
2. Mudar o início da faixa 2 para 17:00. Aparece a sobreposição 17h–18h e o Salvar fica
   desligado. Voltar para 18:00.
3. Mudar o valor das 18h–22h para 110 → Salvar. O aviso informa quantas reservas futuras
   de dia útil mantêm R$ 90.
4. Na consulta pública de um dia útil, os horários a partir das 18h mostram R$ 110.
5. FERIADOS → "Novo feriado" → escolher uma segunda-feira e dar a descrição "Aniversário da
   cidade". Na consulta pública desse dia, os horários usam o preço de fim de semana.
6. Remover o feriado. O dia volta ao preço de dia útil, e as reservas já feitas continuam
   com o valor que foi cobrado.
