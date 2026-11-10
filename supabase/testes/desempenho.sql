-- =============================================================================
-- Desempenho do banco com 12 meses de reservas (atividade 6.5).
--
-- RNF16: o relatório de 12 meses é gerado em até 5 segundos.
-- RNF08 (parte do banco): a consulta de horários do dia responde em menos de 1 segundo, para
-- sobrar tempo da meta de 5 s entre a mudança e a tela (o resto é a rede e o Realtime, medido
-- no teste do sistema, ST-04 da atividade 6.4).
--
-- Roda numa transação e desfaz tudo no fim. Cria 3 quadras de teste ("ZZ Perf n") com cerca
-- de 8 mil reservas nos últimos 12 meses, então não depende do seed.sql. Cada medição
-- aprovada imprime "OK  CT-..." com o tempo gasto. Falha com "TESTE FALHOU: ..." se passar do
-- limite. No GitHub roda sozinho no workflow Banco (supabase/testes/*.sql).
--   psql "$URL" -v ON_ERROR_STOP=1 -f supabase/testes/desempenho.sql
-- =============================================================================
begin;

create function pg_temp.medir(p_caso text, p_limite_ms numeric, p_inicio timestamptz, p_detalhe text)
returns void
language plpgsql
as $$
declare
  v_ms numeric := round(extract(epoch from (clock_timestamp() - p_inicio)) * 1000);
begin
  if v_ms > p_limite_ms then
    raise exception 'TESTE FALHOU [%]: levou % ms e o limite é % ms (%)', p_caso, v_ms, p_limite_ms, p_detalhe;
  end if;
  raise notice 'OK  % em % ms, limite % ms (%)', p_caso, v_ms, p_limite_ms, p_detalhe;
end;
$$;

do $$
declare
  v_hoje  date := public.agora_local()::date;
  v_ini   date := v_hoje - 365;
  v_fim   date := v_hoje - 1;
  n       bigint;
  v_tel   text;
  v_t     timestamptz;
  rs      record;
begin
  -- ------------------------------------------------------------ cenário
  insert into public.quadras (nome, tipo_piso)
  select 'ZZ Perf ' || g, 'saibro' from generate_series(1, 3) g;
  insert into public.horarios_funcionamento (quadra_id, dia_semana, abertura, fechamento)
  select q.id, d, '07:00', '22:00'
    from public.quadras q cross join generate_series(0, 6) d
   where q.nome like 'ZZ Perf %';
  insert into public.faixas_preco (quadra_id, tipo_dia, hora_inicio, hora_fim, valor)
  select q.id, t.tipo_dia, '07:00', '22:00', t.valor
    from public.quadras q
   cross join (values ('util', 60.00), ('fim_de_semana', 100.00)) t(tipo_dia, valor)
   where q.nome like 'ZZ Perf %';

  -- Metade dos horários das 3 quadras ocupada, 1 em cada 11 cancelada.
  insert into public.reservas (quadra_id, data, hora_inicio, nome_cliente, telefone, valor, status)
  select q.id, d::date, make_time(h, 0, 0),
         'Cliente Teste ' || ((q.id + extract(doy from d)::int + h) % 600),
         '319' || lpad(((q.id + extract(doy from d)::int + h) % 600)::text, 8, '0'),
         60 + (h % 3) * 20,
         case when (q.id + extract(doy from d)::int + h) % 11 = 0 then 'cancelada' else 'confirmada' end
    from public.quadras q
   cross join generate_series(v_ini, v_fim, interval '1 day') d
   cross join generate_series(7, 21) h
   where q.nome like 'ZZ Perf %'
     and (extract(doy from d)::int + h + q.id) % 2 = 0;

  select count(*) into n from public.reservas r join public.quadras q on q.id = r.quadra_id
   where q.nome like 'ZZ Perf %';
  raise notice 'massa de teste: % reservas nos últimos 12 meses', n;
  if n < 5000 then
    raise exception 'TESTE FALHOU [massa de teste]: só % reservas criadas (mínimo 5000)', n;
  end if;
  select telefone into v_tel from public.reservas r join public.quadras q on q.id = r.quadra_id
   where q.nome like 'ZZ Perf %' and r.telefone is not null limit 1;

  -- ------------------------------------------------------------ RNF16: relatório de 12 meses
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  v_t := clock_timestamp();
  select * into rs from public.resumo_faturamento(v_ini, v_fim);
  perform pg_temp.medir('CT-RNF16-01 relatório de 12 meses (totais)', 5000, v_t,
                        rs.qtd_locacoes || ' locações, ' || rs.qtd_canceladas || ' canceladas');

  v_t := clock_timestamp();
  select * into rs from public.resumo_faturamento(v_ini, v_fim, v_tel);
  perform pg_temp.medir('CT-RNF16-01 relatório de 12 meses filtrado por telefone', 5000, v_t,
                        rs.qtd_locacoes || ' locações do cliente');

  -- O gráfico do relatório lê data e valor das reservas confirmadas do período.
  v_t := clock_timestamp();
  select count(*) into n from (
    select data, valor from public.reservas
     where status = 'confirmada' and data >= v_ini and data <= v_fim
     order by id
  ) linhas;
  perform pg_temp.medir('CT-RNF16-01 leitura de data e valor de 12 meses (gráfico)', 5000, v_t, n || ' linhas');

  v_t := clock_timestamp();
  select count(*) into n from (
    select data, sum(valor) from public.reservas
     where status = 'confirmada' and data >= v_ini and data <= v_fim
     group by data
  ) por_dia;
  perform pg_temp.medir('CT-RNF16-01 faturamento por dia em 12 meses', 5000, v_t, n || ' dias');

  perform set_config('request.jwt.claim.role', '', true);

  -- ------------------------------------------------------------ RNF08 (banco): consulta do dia
  v_t := clock_timestamp();
  select count(*) into n from public.horarios_do_dia(v_hoje - 30);
  perform pg_temp.medir('CT-RNF08-01 (parte do banco) consulta de horários do dia', 1000, v_t, n || ' horários');
end;
$$;

rollback;

select 'TODAS AS MEDICOES DENTRO DO LIMITE' as resultado;
