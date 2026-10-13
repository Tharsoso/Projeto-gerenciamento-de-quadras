-- Dados de exemplo para desenvolvimento (exemplos das histórias H4 e H9).
-- Rodar com o papel postgres/service_role: faixas_preco não aceita escrita direta do app.

insert into public.quadras (nome, tipo_piso, descricao) values
  ('Saibro 1', 'saibro', 'Quadra coberta'),
  ('Saibro 2', 'saibro', null),
  ('Rápida 1', 'dura',   'Piso de concreto com resina');

-- Segunda a sexta 07h–22h; sábado e domingo 08h–18h.
insert into public.horarios_funcionamento (quadra_id, dia_semana, abertura, fechamento)
select q.id, d, case when d in (0, 6) then '08:00'::time else '07:00'::time end,
               case when d in (0, 6) then '18:00'::time else '22:00'::time end
  from public.quadras q cross join generate_series(0, 6) d;

-- Mesma tabela nas três quadras (exemplo da H4); fim de semana cobre 07h–22h por causa
-- dos feriados em dia útil.
insert into public.faixas_preco (quadra_id, tipo_dia, hora_inicio, hora_fim, valor)
select q.id, f.tipo_dia, f.hora_inicio::time, f.hora_fim::time, f.valor
  from public.quadras q
 cross join (values ('util',          '07:00', '18:00',  60.00),
                    ('util',          '18:00', '22:00',  90.00),
                    ('fim_de_semana', '07:00', '22:00', 100.00)) f(tipo_dia, hora_inicio, hora_fim, valor);

insert into public.feriados (data, descricao) values
  ('2026-10-12', 'Nossa Senhora Aparecida'),
  ('2026-11-02', 'Finados'),
  ('2026-11-15', 'Proclamação da República'),
  ('2026-11-20', 'Dia da Consciência Negra'),
  ('2026-12-25', 'Natal');
