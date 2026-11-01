# Atividade 5.2 · Cadastro e gestão de quadras (H8 · RF12)

Autor: Davi · Branch: `feat/5.2-quadras` · Para: João (ligar o login da 5.1)

## 1. O que foi feito

O proprietário lista, cadastra, edita e inativa quadras. Não existe excluir: o banco revoga
`DELETE` em `quadras` e inativar é `ativa = false`. O visual segue o protótipo **Ace Saibro**
(tela "Quadras" da área admin).

| Arquivo | O que tem |
|---|---|
| `lib/admin/quadras_page.dart` | Tela: lista, botão "Nova quadra" e diálogo de criar/editar |
| `lib/admin/quadras_repositorio.dart` | `QuadrasRepositorio` (interface), `SupabaseQuadrasRepositorio` (real) e `traduzirErro` |
| `lib/models/quadra.dart` | `Quadra`, `DadosQuadra` e `TipoPiso` (valores do banco + cores dos chips) |
| `lib/tema/ace_cores.dart` | Cores do protótipo, com os mesmos nomes dos tokens CSS, para as próximas telas |
| `test/quadras_test.dart` | 9 testes com um repositório falso que repete as regras do banco |
| `lib/app.dart` | Nova rota `/admin/quadras` dentro do `ShellRoute` (exige login) |
| `lib/main.dart` | Rota `/admin/quadras` provisória, para abrir a tela pelo painel-protótipo |
| `lib/screens/admin/painel_prototipo_screen.dart` | O card "Quadras" agora abre a tela |
| `lib/admin/painel_page.dart` | Botão "Quadras" no painel do `app.dart` |

### Conversa com o banco

Nada de mock no app, só nos testes. A tela usa o Supabase de verdade:

| Ação | Chamada |
|---|---|
| Listar | `from('quadras').select('id, nome, tipo_piso, descricao, ativa').order('nome')` |
| Criar | `from('quadras').insert({...}).select(...).single()` |
| Editar / inativar | `from('quadras').update({...}).eq('id', id).select(...).single()` |

As regras ficam no banco (gatilho `validar_quadra`), e o app só mostra a mensagem que vem dele:

| `hint` do erro | Quando | Onde aparece |
|---|---|---|
| `QUADRA_NOME_DUPLICADO` | Nome igual a outro (sem diferenciar maiúsculas/espaços) | Embaixo do campo Nome |
| `QUADRA_COM_RESERVAS` | Inativar quadra com reservas futuras | Alerta vermelho no diálogo |
| código `42501` ou `PGRST116` | **Sem login** (RLS recusou) | "Sua sessão expirou. Entre novamente." |

Conferido em 01/11 com a chave do `env.json`: o banco devolve as 3 quadras do seed
(Rápida 1, Saibro 1 e Saibro 2) e `horarios_do_dia` responde com preços.

## 2. Por que gravar ainda não funciona no `main.dart` atual

O RLS do banco é:

```sql
-- público (anon): só lê quadras ativas
create policy "publico le quadras ativas" on public.quadras for select to anon using (ativa);
-- proprietário logado (authenticated): tudo
create policy "proprietario gerencia quadras" on public.quadras for all to authenticated using (true) with check (true);
```

O `main.dart` de hoje roda o `GqtApp` com o `LoginPrototipoScreen`, que só valida o formulário
e navega, **sem chamar o Supabase Auth**. Então o app fala com o banco como `anon`:
- a lista mostra só as quadras **ativas** (as inativas somem);
- salvar devolve "Sua sessão expirou. Entre novamente."

Quando existir uma sessão do Supabase Auth, o `supabase_flutter` manda o token sozinho em
toda chamada, e a tela de Quadras passa a funcionar **sem mudar nada nela**.

## 3. O que já existe da 5.1 (login)

Já está no `main`, só não está ligado ao `main.dart`:

| Arquivo | O que faz |
|---|---|
| `lib/auth/autenticacao.dart` | `SupabaseAutenticacao`: `entrar()` chama `signInWithPassword`, `sair()` chama `signOut`; avisa o roteador quando a sessão muda |
| `lib/auth/login_page.dart` | Tela de login real (erro genérico "E-mail ou senha inválidos") |
| `lib/auth/controle_inatividade.dart` | Sai sozinho após 30 min sem interação (RNF05) |
| `lib/app.dart` | `App` com `go_router`: `/admin/*` exige login, `/login` redireciona para `/admin` se já logado, sessão expirada vai para `/login?expirou=1` |
| `test/login_test.dart` | Testes do fluxo de login |

O usuário do proprietário é criado no painel do Supabase (Authentication → Users), porque o
cadastro público está desligado. Peça o e-mail e a senha de teste ao Davi.

## 4. Como ligar (sugestão)

A ideia é **um app só**: o `App` do `app.dart` (go_router + login), recebendo as suas telas.

### 4.1 `main.dart`: rodar o `App`

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'auth/autenticacao.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseAnonKey);
  runApp(App(auth: SupabaseAutenticacao(Supabase.instance.client.auth)));
}
```

### 4.2 `app.dart`: trazer as suas telas e o seu tema

- `/` → `ConsultaHorariosScreen` (no lugar do `InicioPage` provisório).
- `/reserva` → `ReservaPrototipoScreen`, fora do `ShellRoute` (é pública).
- `/admin` → o seu painel ou o `PainelPage`, como preferir. Ele precisa de um botão "Sair"
  que chame `auth.sair()`.
- `/login` → `LoginPage(auth: ...)` já faz o login de verdade. Se quiser o seu visual, troque
  o `onPressed` do seu protótipo para chamar `auth.entrar(email:, senha:)` e mostrar
  `FalhaLogin.mensagem` no erro.
- No `MaterialApp.router`, use `theme: AppTheme.light()`, os `localizationsDelegates` e
  `supportedLocales: [Locale('pt', 'BR')]` que hoje estão no `GqtApp`.

### 4.3 Trocar a navegação por `go_router`

Com `MaterialApp.router`, `Navigator.pushNamed('/rota')` não encontra as rotas. Troque:

| Hoje | Com go_router |
|---|---|
| `consulta_horarios_screen.dart:73` `pushNamed('/admin/login')` | `context.go('/admin')` (o redirect manda para `/login` se precisar) |
| `consulta_horarios_screen.dart:213` `pushNamed('/reserva', arguments: {...})` | `context.push('/reserva', extra: {...})` |
| `reserva_prototipo_screen.dart:24` `ModalRoute...settings.arguments` | `GoRouterState.of(context).extra as Map?` (ou passar pelo construtor no `builder` da rota) |
| `login_prototipo_screen.dart:71` `pushReplacementNamed('/admin')` | Não navegar: depois do `auth.entrar`, o redirect leva para `/admin` sozinho |
| `painel_prototipo_screen.dart:24` "Sair" | `auth.sair()`: o redirect leva para `/login` |
| `painel_prototipo_screen.dart:66` `pushNamed(item.rota!)` | `context.go(item.rota!)` |

Depois disso, apague do `main.dart` a rota provisória `/admin/quadras` e o `GqtApp`. A rota
certa já está em `app.dart`, protegida pelo login.

### 4.4 Testes

- `test/widget_test.dart` usa o `LoginPrototipoScreen`. Se ele sair, adapte ou apague.
- `test/login_test.dart` usa `App(auth: AutenticacaoFalsa())`. Para testar Quadras dentro do
  `App`, passe também `quadras: QuadrasFalsas([...])` (classe em `test/quadras_test.dart`).
- Rodar: `flutter analyze && flutter test` (o mesmo que o CI faz).

## 5. Como conferir que ficou ligado

```bash
flutter run -d web-server --web-hostname localhost --web-port 8090 --dart-define-from-file=env.json
```

1. Abrir `http://localhost:8090/#/admin/quadras` sem login → deve ir para a tela de login.
2. Entrar com o usuário do proprietário → painel → Quadras.
3. Criar "Teste 1" → aparece na lista com "Quadra criada…".
4. Criar "teste 1" de novo → "Já existe uma quadra com este nome." no campo.
5. Inativar "Teste 1" → chip "Inativa", e ela continua na lista (o `anon` não veria).
6. Na consulta pública (`/`), "Teste 1" não aparece.
7. Ficar 30 min parado na área admin → volta ao login com aviso de sessão expirada.

Qualquer dúvida sobre o banco: `../modelagem/contrato_banco.md` (fora do repositório) ou
falar com o Davi.
