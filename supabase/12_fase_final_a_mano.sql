-- =====================================================================
-- 12 · Fase final a mano.
-- Ejecutar después de 11. Se puede ejecutar más de una vez.
--
-- Crea las semifinales, el 3er puesto y la final SIN equipos, para
-- rellenarlos a mano desde Panel → Partidos y resultados («Cambiar equipos»).
-- (Cambiar los equipos de cualquier partido de fase final ya se puede hacer
-- siempre, también si la fase final se generó sola.)
-- =====================================================================

create or replace function public.crear_fase_final_vacia(
  p_liga uuid, p_inicio timestamptz, p_sede uuid, p_minutos int default 30, p_campos int default 2)
returns void
language plpgsql security definer set search_path = public as $$
declare
  h1 record; h2 record; h3 record; h4 record;
  dur interval := make_interval(mins => p_minutos);
begin
  if not tengo_rol('admin') then raise exception 'Solo administración puede crear la fase final'; end if;
  if exists (select 1 from partidos where liga_id = p_liga and fase <> 'liga')
     or exists (select 1 from ligas where id = p_liga and final_en is not null) then
    raise exception 'Esta liga ya tiene fase final. Bórrala antes.';
  end if;

  select * into h1 from hueco_libre(p_sede, p_campos, p_inicio, p_minutos);
  insert into partidos (liga_id, fase, jornada, local_id, visitante_id, sede_id, campo, hora)
  values (p_liga, 'semifinal', 1, null, null, p_sede, h1.campo, h1.hora);
  select * into h2 from hueco_libre(p_sede, p_campos, p_inicio, p_minutos);
  insert into partidos (liga_id, fase, jornada, local_id, visitante_id, sede_id, campo, hora)
  values (p_liga, 'semifinal', 2, null, null, p_sede, h2.campo, h2.hora);
  select * into h3 from hueco_libre(p_sede, p_campos, greatest(h1.hora, h2.hora) + dur, p_minutos);
  insert into partidos (liga_id, fase, jornada, local_id, visitante_id, sede_id, campo, hora)
  values (p_liga, 'tercer_puesto', 1, null, null, p_sede, h3.campo, h3.hora);
  select * into h4 from hueco_libre(p_sede, p_campos, greatest(h1.hora, h2.hora) + dur, p_minutos);
  insert into partidos (liga_id, fase, jornada, local_id, visitante_id, sede_id, campo, hora)
  values (p_liga, 'final', 1, null, null, p_sede, h4.campo, h4.hora);
end $$;

grant execute on function public.crear_fase_final_vacia(uuid, timestamptz, uuid, int, int) to authenticated;
