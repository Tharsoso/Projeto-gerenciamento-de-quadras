-- =============================================================================
-- Atividade 5.9 · LGPD (RNF04), regra L4
--
-- A anonimização diária também apaga o motivo do cancelamento das reservas
-- anonimizadas: é texto livre digitado pelo proprietário e pode citar o cliente
-- ("João avisou que viajou"). Quem cancelou e quando continuam no log (RNF06).
--
-- O resto da regra não muda (L3): reserva com data anterior a hoje − 12 meses, no
-- horário de Brasília, vira "Cliente anonimizado", telefone null e anonimizada = true.
-- O agendamento no pg_cron (L5) continua o da migration inicial.
-- =============================================================================

create or replace function public.anonimizar_reservas_antigas()
returns int
language sql
security definer
set search_path = public
as $$
  with a as (
    update public.reservas
       set nome_cliente = 'Cliente anonimizado', telefone = null, anonimizada = true
     where not anonimizada
       and data < (public.agora_local()::date - interval '12 months')
    returning id
  ), m as (
    update public.log_cancelamentos l
       set motivo = null
      from a
     where l.reserva_id = a.id
       and l.motivo is not null
    returning 1
  )
  select count(*)::int from a
$$;

-- Também limpa os motivos de reservas que já tinham sido anonimizadas antes desta
-- migration.
update public.log_cancelamentos l
   set motivo = null
  from public.reservas r
 where r.id = l.reserva_id
   and r.anonimizada
   and l.motivo is not null;

-- create or replace mantém os privilégios: a função continua sem EXECUTE para anon e
-- authenticated (só o pg_cron e o postgres a chamam).
