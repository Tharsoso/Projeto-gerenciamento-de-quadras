-- =============================================================================
-- Teste das regras L3 e L4 da atividade 5.9 (LGPD, RNF04).
-- Roda numa transação e desfaz tudo no fim: pode rodar em qualquer banco com o schema.
--   psql "$URL" -v ON_ERROR_STOP=1 -f supabase/testes/lgpd.sql
-- Precisa de pelo menos uma quadra. As reservas de teste entram como canceladas para não
-- disputar horário com reservas reais (índice único só vale para confirmadas). Falha com "TESTE FALHOU: ..." se uma regra não valer.
-- =============================================================================
begin;

do $$
declare
  v_quadra bigint := (select min(id) from public.quadras);
  v_hoje   date := public.agora_local()::date;
  v_limite date := (public.agora_local()::date - interval '12 months')::date;
  v_velha  bigint;
  v_borda  bigint;
  v_nova   bigint;
  v_qtd    int;
  r        record;
begin
  -- Reserva de 12 meses e 1 dia atrás, cancelada com motivo que cita o cliente.
  insert into public.reservas (quadra_id, data, hora_inicio, nome_cliente, telefone, valor, status)
  values (v_quadra, v_limite - 1, '07:00', 'Maria Teste', '31999990001', 60, 'cancelada')
  returning id into v_velha;
  insert into public.log_cancelamentos (reserva_id, motivo) values (v_velha, 'Maria avisou que viajou');

  -- Reserva de exatamente 12 meses atrás: ainda não é "anterior" ao limite.
  insert into public.reservas (quadra_id, data, hora_inicio, nome_cliente, telefone, valor, status)
  values (v_quadra, v_limite, '08:00', 'Pedro Teste', '31999990002', 90, 'cancelada')
  returning id into v_borda;

  -- Reserva recente cancelada: nada muda.
  insert into public.reservas (quadra_id, data, hora_inicio, nome_cliente, telefone, valor, status)
  values (v_quadra, v_hoje - 10, '09:00', 'Ana Teste', '31999990003', 60, 'cancelada')
  returning id into v_nova;
  insert into public.log_cancelamentos (reserva_id, motivo) values (v_nova, 'Ana pediu');

  v_qtd := public.anonimizar_reservas_antigas();
  if v_qtd < 1 then raise exception 'TESTE FALHOU: nenhuma reserva anonimizada'; end if;

  -- L3: dados pessoais saem, valor/data/status ficam.
  select * into r from public.reservas where id = v_velha;
  if r.nome_cliente <> 'Cliente anonimizado' or r.telefone is not null or not r.anonimizada then
    raise exception 'TESTE FALHOU: reserva antiga não foi anonimizada (%)', row_to_json(r);
  end if;
  if r.valor <> 60 or r.data <> v_limite - 1 or r.status <> 'cancelada' then
    raise exception 'TESTE FALHOU: anonimização mexeu em valor/data/status (%)', row_to_json(r);
  end if;

  -- L4: motivo do cancelamento apagado, o resto do log fica.
  if (select motivo from public.log_cancelamentos where reserva_id = v_velha) is not null then
    raise exception 'TESTE FALHOU: motivo do cancelamento continua na reserva anonimizada';
  end if;
  if not exists (select 1 from public.log_cancelamentos where reserva_id = v_velha) then
    raise exception 'TESTE FALHOU: o log do cancelamento sumiu';
  end if;

  -- Borda: exatamente 12 meses ainda não anonimiza.
  if (select anonimizada from public.reservas where id = v_borda) then
    raise exception 'TESTE FALHOU: reserva de exatamente 12 meses foi anonimizada';
  end if;

  -- Recente: intacta, com motivo.
  if (select telefone from public.reservas where id = v_nova) is distinct from '31999990003'
     or (select motivo from public.log_cancelamentos where reserva_id = v_nova) is distinct from 'Ana pediu' then
    raise exception 'TESTE FALHOU: reserva recente foi alterada';
  end if;

  -- Rodar de novo não anonimiza nada a mais.
  if public.anonimizar_reservas_antigas() <> 0 then
    raise exception 'TESTE FALHOU: segunda execução anonimizou de novo';
  end if;

  -- Ninguém de fora chama a função.
  if has_function_privilege('anon', 'public.anonimizar_reservas_antigas()', 'execute')
     or has_function_privilege('authenticated', 'public.anonimizar_reservas_antigas()', 'execute') then
    raise exception 'TESTE FALHOU: anon/authenticated podem chamar a anonimização';
  end if;

  raise notice 'LGPD OK: L3 e L4 conferidas';
end;
$$;

rollback;
