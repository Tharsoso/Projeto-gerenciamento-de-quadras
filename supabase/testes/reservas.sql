
begin;

create function pg_temp.esperar_erro(p_caso text, p_sql text, p_hint text)
returns void
language plpgsql
as $$
declare
  v_hint text;
begin
  begin
    execute p_sql;
  exception when others then
    get stacked diagnostics v_hint = pg_exception_hint;
    if v_hint is distinct from p_hint then
      raise exception 'TESTE FALHOU [%]: esperava o erro % e veio % (%)',
        p_caso, p_hint, coalesce(v_hint, 'sem hint'), sqlerrm;
    end if;
    raise notice 'OK  %', p_caso;
    return;
  end;
  raise exception 'TESTE FALHOU [%]: esperava o erro % mas a operação foi aceita', p_caso, p_hint;
end;
$$;


create function pg_temp.sql_reservar(p_quadra bigint, p_data date, p_hora text, p_nome text, p_tel text)
returns text
language sql
as $$
  select format('select * from public.criar_reserva(%s, %L, %L, %L, %L)',
                p_quadra, p_data, p_hora, p_nome, p_tel)
$$;

create function pg_temp.verificar(p_caso text, p_ok boolean, p_detalhe text default '')
returns void
language plpgsql
as $$
begin
  if p_ok is not true then
    raise exception 'TESTE FALHOU [%]: %', p_caso, p_detalhe;
  end if;
  raise notice 'OK  %', p_caso;
end;
$$;

do $$
declare
  v_q      bigint;
  v_q2     bigint;
  v_hoje   date := public.agora_local()::date;
  v_data   date;                 -- uma segunda-feira (dia útil) a ~400 dias
  v_fer    date;                 -- outra segunda-feira, usada como feriado
  r        record;
  v_maria  bigint;               -- reserva 10:00 de Maria
  v_noite  bigint;               -- reserva 19:00
  v_c1     bigint;
  v_c2     bigint;
  v_passada bigint;
  n        int;
  t        record;
begin

  v_data := v_hoje + 400;
  v_data := v_data + ((8 - extract(isodow from v_data)::int) % 7);   -- próxima segunda
  while exists (select 1 from public.feriados f where f.data = v_data) loop v_data := v_data + 7; end loop;
  v_fer := v_data + 14;
  while exists (select 1 from public.feriados f where f.data = v_fer) loop v_fer := v_fer + 7; end loop;

  insert into public.quadras (nome, tipo_piso) values ('ZZ QA Quadra', 'dura') returning id into v_q;
  insert into public.quadras (nome, tipo_piso) values ('ZZ QA Quadra 2', 'saibro') returning id into v_q2;
  insert into public.horarios_funcionamento (quadra_id, dia_semana, abertura, fechamento)
  select q, d, '07:00', '22:00' from unnest(array[v_q, v_q2]) q cross join generate_series(0, 6) d;
  insert into public.faixas_preco (quadra_id, tipo_dia, hora_inicio, hora_fim, valor)
  select q, f.tipo_dia, f.ini::time, f.fim::time, f.valor
    from unnest(array[v_q, v_q2]) q
   cross join (values ('util', '07:00', '18:00', 60.00), ('util', '18:00', '22:00', 90.00),
                      ('fim_de_semana', '07:00', '22:00', 100.00)) f(tipo_dia, ini, fim, valor);


  select count(*) filter (where status = 'livre'), min(valor), max(valor), count(*)
    into r from public.horarios_do_dia(v_data) h where h.quadra_id = v_q;
  perform pg_temp.verificar('CT-H1-01 e CT-H9-01 consulta lista os 15 blocos livres de 07h às 22h, de R$ 60 a R$ 90',
    r.count = 15 and r.min = 60 and r.max = 90, format('livres/total=%s, min=%s, max=%s', r.count, r.min, r.max));

  perform pg_temp.verificar('CT-H1-09 a consulta não expõe nome nem telefone de clientes',
    pg_get_function_result('public.horarios_do_dia(date)'::regprocedure) !~* '(nome_cliente|telefone)',
    pg_get_function_result('public.horarios_do_dia(date)'::regprocedure));

  select count(*) into n from public.horarios_do_dia(v_hoje) h
   where h.quadra_id = v_q
     and (v_hoje + h.hora_inicio <= public.agora_local()) <> (h.status = 'passado');
  perform pg_temp.verificar('CT-H1-03 horários de hoje que já passaram aparecem como passado', n = 0, n || ' linhas erradas');

 
  select * into r from public.criar_reserva(v_q, v_data, '10:00', '  Maria   da Silva ', '(31) 99999-0001');
  v_maria := r.id;
  perform pg_temp.verificar('CT-H2-01 reserva válida devolve quadra, data, hora e valor (R$ 60)',
    r.valor = 60 and r.quadra_nome = 'ZZ QA Quadra' and r.data = v_data and r.hora_inicio = '10:00' and not r.feriado,
    row_to_json(r)::text);
  select * into r from public.reservas where id = v_maria;
  perform pg_temp.verificar('CT-H2-01 (dados gravados) nome é limpo, telefone só tem dígitos e a reserva fica confirmada',
    r.nome_cliente = 'Maria da Silva' and r.telefone = '31999990001' and r.status = 'confirmada',
    row_to_json(r)::text);
  perform pg_temp.verificar('CT-H1-04 (Realtime) o horário reservado vira ocupação do tipo reserva',
    exists (select 1 from public.ocupacoes o where o.quadra_id = v_q and o.data = v_data
              and o.hora_inicio = '10:00' and o.tipo = 'reserva'));
  perform pg_temp.verificar('CT-H1-04 o horário reservado aparece como reservado na consulta',
    (select h.status from public.horarios_do_dia(v_data) h where h.quadra_id = v_q and h.hora_inicio = '10:00') = 'reservado');

  select * into r from public.criar_reserva(v_q, v_data, '19:00', 'João Pereira', '31999990002');
  v_noite := r.id;
  perform pg_temp.verificar('CT-H2-09 o valor vem do banco: faixa noturna custa R$ 90', r.valor = 90, r.valor::text);

  perform pg_temp.esperar_erro('CT-H2-03 nome curto é recusado',
    pg_temp.sql_reservar(v_q, v_data, '11:00', 'Al', '31999990003'), 'NOME_INVALIDO');
  perform pg_temp.esperar_erro('CT-H2-02 (sem o 9) telefone sem o dígito 9 é recusado',
    pg_temp.sql_reservar(v_q, v_data, '11:00', 'Ana Souza', '(31) 9999-0003'), 'TELEFONE_INVALIDO');
  perform pg_temp.esperar_erro('CT-H2-02 (sem DDD) telefone sem DDD é recusado',
    pg_temp.sql_reservar(v_q, v_data, '11:00', 'Ana Souza', '99999-0003'), 'TELEFONE_INVALIDO');
  perform pg_temp.esperar_erro('CT-H2-11 horário que já passou é recusado',
    pg_temp.sql_reservar(v_q, v_hoje - 1, '10:00', 'Ana Souza', '31999990003'), 'HORARIO_PASSADO');
  perform pg_temp.esperar_erro('CT-H2-05 horário já reservado por outro cliente é recusado',
    pg_temp.sql_reservar(v_q, v_data, '10:00', 'Outra Pessoa', '31999990004'), 'HORARIO_OCUPADO');
  perform pg_temp.esperar_erro('CT-H2-15 hora quebrada (10:30) é recusada',
    pg_temp.sql_reservar(v_q, v_data, '10:30', 'Ana Souza', '31999990003'), 'HORARIO_INVALIDO');


  perform set_config('request.jwt.claim.role', 'anon', true);
  execute 'set local role anon';
  select * into r from public.criar_reserva(v_q, v_data, '11:00', 'Visitante Sem Login', '31999990005');
  execute 'reset role';
  perform set_config('request.jwt.claim.role', '', true);
  perform pg_temp.verificar('CT-H2-10 visitante sem login (papel anon) consegue reservar', r.id is not null);


  perform pg_temp.esperar_erro('CT-H9-05 não reserva no horário de fechamento (22h é exclusivo)',
    pg_temp.sql_reservar(v_q, v_data, '22:00', 'Ana Souza', '31999990006'), 'FORA_DO_FUNCIONAMENTO');
  perform pg_temp.esperar_erro('CT-H9-07 (abertura) não reserva antes da abertura (06h)',
    pg_temp.sql_reservar(v_q, v_data, '06:00', 'Ana Souza', '31999990006'), 'FORA_DO_FUNCIONAMENTO');
  select * into r from public.criar_reserva(v_q, v_data, '21:00', 'Ana Souza', '31999990006');
  perform pg_temp.verificar('CT-H9-07 (última hora) a última hora (21h) aceita reserva', r.id is not null);
  perform pg_temp.esperar_erro('CT-H9-04 fechamento antes da abertura é recusado',
    format('update public.horarios_funcionamento set fechamento = ''07:00'' where quadra_id = %s and dia_semana = 1', v_q),
    'INTERVALO_INVALIDO');


  insert into public.bloqueios (quadra_id, data, hora_inicio, motivo) values (v_q, v_data, '16:00', 'Manutenção');
  perform pg_temp.verificar('CT-H5-01 horário bloqueado some da lista de livres',
    (select h.status from public.horarios_do_dia(v_data) h where h.quadra_id = v_q and h.hora_inicio = '16:00') = 'bloqueado');
  perform pg_temp.esperar_erro('CT-H5-02 cliente não reserva horário bloqueado',
    pg_temp.sql_reservar(v_q, v_data, '16:00', 'Ana Souza', '31999990007'), 'HORARIO_BLOQUEADO');
  delete from public.bloqueios where quadra_id = v_q and data = v_data and hora_inicio = '16:00';
  perform pg_temp.verificar('CT-H5-03 desbloquear libera o horário',
    (select h.status from public.horarios_do_dia(v_data) h where h.quadra_id = v_q and h.hora_inicio = '16:00') = 'livre');
  perform pg_temp.esperar_erro('CT-H5-04 não bloqueia horário que já tem reserva',
    format('insert into public.bloqueios (quadra_id, data, hora_inicio) values (%s, %L, ''10:00'')', v_q, v_data),
    'HORARIO_RESERVADO');
  perform pg_temp.esperar_erro('CT-H5-05 não bloqueia horário que já passou',
    format('insert into public.bloqueios (quadra_id, data, hora_inicio) values (%s, %L, ''07:00'')', v_q, v_hoje - 1),
    'HORARIO_PASSADO');


  select * into r from public.criar_reserva(v_q, v_data, '12:00', 'Carla Dias', '31999990010');
  v_c1 := r.id;
  select * into r from public.criar_reserva(v_q, v_data, '13:00', 'Carla Dias', '31999990010');
  v_c2 := r.id;
  perform pg_temp.verificar('CT-H10-01 a 1ª e a 2ª reserva do dia são aceitas', v_c1 is not null and v_c2 is not null);
  perform pg_temp.esperar_erro('CT-H10-02 e CT-H10-05 a 3ª reserva no mesmo dia é recusada, mesmo com o telefone escrito com máscara',
    pg_temp.sql_reservar(v_q, v_data, '14:00', 'Carla Dias', '(31) 99999-0010'), 'LIMITE_DIARIO');
  select * into r from public.criar_reserva(v_q, v_data + 7, '12:00', 'Carla Dias', '31999990010');
  perform pg_temp.verificar('CT-H10-03 o limite vale por dia: no dia seguinte da semana seguinte pode reservar', r.id is not null);

  perform pg_temp.esperar_erro('CT-H3-10 quem não é o proprietário não cancela',
    format('select public.cancelar_reserva(%s)', v_c2), 'NAO_AUTORIZADO');
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  select * into r from public.cancelar_reserva(v_c2, 'Cliente avisou que não vem');
  perform pg_temp.verificar('CT-H3-01 (exclusão lógica) cancelar faz exclusão lógica (status cancelada, linha continua)',
    r.status = 'cancelada' and exists (select 1 from public.reservas where id = v_c2));
  perform pg_temp.verificar('CT-H3-09 o cancelamento fica registrado no log com o motivo',
    (select motivo from public.log_cancelamentos where reserva_id = v_c2) = 'Cliente avisou que não vem');
  perform pg_temp.verificar('CT-H3-01 (horário livre) o horário cancelado volta a ficar livre',
    (select h.status from public.horarios_do_dia(v_data) h where h.quadra_id = v_q and h.hora_inicio = '13:00') = 'livre');
  perform pg_temp.esperar_erro('CT-H3-07 cancelar de novo é recusado',
    format('select public.cancelar_reserva(%s)', v_c2), 'RESERVA_JA_CANCELADA');
  perform pg_temp.esperar_erro('CT-H3-11 reserva inexistente é recusada',
    'select public.cancelar_reserva(-1)', 'RESERVA_NAO_ENCONTRADA');
  insert into public.reservas (quadra_id, data, hora_inicio, nome_cliente, telefone, valor)
  values (v_q, v_hoje - 1, '10:00', 'Passado Teste', '31999990099', 60) returning id into v_passada;
  perform pg_temp.esperar_erro('CT-H3-03 reserva que já terminou não pode ser cancelada',
    format('select public.cancelar_reserva(%s)', v_passada), 'RESERVA_PASSADA');
  perform set_config('request.jwt.claim.role', '', true);

  select * into r from public.criar_reserva(v_q, v_data, '14:00', 'Carla Dias', '31999990010');
  perform pg_temp.verificar('CT-H10-04 reserva cancelada não conta no limite: a 3ª passa a ser aceita', r.id is not null);


  perform pg_temp.esperar_erro('CT-H8-03 nome de quadra repetido é recusado (sem diferenciar maiúsculas)',
    'insert into public.quadras (nome, tipo_piso) values (''  zz qa QUADRA '', ''dura'')', 'QUADRA_NOME_DUPLICADO');
  perform pg_temp.esperar_erro('CT-H8-05 não inativa quadra com reserva futura',
    format('update public.quadras set ativa = false where id = %s', v_q), 'QUADRA_COM_RESERVAS');
  update public.quadras set ativa = false where id = v_q2;
  perform pg_temp.verificar('CT-H8-04 quadra sem reservas pode ser inativada', not (select ativa from public.quadras where id = v_q2));
  perform pg_temp.verificar('CT-H1-05 quadra inativa não aparece na consulta',
    not exists (select 1 from public.horarios_do_dia(v_data) h where h.quadra_id = v_q2));
  perform pg_temp.esperar_erro('CT-H8-06 não reserva em quadra inativa',
    pg_temp.sql_reservar(v_q2, v_data, '10:00', 'Ana Souza', '31999990008'), 'QUADRA_INDISPONIVEL');


  delete from public.horarios_funcionamento where quadra_id = v_q and dia_semana = extract(dow from (v_data + 1))::int;
  perform pg_temp.verificar('CT-H9-06 (consulta) dia sem funcionamento não tem horários na consulta',
    not exists (select 1 from public.horarios_do_dia(v_data + 1) h where h.quadra_id = v_q));
  perform pg_temp.esperar_erro('CT-H9-06 (reserva) não reserva em dia em que a quadra está fechada',
    pg_temp.sql_reservar(v_q, v_data + 1, '10:00', 'Ana Souza', '31999990008'), 'FORA_DO_FUNCIONAMENTO');


  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform pg_temp.verificar('CT-H11-08 a consulta do proprietário traz o motivo do cancelamento',
    (select motivo_cancelamento from public.vw_reservas where id = v_c2) = 'Cliente avisou que não vem');

  select count(*) filter (where status = 'confirmada') as qtd,
         coalesce(sum(valor) filter (where status = 'confirmada'), 0) as conf,
         coalesce(sum(valor), 0) as todas,
         count(*) filter (where status = 'cancelada') as canc
    into t from public.reservas where data = v_data;
  select * into r from public.resumo_faturamento(v_data, v_data);
  perform pg_temp.verificar('CT-H12-01 o relatório conta as locações confirmadas e soma o faturamento',
    r.qtd_locacoes = t.qtd and r.faturamento = t.conf, format('relatório=%s/%s, tabela=%s/%s', r.qtd_locacoes, r.faturamento, t.qtd, t.conf));
  perform pg_temp.verificar('CT-H12-02 reservas canceladas não entram no faturamento',
    t.canc >= 1 and t.todas > t.conf and r.faturamento = t.conf and r.qtd_canceladas = t.canc,
    format('canceladas=%s, todas=%s, confirmadas=%s', t.canc, t.todas, t.conf));
  select * into r from public.resumo_faturamento(v_data, v_data, '(31) 99999-0001');
  perform pg_temp.verificar('CT-H12-03 o relatório filtra por telefone (com ou sem máscara)',
    r.qtd_locacoes = 1 and r.faturamento = 60, format('qtd=%s, valor=%s', r.qtd_locacoes, r.faturamento));
  perform pg_temp.esperar_erro('CT-H12-05 período com início depois do fim é recusado',
    format('select * from public.resumo_faturamento(%L, %L)', v_data, v_data - 1), 'PERIODO_INVALIDO');
  perform set_config('request.jwt.claim.role', '', true);
  perform pg_temp.esperar_erro('CT-H12-08 quem não é o proprietário não vê o relatório',
    format('select * from public.resumo_faturamento(%L, %L)', v_data, v_data), 'NAO_AUTORIZADO');


  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform pg_temp.esperar_erro('CT-H4-02 faixas que se sobrepõem (08h-18h e 17h-22h) não são salvas',
    format('select * from public.salvar_faixas_preco(%s, ''util'', %L::jsonb)', v_q,
      '[{"hora_inicio":"08:00","hora_fim":"18:00","valor":60},{"hora_inicio":"17:00","hora_fim":"22:00","valor":90}]'),
    'FAIXA_SOBREPOSTA');
  perform pg_temp.esperar_erro('CT-H4-03 horário de funcionamento sem preço (lacuna) não é salvo',
    format('select * from public.salvar_faixas_preco(%s, ''util'', %L::jsonb)', v_q,
      '[{"hora_inicio":"08:00","hora_fim":"18:00","valor":60}]'),
    'FAIXA_LACUNA');
  perform set_config('request.jwt.claim.role', '', true);
  perform pg_temp.esperar_erro('CT-H4-11 quem não é o proprietário não altera preços',
    format('select * from public.salvar_faixas_preco(%s, ''util'', %L::jsonb)', v_q,
      '[{"hora_inicio":"07:00","hora_fim":"22:00","valor":70}]'),
    'NAO_AUTORIZADO');

  insert into public.feriados (data, descricao) values (v_fer, 'Feriado de teste (QA)');
  select * into r from public.criar_reserva(v_q, v_fer, '10:00', 'Rita Feriado', '31999990020');
  perform pg_temp.verificar('CT-H4-09 feriado em dia útil usa a tabela de fim de semana (R$ 100) e marca a reserva',
    r.valor = 100 and r.feriado, row_to_json(r)::text);

  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.salvar_faixas_preco(v_q, 'util', '[{"hora_inicio":"07:00","hora_fim":"22:00","valor":70}]'::jsonb);
  perform set_config('request.jwt.claim.role', '', true);
  perform pg_temp.verificar('CT-H4-10 (valor gravado) mudar o preço não altera o valor já gravado na reserva (R$ 60 continua R$ 60)',
    (select valor from public.reservas where id = v_maria) = 60);
  select * into r from public.criar_reserva(v_q, v_data, '15:00', 'Paula Nova', '31999990021');
  perform pg_temp.verificar('CT-H4-10 (preço novo) a reserva nova já usa o preço novo (R$ 70)', r.valor = 70, r.valor::text);


  begin
    execute 'set local role anon';
    select count(*) into n from public.reservas;
    execute 'reset role';
  exception when insufficient_privilege then
    n := 0;
  end;
  perform pg_temp.verificar('CT-RNF04-01 visitante anônimo não lê nenhuma reserva (nem nome, nem telefone)', n = 0, n || ' linhas visíveis');
end;
$$;

rollback;

select 'TODOS OS CASOS PASSARAM' as resultado;
