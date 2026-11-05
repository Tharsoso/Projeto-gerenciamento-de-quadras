#!/usr/bin/env bash
# =============================================================================
# Backup do banco (atividade 5.9, RNF14, regras B2–B6).
#
#   SUPABASE_DB_URL=postgresql://... BACKUP_AGE_PUBLICA=age1... \
#     supabase/backup/backup.sh <pasta-de-saida>
#
# Gera <pasta>/gqt-AAAA-MM-DD-HHMM.tar.gz.age (cifrado) e <pasta>/manifesto.txt
# (só contagens, sem dados pessoais). Dentro do arquivo cifrado:
#   public.dump      esquema public inteiro (estrutura + dados), formato custom
#   auth.dump        tabelas auth.users e auth.identities (estrutura + dados)
#   manifesto.txt    linhas de cada tabela, na mesma foto (snapshot) dos dumps
#   permissoes.txt   permissões de PUBLIC/anon/authenticated/service_role por objeto
#
# Precisa de psql/pg_dump com versão >= a do servidor (17) e do age.
# =============================================================================
set -euo pipefail

saida=${1:?"uso: backup.sh <pasta-de-saida>"}
: "${SUPABASE_DB_URL:?defina SUPABASE_DB_URL (URL do Session pooler)}"

# B6: sem chave pública não há backup; texto aberto em repositório público é vazamento.
if [[ "${BACKUP_AGE_PUBLICA:-}" != age1* ]]; then
  echo "::error::BACKUP_AGE_PUBLICA ausente ou inválida (deve começar com age1). Backup cancelado." >&2
  exit 1
fi

trabalho=$(mktemp -d)
trap 'rm -rf "$trabalho"' EXIT
nome="gqt-$(TZ=America/Sao_Paulo date +%Y-%m-%d-%H%M)"
pasta="$trabalho/$nome"
mkdir -p "$pasta" "$saida"

# Uma transação só de leitura fica aberta enquanto os dumps rodam: contagens e dumps
# veem exatamente os mesmos dados (pg_export_snapshot + pg_dump --snapshot).
coproc PSQL { psql "$SUPABASE_DB_URL" -X -q -At -v ON_ERROR_STOP=1; }
enviar() { printf '%s\n' "$1" >&"${PSQL[1]}"; }
ler_ate_fim() {
  local linha
  while IFS= read -r linha <&"${PSQL[0]}"; do
    [[ "$linha" == "__FIM__" ]] && return 0
    printf '%s\n' "$linha"
  done
  echo "::error::a conexão com o banco caiu durante o backup" >&2
  return 1
}

enviar "begin isolation level repeatable read read only; select pg_export_snapshot(); select '__FIM__';"
snapshot=$(ler_ate_fim)

enviar "select table_schema || '.' || table_name || '|' ||
               (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from %I.%I',
                       table_schema, table_name), false, true, '')))[1]::text
          from information_schema.tables
         where table_type = 'BASE TABLE'
           and (table_schema = 'public' or (table_schema, table_name) in
                (('auth', 'users'), ('auth', 'identities')))
         order by 1;
        select '__FIM__';"
ler_ate_fim > "$pasta/manifesto.txt"

# Permissões de anon/authenticated/service_role por objeto, para a restauração conferir.
enviar "$(cat "$(dirname "$0")/permissoes.sql") select '__FIM__';"
ler_ate_fim > "$pasta/permissoes.txt"

pg_dump "$SUPABASE_DB_URL" --snapshot="$snapshot" --format=custom --no-owner \
  --schema=public --file="$pasta/public.dump"
pg_dump "$SUPABASE_DB_URL" --snapshot="$snapshot" --format=custom --no-owner \
  --table=auth.users --table=auth.identities --file="$pasta/auth.dump"

enviar "commit; \\q"
wait "$PSQL_PID" 2>/dev/null || true

tar -czf - -C "$trabalho" "$nome" | age -r "$BACKUP_AGE_PUBLICA" > "$saida/$nome.tar.gz.age"
cp "$pasta/manifesto.txt" "$saida/manifesto.txt"

echo "Backup: $saida/$nome.tar.gz.age ($(du -h "$saida/$nome.tar.gz.age" | cut -f1))"
echo "Tabelas e linhas:"
sed 's/^/  /' "$saida/manifesto.txt"
