#!/usr/bin/env bash
# =============================================================================
# Restauração de um backup (atividade 5.9, RNF14 B7 e RNF04 L7).
#
#   BACKUP_AGE_CHAVE='AGE-SECRET-KEY-1...' DESTINO_URL=postgresql://... \
#     supabase/backup/restaurar.sh <modo> <arquivo.tar.gz.age>
#
# Modos:
#   teste         destino é um Postgres do Supabase vazio e descartável (imagem
#                 supabase/postgres), conectado como supabase_admin (dono do auth).
#                 Recria auth.users/auth.identities com a estrutura
#                 do backup, restaura, anonimiza e confere tudo contra o manifesto.
#   projeto-novo  destino é um projeto Supabase NOVO, sem as migrations aplicadas.
#                 Restaura só os dados do auth (a estrutura já é a do Supabase),
#                 restaura o public, anonimiza e reagenda a anonimização no pg_cron.
#
# Sem BACKUP_AGE_CHAVE no ambiente, o age pede a chave pela entrada padrão: cole a
# chave AGE-SECRET-KEY-1... e tecle Ctrl+D. Assim ela não fica gravada em disco.
# =============================================================================
set -euo pipefail

modo=${1:?"uso: restaurar.sh teste|projeto-novo <arquivo.tar.gz.age>"}
arquivo=${2:?"uso: restaurar.sh teste|projeto-novo <arquivo.tar.gz.age>"}
: "${DESTINO_URL:?defina DESTINO_URL (banco de destino)}"
[[ "$modo" == teste || "$modo" == projeto-novo ]] || { echo "modo inválido: $modo" >&2; exit 2; }

trabalho=$(mktemp -d)
trap 'rm -rf "$trabalho"' EXIT

if [[ -n "${BACKUP_AGE_CHAVE:-}" ]]; then
  age -d -i <(printf '%s\n' "$BACKUP_AGE_CHAVE") "$arquivo" | tar -xzf - -C "$trabalho"
else
  echo "Cole a chave privada (AGE-SECRET-KEY-1...) e tecle Ctrl+D:" >&2
  age -d -i - "$arquivo" | tar -xzf - -C "$trabalho"
fi
pasta=$(find "$trabalho" -mindepth 1 -maxdepth 1 -type d | head -1)
echo "Backup aberto: $(basename "$pasta")"

sql() { psql "$DESTINO_URL" -X -q -At -v ON_ERROR_STOP=1 -c "$1"; }

# 1. auth primeiro: log_cancelamentos.cancelado_por aponta para auth.users.
if [[ "$modo" == teste ]]; then
  # A imagem do Postgres pode ter uma versão do auth diferente da do projeto real;
  # recriar as duas tabelas com a estrutura do backup evita diferença de colunas.
  sql "drop table if exists auth.identities, auth.users cascade;"
  pg_restore --dbname="$DESTINO_URL" --no-owner --exit-on-error "$pasta/auth.dump"
else
  pg_restore --dbname="$DESTINO_URL" --no-owner --exit-on-error --data-only "$pasta/auth.dump"
fi

# 2. Esquema public (estrutura, dados, RLS e publicação do Realtime), em duas passadas.
#    O Supabase tem "default privileges" que dão tudo a anon/authenticated em cada objeto
#    novo, e o pg_dump grava as permissões supondo o padrão do Postgres: sem zerar antes,
#    a restauração deixaria o anon escrever em reservas. Então: (a) objetos sem as
#    permissões, (b) zera as permissões dos papéis da API, (c) aplica as do backup.
#    Ficam de fora o CREATE/COMMENT/ACL do esquema public e os DEFAULT ACL: os dois já
#    existem em todo projeto Supabase e só o dono da plataforma (supabase_admin) os altera.
pg_restore --list "$pasta/public.dump" \
  | grep -Ev '(SCHEMA - public|SCHEMA public) |[0-9]+ DEFAULT ACL ' > "$trabalho/lista.txt"
grep -Ev '[0-9]+ ACL ' "$trabalho/lista.txt" > "$trabalho/objetos.txt"
grep -E '[0-9]+ ACL ' "$trabalho/lista.txt" > "$trabalho/permissoes.txt"
pg_restore --dbname="$DESTINO_URL" --no-owner --exit-on-error \
  --use-list="$trabalho/objetos.txt" "$pasta/public.dump"
sql "revoke all on all tables    in schema public from public, anon, authenticated, service_role;
     revoke all on all sequences in schema public from public, anon, authenticated, service_role;
     revoke all on all functions in schema public from public, anon, authenticated, service_role;"
pg_restore --dbname="$DESTINO_URL" --no-owner --exit-on-error \
  --use-list="$trabalho/permissoes.txt" "$pasta/public.dump"

# 3. L7: o backup pode trazer dados que já foram anonimizados depois dele.
anonimizadas=$(sql "select public.anonimizar_reservas_antigas();")
echo "Anonimizadas depois da restauração: $anonimizadas"

if [[ "$modo" == projeto-novo ]]; then
  # O agendamento fica no esquema cron, que não entra no backup (L5).
  sql "create extension if not exists pg_cron;
       select cron.schedule('anonimizar-reservas', '0 3 * * *',
                            'select public.anonimizar_reservas_antigas()');" >/dev/null
  echo "Anonimização reagendada no pg_cron (0 3 * * *, UTC)."
fi

# 4. Conferências.
falhas=0
while IFS='|' read -r tabela esperado; do
  [[ -z "$tabela" ]] && continue
  atual=$(sql "select count(*) from $tabela;")
  if [[ "$atual" == "$esperado" ]]; then
    echo "  ok     $tabela: $atual"
  else
    echo "  ERRO   $tabela: backup tinha $esperado, restauração tem $atual"
    falhas=$((falhas + 1))
  fi
done < "$pasta/manifesto.txt"

if diff <(psql "$DESTINO_URL" -X -q -At -v ON_ERROR_STOP=1 -f "$(dirname "$0")/permissoes.sql") \
        "$pasta/permissoes.txt" > "$trabalho/permissoes.diff"; then
  echo "  ok     permissões de anon/authenticated/service_role iguais às do backup"
else
  echo "  ERRO   permissões diferentes do backup (< restaurado, > backup):"
  sed 's/^/           /' "$trabalho/permissoes.diff"
  falhas=$((falhas + 1))
fi

if sql "select count(*) from public.horarios_do_dia(public.agora_local()::date);" >/dev/null; then
  echo "  ok     horarios_do_dia responde"
else
  echo "  ERRO   horarios_do_dia falhou"; falhas=$((falhas + 1))
fi

restantes=$(sql "select count(*) from public.reservas
                  where telefone is not null
                    and data < (public.agora_local()::date - interval '12 months');")
if [[ "$restantes" == 0 ]]; then
  echo "  ok     nenhuma reserva com mais de 12 meses tem telefone (LGPD)"
else
  echo "  ERRO   $restantes reservas com mais de 12 meses ainda têm telefone"
  falhas=$((falhas + 1))
fi

if (( falhas > 0 )); then
  echo "::error::Restauração com $falhas problema(s)." >&2
  exit 1
fi
echo "Restauração conferida: tudo ok."
