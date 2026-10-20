# Gerenciamento de Quadras de Tênis (gqt)

Sistema web para reserva de quadras de tênis. Trabalho prático de **CSI405 – Gerência de
Projetos de Software** (UFOP, 2026/2).

- **Público (sem login):** consulta os horários livres de cada quadra, em tempo real, e faz a
  reserva informando nome e telefone.
- **Proprietário (com login):** cadastra quadras, horários de funcionamento, preços e feriados,
  bloqueia horários para manutenção, cancela reservas e consulta o faturamento.

## Equipe

| Integrante | Papel |
|---|---|
| Tharsos G. C. Fernandes | Gerente de projeto |
| Davi E. P. Fonseca | Back-end (Supabase) |
| João Vitor C. Silva | Front-end (Flutter) |
| Arthur F. F. Vasconcelos | Qualidade e testes |

## Tecnologias

- **Front-end:** Flutter Web, publicado no GitHub Pages
- **Back-end:** [Supabase](https://supabase.com) (plano gratuito): PostgreSQL, Auth, Row Level
  Security, Realtime e `pg_cron`
- **CI e backup:** GitHub Actions

## Estrutura

```
lib/                  código do app Flutter
test/                 testes
web/                  index.html, ícones e manifest do site
supabase/
  config.toml         configuração da CLI do Supabase
  migrations/         schema do banco (uma migração por mudança)
  seed.sql            dados de exemplo (3 quadras, preços e feriados)
```

## Como rodar

Pré-requisitos: [Flutter](https://docs.flutter.dev/get-started/install) estável (usado: 3.47)
e Google Chrome.

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=<url do projeto> \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

A URL e a anon key são passadas pelo responsável pelo back-end. A anon key é pública (vai no
JavaScript do site); a segurança dos dados está no RLS. A chave `service_role` **nunca** entra
no app nem no repositório.

## Banco de dados

O schema só muda por um arquivo novo em `supabase/migrations/`, com aviso no grupo; nada de
alterar tabelas pelo painel do Supabase. Para aplicar as migrações no projeto remoto
([Supabase CLI](https://supabase.com/docs/guides/cli)):

```bash
npx supabase login
npx supabase link --project-ref <project ref>
npx supabase db push
```

As funções e as regras que o front-end usa (consulta de horários, reserva, erros) estão
descritas no contrato do banco, mantido com a documentação do projeto.
