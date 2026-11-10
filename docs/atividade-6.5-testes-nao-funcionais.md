# Atividade 6.5 · Testes não funcionais (RNF04, RNF05, RNF08, RNF10 a RNF18)

Autor: Arthur · Branch: `feat/6.5-testes-nao-funcionais`, criada a partir da `main`.

## 1. O que foi feito

Cada requisito não funcional do Documento de Visão ganhou uma forma de verificação: um teste automatizado quando dá para automatizar, e um procedimento com tabela de resultado quando a medição depende do sistema publicado ou de uma ferramenta externa.

| Arquivo | O que verifica |
|---|---|
| `test/responsividade_test.dart` | RNF12: 6 telas em 4 larguras (360, 768, 1280 e 1920 px) sem estourar o layout e sem rolagem horizontal (24 testes, 1 ignorado: a home em 360 px, conferida à mão) |
| `test/contraste_test.dart` | RNF18: contraste mínimo de 4,5:1 (WCAG 2.1 AA) nos pares de texto e fundo da paleta (15 testes) |
| `supabase/testes/desempenho.sql` | RNF16 (relatório de 12 meses em até 5 s) e a parte do banco do RNF08, com cerca de 8 mil reservas |
| Este documento | Procedimentos e tabelas de resultado das medições manuais |

Nenhum código do app foi alterado. O `desempenho.sql` roda sozinho no workflow **Banco**, como os outros arquivos de `supabase/testes/`.

## 2. Resumo por requisito

| RNF | Requisito | Verificação | Onde |
|---|---|---|---|
| RNF04 | Dados por até 12 meses, depois anonimizados; aviso LGPD | Automatizada e manual | `lgpd.sql`, `reservas.sql` (CT-RNF04-01), `reserva_test.dart`, `agendamentos_test.dart`; seção 8 |
| RNF05 | Sessão expira em 30 min; senhas com hash | Automatizada e documental | `login_test.dart`, `admin_acesso_test.dart`; seção 8 |
| RNF08 | Mudança de disponibilidade na consulta em até 5 s | Automatizada (banco) e manual (tempo na tela) | `desempenho.sql`, `consulta_horarios_test.dart`; ST-04 da 6.4 |
| RNF10 | Reserva concluída sem usar o link do WhatsApp | Automatizada | `sucesso_test.dart`, `comprovante_test.dart` |
| RNF11 | 2 últimas versões de Chrome, Firefox, Edge e Safari | Manual | Seção 6 |
| RNF12 | Telas de 360 px a 1920 px sem rolagem horizontal | Automatizada e manual | `responsividade_test.dart`; seção 4 |
| RNF13 | Disponibilidade de 99% ao mês | Monitoramento contínuo | Seção 7 |
| RNF14 | Backup diário, retenção de 30 dias, teste mensal | Já implementado em workflows; conferir execuções | `backup.yml`, `restauracao.yml`; seção 7 |
| RNF15 | Fuso America/Sao_Paulo, pt-BR, R$ 0,00 | Automatizada | `fuso_test.dart` |
| RNF16 | Relatório de 12 meses em até 5 s | Automatizada (banco) e manual (tela) | `desempenho.sql`; seção 5 |
| RNF17 | Cobertura de 70% e 0 erros no `flutter analyze` | CI para o `analyze`; medição para a cobertura | `ci.yml`; seção 9 |
| RNF18 | Contraste WCAG 2.1 AA e áreas de toque de 48x48 px | Automatizada (contraste) e manual (toque) | `contraste_test.dart`; seção 3 |

## 3. Acessibilidade (RNF18)

### 3.1 Contraste

O `contraste_test.dart` calcula a razão de contraste da WCAG com as cores de `AppColors` e exige pelo menos 4,5:1 nos pares que **passam hoje**, para que não piorem:

| Par (texto sobre fundo) | Razão |
|---|---|
| Texto principal sobre branco, fundo claro e papel | 17,89 · 16,71 · 15,99 |
| Texto secundário sobre branco, fundo claro e papel | 5,38 · 5,03 · 4,81 |
| Branco sobre verde, verde médio e verde escuro | 7,87 · 5,13 · 12,37 |
| Bola de tênis sobre verde escuro | 9,87 |
| Verde sobre verde claro | 7,00 |
| Branco sobre vermelho | 5,62 |
| Chip "Reservado" (vermelho sobre vermelho claro) | 4,81 |
| Chip "Bloqueado" (marrom sobre marrom claro) | 6,53 |

### 3.2 Achados abaixo de 4,5:1

Pelas cores definidas em `consulta_horarios_screen.dart` (texto na cor do estado, sobre o fundo da própria cor com 10% de opacidade):

| Onde | Razão | Situação |
|---|---|---|
| Chip "Passou" (cinza) | 2,76 | Abaixo do AA. O WCAG dispensa componentes inativos, e o estado também vem escrito em texto, mas vale melhorar |
| Chip "Sem preço" (laranja) | 3,34 | Abaixo do AA para texto pequeno |

Sugestão: manter a cor do ponto e da borda e passar o texto desses dois estados para `AppColors.muted`, que dá 4,92 sobre o cinza claro e 4,74 sobre o laranja claro. Esses dois pares **não** estão no teste automatizado, porque hoje falhariam. Quando forem corrigidos, entram na lista de `contraste_test.dart`.

### 3.3 Área de toque

Os horários da consulta têm 92×68 px, acima do mínimo de 48×48 px. Para as demais telas, a conferência é manual:

1. No Chrome, abra o site, aperte **F12** e vá na aba **Lighthouse**.
2. Marque só **Accessibility**, escolha **Mobile** e clique em **Analyze page load**.
3. Anote a nota e os itens reprovados (por exemplo, "Touch targets do not have sufficient size").
4. Repita em: home, reserva, confirmação, login e painel.

| Tela | Nota de acessibilidade | Itens reprovados | Data | Quem |
|---|---|---|---|---|
| Home | | | | |
| Reserva | | | | |
| Confirmação | | | | |
| Login | | | | |
| Painel | | | | |

## 4. Responsividade (RNF12)

O `responsividade_test.dart` abre home, reserva, confirmação, login, painel e reservas do proprietário em 360×800, 768×1024, 1280×800 e 1920×1080. Cada teste falha se o layout estourar (`overflowed by N pixels`) ou se a tela tiver rolagem horizontal.

O app abre primeiro na home. Para o estouro da home não ser atribuído às outras telas, cada teste abre o app numa janela grande, vai para a tela e só então encolhe a janela até o tamanho testado.

Nos testes, o Flutter usa uma fonte mais larga que a real. Um estouro que aparece só em 360 px deve ser conferido no navegador (modo dispositivo, 360 px) antes de virar defeito.

**Home em 360 px:** o teste automático acusou estouro e está ignorado (`skip`). A causa mais provável é a fonte de teste, mas isso não foi confirmado. É preciso abrir a home em 360 px no navegador: se estiver correta, o teste continua ignorado e o resultado fica registrado abaixo; se estourar, é defeito da home, e o `skip` sai depois da correção.

As telas de **preços, feriados e faturamento** têm tabelas e gráficos com rolagem horizontal própria, e são conferidas à mão:

1. No Chrome, aperte **F12** e depois **Ctrl+Shift+M** (modo dispositivo).
2. Escolha "Responsive" e digite a largura.
3. Confira se a **página** (fora do gráfico ou da tabela) não rola na horizontal e se tudo dá para usar.

| Tela | 360 px | 768 px | 1280 px | 1920 px |
|---|---|---|---|---|
| Home | | n/a | n/a | n/a |
| Preços | | | | |
| Feriados | | | | |
| Faturamento | | | | |

Preencha com "ok" ou com a descrição do problema.

## 5. Desempenho (RNF16 e RNF08)

**Automatizado:** o `desempenho.sql` cria 3 quadras de teste com cerca de 8 mil reservas em 12 meses e mede, com limite de 5 segundos cada: o resumo do relatório, o resumo filtrado por telefone, a leitura de data e valor usada pelo gráfico e o faturamento por dia. Mede também a consulta de horários do dia, com limite de 1 segundo. Cada medição aprovada imprime o tempo gasto no log do workflow **Banco**.

**Manual (tempo na tela):** com o app contra o projeto de testes, com reservas dos últimos meses:

1. Abra o painel, vá em Faturamento e escolha um período de 12 meses.
2. Aperte **F12**, aba **Network**, e anote o tempo total das chamadas ao gerar o relatório.
3. Repita 3 vezes.

| Medição | 1ª | 2ª | 3ª | Média | Limite |
|---|---|---|---|---|---|
| Relatório de 12 meses (tela) | | | | | 5 s |
| Mudança de disponibilidade até a tela (ST-04 da 6.4) | | | | | 5 s |

Para medir a carga da home, rode o **Lighthouse** em "Performance", no modo celular, e anote nota e LCP.

## 6. Compatibilidade (RNF11)

Abra o site publicado em cada navegador (as 2 últimas versões estáveis) e confira se consulta, reserva e login funcionam. O Safari exige um Mac ou iPhone.

| Navegador e versão | Consulta | Reserva | Login e painel | Quem | Data |
|---|---|---|---|---|---|
| Chrome (atual) | | | | | |
| Chrome (anterior) | | | | | |
| Firefox (atual) | | | | | |
| Firefox (anterior) | | | | | |
| Edge (atual) | | | | | |
| Edge (anterior) | | | | | |
| Safari (atual) | | | | | |
| Safari (anterior) | | | | | |

## 7. Disponibilidade e backup (RNF13 e RNF14)

**Backup (RNF14).** Já existe nos workflows do repositório:

- `backup.yml`: roda todo dia às 06:30 UTC (03:30 de Brasília), gera o backup cifrado e guarda por 30 dias (`retention-days: 30`).
- `restauracao.yml`: o teste de restauração mensal.

Para verificar, abra a aba **Actions** do GitHub e confira que há uma execução verde de "Backup do banco" por dia e uma de restauração no último mês.

| Verificação | Resultado | Data | Quem |
|---|---|---|---|
| Execuções diárias do backup nos últimos 7 dias | | | |
| Artefato com retenção de 30 dias | | | |
| Última restauração mensal bem-sucedida | | | |

**Disponibilidade (RNF13).** A meta de 99% ao mês permite no máximo cerca de 7 h 12 min fora do ar. Não existe teste pontual para isso: exige monitoramento contínuo. Use uma ferramenta de monitoramento de disponibilidade que acesse a página inicial a cada poucos minutos e registre o resultado.

| Mês | Disponibilidade medida | Ferramenta |
|---|---|---|
| | | |

## 8. Segurança e privacidade (RNF04 e RNF05)

**Visitante anônimo não lê dados de clientes.** O `reservas.sql` já confere isso no banco (CT-RNF04-01). A conferência pela API real, com a anon key do projeto de testes (peça ao Davi):

```bash
curl "URL-DO-PROJETO/rest/v1/reservas?select=*" -H "apikey: ANON-KEY" -H "Authorization: Bearer ANON-KEY"
```

O resultado esperado é uma lista vazia ou um erro de permissão, nunca nomes ou telefones.

| Verificação | Resultado esperado | Resultado | Data | Quem |
|---|---|---|---|---|
| Leitura de `reservas` com a anon key | Lista vazia ou erro de permissão | | | |
| Senha do proprietário guardada com hash | O Supabase Auth guarda a senha com hash (bcrypt). Confirmar na documentação oficial do Supabase Auth e anotar o link | | | |

## 9. Manutenibilidade (RNF17)

**0 erros no `flutter analyze`:** o `ci.yml` já roda `flutter analyze` em todo Pull Request, e qualquer aviso reprova.

**Cobertura mínima de 70%:** ainda não era medida. Para medir:

```powershell
flutter test --coverage
```

Isso cria `coverage/lcov.info`. Para calcular o total no PowerShell:

```powershell
$lf = 0; $lh = 0
Get-Content coverage/lcov.info | ForEach-Object {
  if ($_ -match '^LF:(\d+)') { $lf += [int]$Matches[1] }
  elseif ($_ -match '^LH:(\d+)') { $lh += [int]$Matches[1] }
}
"{0:P1}" -f ($lh / $lf)
```

| Medição | Resultado | Meta | Data | Quem |
|---|---|---|---|---|
| Cobertura de linhas | | 70% | | |
| `flutter analyze` | | 0 problemas | | |

Se ficar abaixo de 70%, o relatório aponta quais arquivos têm menos cobertura, e a diferença vira item para o grupo. Uma verificação automática no CI pode ser combinada depois, quando a meta estiver atingida.

## 10. Achados

| N.º | Requisito | O que aconteceu | Quem avisou |
|---|---|---|---|
| 1 | RNF18 | Chip "Passou" com contraste de 2,76:1 | |
| 2 | RNF18 | Chip "Sem preço" com contraste de 3,34:1 | |
| 3 | RNF12 | Home em 360 px: o teste automático acusou estouro (causa provável: fonte de teste). Conferir no navegador | |
| | | | |

## 11. Como conferir

```bash
flutter test test/responsividade_test.dart
flutter test test/contraste_test.dart
flutter test
flutter analyze
```

O `desempenho.sql` roda sozinho no workflow **Banco** do Pull Request.
