-- =============================================================================
-- Schema inicial do sistema de agendamento de quadras de tênis (atividade 2.2)
--
-- Convenções (contrato com o front-end):
--   * Nomes em português, snake_case, sem acento.
--   * Datas em DATE e horários em TIME, sempre no fuso America/Sao_Paulo (RNF15).
--     Cada reserva/bloqueio ocupa 1 hora começando em hora cheia (07:00, 08:00...).
--   * Telefone gravado só com dígitos, DDD + 9 dígitos: '31999990000' (RF05).
--   * Valores em NUMERIC(10,2), em reais (RNF07).
--   * Erros de regra de negócio: SQLSTATE P0001, "message" em pt-BR pronta para
--     exibir e "hint" com um código estável (ex.: LIMITE_DIARIO) para o app
--     decidir o que fazer. Lista completa no fim do arquivo.
--   * Área pública (anon) só lê quadras ativas, funcionamento, preços e feriados,
--     e chama horarios_do_dia() e criar_reserva(). Nunca lê nome/telefone.
--   * Área administrativa = usuário autenticado (único proprietário; cadastro
--     público desabilitado no Supabase Auth).
-- =============================================================================

-- ---------------------------------------------------------------- utilitários

-- Lança erro de negócio no formato do contrato.
create function public.erro(p_codigo text, p_mensagem text)
returns void
language plpgsql
as $$
begin
  raise exception using errcode = 'P0001', message = p_mensagem, hint = p_codigo;
end;
$$;

-- Data/hora atual no fuso do negócio, independente do fuso do servidor.
create function public.agora_local()
returns timestamp
language sql
stable
as $$ select (now() at time zone 'America/Sao_Paulo') $$;

create function public.e_proprietario()
returns boolean
language sql
stable
as $$ select coalesce(auth.role() = 'authenticated', false) $$;

create function public.exigir_proprietario()
returns void
language plpgsql
stable
as $$
begin
  if not public.e_proprietario() then
    perform public.erro('NAO_AUTORIZADO', 'Acesso restrito ao proprietário.');
  end if;
end;
$$;

-- ---------------------------------------------------------------- tabelas

-- H8 / RF12
create table public.quadras (
  id         bigint generated always as identity primary key,
  nome       text        not null check (length(trim(nome)) between 1 and 60),
  tipo_piso  text        not null check (tipo_piso in ('saibro', 'dura', 'grama', 'sintetica')),
  descricao  text,
  ativa      boolean     not null default true,
  criada_em  timestamptz not null default now()
);
create unique index quadras_nome_unico on public.quadras (lower(trim(nome)));

-- H9 / RF13. Um intervalo por quadra e dia da semana (0 = domingo ... 6 = sábado,
-- mesmo padrão de extract(dow)). Dia sem linha = quadra fechada nesse dia.
create table public.horarios_funcionamento (
  quadra_id   bigint   not null references public.quadras (id) on delete cascade,
  dia_semana  smallint not null check (dia_semana between 0 and 6),
  abertura    time     not null check (date_trunc('hour', abertura) = abertura),
  fechamento  time     not null check (date_trunc('hour', fechamento) = fechamento),
  primary key (quadra_id, dia_semana),
  check (fechamento > abertura)
);

-- H4 / RF18-RF19. Tabela única de preços para todas as quadras.
-- 'util' = segunda a sexta; 'fim_de_semana' = sábado, domingo e feriados (RF21).
-- Escrita somente pela função salvar_faixas_preco(), que valida sobreposição e lacunas.
create table public.faixas_preco (
  id           bigint generated always as identity primary key,
  tipo_dia     text          not null check (tipo_dia in ('util', 'fim_de_semana')),
  hora_inicio  time          not null check (date_trunc('hour', hora_inicio) = hora_inicio),
  hora_fim     time          not null check (date_trunc('hour', hora_fim) = hora_fim),
  valor        numeric(10,2) not null check (valor > 0),
  check (hora_fim > hora_inicio)
);

-- H4 / RF21
create table public.feriados (
  data       date primary key,
  descricao  text not null check (length(trim(descricao)) > 0)
);

-- H5 / RF17. Excluir a linha = desbloquear.
create table public.bloqueios (
  id           bigint generated always as identity primary key,
  quadra_id    bigint      not null references public.quadras (id),
  data         date        not null,
  hora_inicio  time        not null check (date_trunc('hour', hora_inicio) = hora_inicio),
  motivo       text,
  criado_em    timestamptz not null default now(),
  unique (quadra_id, data, hora_inicio)
);

-- H2 / RF04-RF08, RF20. Criada só por criar_reserva(); cancelada só por cancelar_reserva().
create table public.reservas (
  id            bigint generated always as identity primary key,
  quadra_id     bigint        not null references public.quadras (id),
  data          date          not null,
  hora_inicio   time          not null check (date_trunc('hour', hora_inicio) = hora_inicio),
  nome_cliente  text          not null,
  telefone      text          check (telefone ~ '^[1-9]{2}9[0-9]{8}$'),  -- null após anonimização
  valor         numeric(10,2) not null check (valor >= 0),                 -- congelado (RNF07)
  feriado       boolean       not null default false,                     -- relatório H12
  status        text          not null default 'confirmada'
                              check (status in ('confirmada', 'cancelada')),
  criada_em     timestamptz   not null default now(),
  anonimizada   boolean       not null default false
);
-- RF06 / RNF03: nunca duas reservas ativas no mesmo horário, mesmo com concorrência.
create unique index reservas_horario_unico
  on public.reservas (quadra_id, data, hora_inicio)
  where status = 'confirmada';
create index reservas_data_idx     on public.reservas (data);
create index reservas_telefone_idx on public.reservas (telefone, data);

-- H3 / RF16 / RNF06
create table public.log_cancelamentos (
  id             bigint generated always as identity primary key,
  reserva_id     bigint      not null references public.reservas (id),
  cancelado_por  uuid        references auth.users (id) on delete set null,
  cancelado_em   timestamptz not null default now(),
  motivo         text
);
create index log_cancelamentos_reserva_idx on public.log_cancelamentos (reserva_id);

-- ---------------------------------------------------------------- regras em gatilhos

-- H8 Alt1 (nome duplicado) e Alt2 (inativar com reservas futuras).
create function public.validar_quadra()
returns trigger
language plpgsql
as $$
declare
  v_futuras int;
begin
  if exists (select 1 from public.quadras q
             where lower(trim(q.nome)) = lower(trim(new.nome))
               and q.id is distinct from new.id) then
    perform public.erro('QUADRA_NOME_DUPLICADO', 'Já existe uma quadra com este nome.');
  end if;

  if tg_op = 'UPDATE' and old.ativa and not new.ativa then
    select count(*) into v_futuras
      from public.reservas r
     where r.quadra_id = new.id
       and r.status = 'confirmada'
       and r.data + r.hora_inicio + interval '1 hour' > public.agora_local();
    if v_futuras > 0 then
      perform public.erro('QUADRA_COM_RESERVAS',
        case when v_futuras = 1
             then 'Existe 1 reserva futura nesta quadra. Cancele-a antes de inativar.'
             else format('Existem %s reservas futuras nesta quadra. Cancele-as antes de inativar.', v_futuras)
        end);
    end if;
  end if;
  return new;
end;
$$;
create trigger quadras_validar before insert or update on public.quadras
  for each row execute function public.validar_quadra();

create function public.validar_funcionamento()
returns trigger
language plpgsql
as $$
begin
  if new.fechamento <= new.abertura then
    perform public.erro('INTERVALO_INVALIDO', 'O horário de fechamento deve ser depois da abertura.');
  end if;
  return new;
end;
$$;
create trigger horarios_funcionamento_validar before insert or update on public.horarios_funcionamento
  for each row execute function public.validar_funcionamento();

-- H5 Alt1 (horário já reservado) e bloqueio de horário passado.
create function public.validar_bloqueio()
returns trigger
language plpgsql
as $$
begin
  if new.data + new.hora_inicio + interval '1 hour' <= public.agora_local() then
    perform public.erro('HORARIO_PASSADO', 'Não é possível bloquear um horário que já passou.');
  end if;
  if exists (select 1 from public.reservas r
             where r.quadra_id = new.quadra_id and r.data = new.data
               and r.hora_inicio = new.hora_inicio and r.status = 'confirmada') then
    perform public.erro('HORARIO_RESERVADO',
      'Existe um agendamento neste horário. Cancele a reserva do cliente antes de realizar o bloqueio.');
  end if;
  return new;
end;
$$;
create trigger bloqueios_validar before insert or update on public.bloqueios
  for each row execute function public.validar_bloqueio();

-- ---------------------------------------------------------------- preço

create function public.tipo_dia(p_data date)
returns text
language sql
stable
as $$
  select case
    when extract(dow from p_data) in (0, 6)
      or exists (select 1 from public.feriados f where f.data = p_data) then 'fim_de_semana'
    else 'util'
  end
$$;

-- Valor de 1 hora começando em p_hora na data p_data; null se não houver faixa.
create function public.preco_horario(p_data date, p_hora time)
returns numeric
language sql
stable
as $$
  select fp.valor
    from public.faixas_preco fp
   where fp.tipo_dia = public.tipo_dia(p_data)
     and p_hora >= fp.hora_inicio
     and p_hora <  fp.hora_fim
$$;

-- H4 / RF19. Substitui todas as faixas de um tipo de dia de uma vez.
-- p_faixas: [{"hora_inicio": "08:00", "hora_fim": "18:00", "valor": 60}, ...]
create function public.salvar_faixas_preco(p_tipo_dia text, p_faixas jsonb)
returns setof public.faixas_preco
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conflito record;
  v_lacuna   record;
begin
  perform public.exigir_proprietario();
  if p_tipo_dia not in ('util', 'fim_de_semana') then
    perform public.erro('TIPO_DIA_INVALIDO', 'Tipo de dia inválido.');
  end if;

  create temp table novas on commit drop as
    select (f ->> 'hora_inicio')::time          as hora_inicio,
           (f ->> 'hora_fim')::time             as hora_fim,
           (f ->> 'valor')::numeric(10,2)       as valor
      from jsonb_array_elements(p_faixas) f;

  if exists (select 1 from novas where hora_fim <= hora_inicio) then
    perform public.erro('INTERVALO_INVALIDO', 'Em cada faixa o horário final deve ser depois do inicial.');
  end if;

  select a.hora_inicio as a_ini, a.hora_fim as a_fim, b.hora_inicio as b_ini, b.hora_fim as b_fim
    into v_conflito
    from novas a join novas b
      on a.ctid < b.ctid and a.hora_inicio < b.hora_fim and b.hora_inicio < a.hora_fim
   limit 1;
  if found then
    perform public.erro('FAIXA_SOBREPOSTA', format('As faixas %s–%s e %s–%s se sobrepõem.',
      to_char(v_conflito.a_ini, 'HH24"h"'), to_char(v_conflito.a_fim, 'HH24"h"'),
      to_char(v_conflito.b_ini, 'HH24"h"'), to_char(v_conflito.b_fim, 'HH24"h"')));
  end if;

  -- Toda hora de funcionamento das quadras ativas nesses dias precisa de preço.
  -- Feriado pode cair em dia útil e usa a tabela de fim de semana, então essa
  -- tabela precisa cobrir o funcionamento de todos os dias.
  select q.nome, h.hora
    into v_lacuna
    from public.quadras q
    join public.horarios_funcionamento hf on hf.quadra_id = q.id
    cross join lateral (select make_time(g, 0, 0) as hora
                          from generate_series(extract(hour from hf.abertura)::int,
                                               extract(hour from hf.fechamento)::int - 1) g) h
   where q.ativa
     and (p_tipo_dia = 'fim_de_semana' or hf.dia_semana between 1 and 5)
     and not exists (select 1 from novas n where h.hora >= n.hora_inicio and h.hora < n.hora_fim)
   order by h.hora
   limit 1;
  if found then
    perform public.erro('FAIXA_LACUNA', format('O horário das %s da quadra %s ficou sem preço.',
      to_char(v_lacuna.hora, 'HH24"h"'), v_lacuna.nome));
  end if;

  delete from public.faixas_preco where tipo_dia = p_tipo_dia;
  return query
    insert into public.faixas_preco (tipo_dia, hora_inicio, hora_fim, valor)
    select p_tipo_dia, hora_inicio, hora_fim, valor from novas order by hora_inicio
    returning *;
end;
$$;

-- ---------------------------------------------------------------- consulta pública

-- H1 / RF01-RF03. Todos os blocos de 1 hora das quadras ativas em p_data.
-- status: 'livre' | 'reservado' | 'bloqueado' | 'passado' | 'sem_preco'.
-- Só 'livre' pode ser reservado. Não expõe dados de clientes.
create function public.horarios_do_dia(p_data date)
returns table (
  quadra_id    bigint,
  quadra_nome  text,
  tipo_piso    text,
  hora_inicio  time,
  valor        numeric,
  status       text
)
language sql
stable
security definer
set search_path = public
as $$
  select q.id, q.nome, q.tipo_piso, h.hora,
         public.preco_horario(p_data, h.hora),
         case
           when p_data + h.hora <= public.agora_local() then 'passado'
           when exists (select 1 from public.reservas r
                        where r.quadra_id = q.id and r.data = p_data
                          and r.hora_inicio = h.hora and r.status = 'confirmada') then 'reservado'
           when exists (select 1 from public.bloqueios b
                        where b.quadra_id = q.id and b.data = p_data
                          and b.hora_inicio = h.hora) then 'bloqueado'
           when public.preco_horario(p_data, h.hora) is null then 'sem_preco'
           else 'livre'
         end
    from public.quadras q
    join public.horarios_funcionamento hf
      on hf.quadra_id = q.id and hf.dia_semana = extract(dow from p_data)
    cross join lateral (select make_time(g, 0, 0) as hora
                          from generate_series(extract(hour from hf.abertura)::int,
                                               extract(hour from hf.fechamento)::int - 1) g) h
   where q.ativa
   order by q.nome, h.hora
$$;

-- ---------------------------------------------------------------- reserva

-- H2, H10 / RF04-RF08, RF20. Tudo numa transação; o valor vem do banco, nunca do app.
create function public.criar_reserva(
  p_quadra_id    bigint,
  p_data         date,
  p_hora_inicio  time,
  p_nome         text,
  p_telefone     text
)
returns table (
  id           bigint,
  quadra_nome  text,
  data         date,
  hora_inicio  time,
  valor        numeric,
  feriado      boolean
)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_nome      text := regexp_replace(trim(coalesce(p_nome, '')), '\s+', ' ', 'g');
  v_telefone  text := regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g');
  v_quadra    public.quadras;
  v_valor     numeric;
  v_qtd       int;
  v_id        bigint;
begin
  if length(v_nome) < 3 then
    perform public.erro('NOME_INVALIDO', 'Informe o nome completo.');
  end if;
  if v_telefone !~ '^[1-9]{2}9[0-9]{8}$' then
    perform public.erro('TELEFONE_INVALIDO', 'Informe o telefone no formato (DD) 9XXXX-XXXX.');
  end if;
  if p_hora_inicio is null or date_trunc('hour', p_hora_inicio) <> p_hora_inicio then
    perform public.erro('HORARIO_INVALIDO', 'Horário inválido.');
  end if;
  if p_data is null or p_data + p_hora_inicio <= public.agora_local() then
    perform public.erro('HORARIO_PASSADO', 'Este horário já passou. Escolha outro.');
  end if;

  select * into v_quadra from public.quadras q where q.id = p_quadra_id;
  if not found or not v_quadra.ativa then
    perform public.erro('QUADRA_INDISPONIVEL', 'Esta quadra não está disponível para reservas.');
  end if;

  if not exists (select 1 from public.horarios_funcionamento hf
                 where hf.quadra_id = p_quadra_id
                   and hf.dia_semana = extract(dow from p_data)
                   and p_hora_inicio >= hf.abertura
                   and p_hora_inicio <  hf.fechamento) then
    perform public.erro('FORA_DO_FUNCIONAMENTO', 'A quadra não funciona neste horário.');
  end if;

  if exists (select 1 from public.bloqueios b
             where b.quadra_id = p_quadra_id and b.data = p_data and b.hora_inicio = p_hora_inicio) then
    perform public.erro('HORARIO_BLOQUEADO', 'Este horário está bloqueado para manutenção.');
  end if;

  v_valor := public.preco_horario(p_data, p_hora_inicio);
  if v_valor is null then
    perform public.erro('SEM_PRECO', 'Este horário ainda não tem preço definido.');
  end if;

  -- Serializa reservas do mesmo telefone no mesmo dia para o limite valer sob concorrência.
  perform pg_advisory_xact_lock(hashtext(v_telefone || '|' || p_data::text));
  select count(*) into v_qtd
    from public.reservas r
   where r.telefone = v_telefone and r.data = p_data and r.status = 'confirmada';
  if v_qtd >= 2 then
    perform public.erro('LIMITE_DIARIO', 'Limite de 2 horários por dia atingido para este telefone.');
  end if;

  begin
    insert into public.reservas (quadra_id, data, hora_inicio, nome_cliente, telefone, valor, feriado)
    values (p_quadra_id, p_data, p_hora_inicio, v_nome, v_telefone, v_valor,
            exists (select 1 from public.feriados f where f.data = p_data))
    returning reservas.id into v_id;
  exception when unique_violation then
    perform public.erro('HORARIO_OCUPADO', 'Este horário acabou de ser reservado.');
  end;

  return query
    select r.id, v_quadra.nome, r.data, r.hora_inicio, r.valor, r.feriado
      from public.reservas r where r.id = v_id;
end;
$$;

-- H3 / RF15-RF16. Reserva futura ou em andamento.
create function public.cancelar_reserva(p_reserva_id bigint, p_motivo text default null)
returns public.reservas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reserva public.reservas;
begin
  perform public.exigir_proprietario();

  select * into v_reserva from public.reservas r where r.id = p_reserva_id for update;
  if not found then
    perform public.erro('RESERVA_NAO_ENCONTRADA', 'Reserva não encontrada.');
  end if;
  if v_reserva.status = 'cancelada' then
    perform public.erro('RESERVA_JA_CANCELADA', 'Esta reserva já está cancelada.');
  end if;
  if v_reserva.data + v_reserva.hora_inicio + interval '1 hour' <= public.agora_local() then
    perform public.erro('RESERVA_PASSADA', 'Não é possível cancelar uma reserva que já terminou.');
  end if;

  update public.reservas set status = 'cancelada' where id = p_reserva_id
  returning * into v_reserva;
  insert into public.log_cancelamentos (reserva_id, cancelado_por, motivo)
  values (p_reserva_id, auth.uid(), nullif(trim(p_motivo), ''));
  return v_reserva;
end;
$$;

-- ---------------------------------------------------------------- área administrativa

-- H11 / RF14 e listagem do relatório H12. Usa o RLS de reservas (security_invoker).
create view public.vw_reservas
with (security_invoker = true)
as
select r.id, r.quadra_id, q.nome as quadra_nome, r.data, r.hora_inicio,
       r.nome_cliente, r.telefone, r.valor, r.feriado, r.status, r.criada_em,
       lc.cancelado_em, lc.motivo as motivo_cancelamento
  from public.reservas r
  join public.quadras q on q.id = r.quadra_id
  left join public.log_cancelamentos lc on lc.reserva_id = r.id;

-- H12 / RF22-RF23. Canceladas não entram no faturamento.
create function public.resumo_faturamento(p_inicio date, p_fim date, p_telefone text default null)
returns table (qtd_locacoes bigint, faturamento numeric, qtd_canceladas bigint)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tel text := nullif(regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g'), '');
begin
  perform public.exigir_proprietario();
  if p_inicio is null or p_fim is null or p_inicio > p_fim then
    perform public.erro('PERIODO_INVALIDO', 'A data inicial deve ser anterior ou igual à final.');
  end if;
  return query
    select count(*) filter (where r.status = 'confirmada'),
           coalesce(sum(r.valor) filter (where r.status = 'confirmada'), 0)::numeric,
           count(*) filter (where r.status = 'cancelada')
      from public.reservas r
     where r.data between p_inicio and p_fim
       and (v_tel is null or r.telefone = v_tel);
end;
$$;

-- ---------------------------------------------------------------- LGPD (RNF04)

-- Anonimiza reservas com mais de 12 meses. Agendada diariamente via pg_cron.
create function public.anonimizar_reservas_antigas()
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
    returning 1
  )
  select count(*)::int from a
$$;

do $$
begin
  create extension if not exists pg_cron;
  perform cron.schedule('anonimizar-reservas', '0 3 * * *',
                        'select public.anonimizar_reservas_antigas()');
exception when others then
  raise notice 'pg_cron indisponível; agende anonimizar_reservas_antigas() manualmente: %', sqlerrm;
end;
$$;

-- Realtime para o painel do proprietário (RNF08). Respeita o RLS: anon não recebe nada.
do $$
begin
  alter publication supabase_realtime add table public.reservas, public.bloqueios;
exception when undefined_object then
  raise notice 'publicação supabase_realtime não existe (fora do Supabase)';
end;
$$;

-- ---------------------------------------------------------------- RLS e permissões

alter table public.quadras                enable row level security;
alter table public.horarios_funcionamento enable row level security;
alter table public.faixas_preco           enable row level security;
alter table public.feriados               enable row level security;
alter table public.bloqueios              enable row level security;
alter table public.reservas               enable row level security;
alter table public.log_cancelamentos      enable row level security;

-- Leitura pública do que a tela de consulta precisa.
create policy "publico le quadras ativas" on public.quadras
  for select to anon using (ativa);
create policy "publico le funcionamento" on public.horarios_funcionamento
  for select to anon using (true);
create policy "publico le precos" on public.faixas_preco
  for select to anon using (true);
create policy "publico le feriados" on public.feriados
  for select to anon using (true);

-- Proprietário: gestão completa do cadastro e da agenda.
create policy "proprietario gerencia quadras" on public.quadras
  for all to authenticated using (true) with check (true);
create policy "proprietario gerencia funcionamento" on public.horarios_funcionamento
  for all to authenticated using (true) with check (true);
create policy "proprietario le precos" on public.faixas_preco
  for select to authenticated using (true);
create policy "proprietario gerencia feriados" on public.feriados
  for all to authenticated using (true) with check (true);
create policy "proprietario gerencia bloqueios" on public.bloqueios
  for all to authenticated using (true) with check (true);
create policy "proprietario le reservas" on public.reservas
  for select to authenticated using (true);
create policy "proprietario le cancelamentos" on public.log_cancelamentos
  for select to authenticated using (true);

-- Reservas, cancelamentos e preços só mudam pelas funções acima.
revoke insert, update, delete on public.reservas, public.log_cancelamentos, public.faixas_preco
  from anon, authenticated;
-- Quadras nunca são excluídas (histórico e relatórios); usa-se ativa = false.
revoke delete on public.quadras from anon, authenticated;

-- O Supabase concede EXECUTE a anon por padrão; liberar só o necessário.
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.horarios_do_dia(date)                          to anon, authenticated;
grant execute on function public.criar_reserva(bigint, date, time, text, text)  to anon, authenticated;
grant execute on function public.cancelar_reserva(bigint, text)                 to authenticated;
grant execute on function public.salvar_faixas_preco(text, jsonb)               to authenticated;
grant execute on function public.resumo_faturamento(date, date, text)           to authenticated;
grant execute on function public.preco_horario(date, time)                      to anon, authenticated;
grant execute on function public.tipo_dia(date)                                 to anon, authenticated;
-- Usadas por gatilhos e políticas executados com o papel do usuário.
grant execute on function public.erro(text, text), public.agora_local(),
                          public.e_proprietario(), public.exigir_proprietario(),
                          public.validar_quadra(), public.validar_funcionamento(),
                          public.validar_bloqueio()
  to anon, authenticated;

-- =============================================================================
-- Códigos de erro (campo "hint" da PostgrestException):
--   NAO_AUTORIZADO, NOME_INVALIDO, TELEFONE_INVALIDO, HORARIO_INVALIDO,
--   HORARIO_PASSADO, QUADRA_INDISPONIVEL, FORA_DO_FUNCIONAMENTO, HORARIO_BLOQUEADO,
--   SEM_PRECO, LIMITE_DIARIO, HORARIO_OCUPADO, RESERVA_NAO_ENCONTRADA,
--   RESERVA_JA_CANCELADA, RESERVA_PASSADA, QUADRA_NOME_DUPLICADO,
--   QUADRA_COM_RESERVAS, INTERVALO_INVALIDO, HORARIO_RESERVADO, TIPO_DIA_INVALIDO,
--   FAIXA_SOBREPOSTA, FAIXA_LACUNA, PERIODO_INVALIDO
-- =============================================================================
