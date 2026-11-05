-- Permissões dos papéis da API (PUBLIC, anon, authenticated, service_role) em cada
-- tabela, sequência e função do esquema public, uma linha por objeto. Sem dados
-- pessoais. O backup grava esta lista e a restauração confere se ficou igual
-- (atividade 5.9, B7). O dono e os papéis administrativos ficam de fora, porque mudam
-- conforme quem restaura.
with objetos as (
  select 'tabela ' || c.relname as objeto, c.relacl as acl, c.relowner as dono,
         case c.relkind when 'S' then 's' else 'r' end as tipo
    from pg_class c
   where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'S', 'v')
  union all
  select 'funcao ' || p.oid::regprocedure::text, p.proacl, p.proowner, 'f'
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace
)
select o.objeto || '|' || coalesce(
         (select string_agg(case when a.grantee = 0 then 'PUBLIC' else a.grantee::regrole::text end
                            || ':' || a.privilege_type, ',' order by 1)
            from aclexplode(coalesce(o.acl, acldefault(o.tipo::"char", o.dono))) a
           where a.grantee = 0
              or a.grantee::regrole::text in ('anon', 'authenticated', 'service_role')),
         '-')
  from objetos o
 order by 1;
