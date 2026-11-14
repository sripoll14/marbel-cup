-- =====================================================================
-- 11 · Fase final conjunta entre grupos (decisión de última hora).
-- Ejecutar después de 10. Se puede ejecutar más de una vez.
--
-- Por defecto cada grupo tiene su propia fase final. Si se decide hacer
-- una sola entre todos los grupos de una categoría y nivel:
--   · 2 grupos: semifinales 1ºA – 2ºB y 1ºB – 2ºA.
--   · 3 grupos: los tres primeros + el mejor segundo (sin repetir grupo en semis).
--   · 4 grupos: semifinales 1ºA – 1ºD y 1ºB – 1ºC.
-- Después, 3er puesto y final como siempre. Los partidos se guardan en el
-- grupo A y el resto de grupos apuntan a él (ligas.final_en).
-- =====================================================================

alter table ligas add column if not exists final_en uuid references ligas on delete set null;

create or replace function public.generar_fase_conjunta(
  p_liga uuid, p_inicio timestamptz, p_sede uuid, p_minutos int default 30, p_campos int default 2)
returns void
language plpgsql security definer set search_path = public as $$
declare
  l ligas;
  grupos uuid[];
  n int;
  base uuid;
  a1 uuid; a2 uuid; b1 uuid; b2 uuid;   -- semifinal 1: a1 – a2 · semifinal 2: b1 – b2
  h1 record; h2 record; h3 record; h4 record;
  dur interval := make_interval(mins => p_minutos);
  ganadores record;
  w uuid[]; wg uuid[]; s record;
begin
  if not tengo_rol('admin') then raise exception 'Solo administración puede generar la fase final'; end if;
  select * into l from ligas where id = p_liga;
  if l.id is null then raise exception 'Esa liga no existe'; end if;

  select array_agg(id order by grupo) into grupos
    from ligas where torneo_id = l.torneo_id and categoria_id = l.categoria_id and nivel_id = l.nivel_id;
  n := coalesce(array_length(grupos, 1), 0);
  if n < 2 then raise exception 'Esta categoría no tiene grupos'; end if;
  if n > 4 then raise exception 'La fase final conjunta admite como mucho 4 grupos'; end if;
  if exists (select 1 from partidos where liga_id = any(grupos) and fase <> 'liga') then
    raise exception 'Algún grupo ya tiene fase final. Bórrala antes.';
  end if;
  if exists (select 1 from unnest(grupos) g
              where (select count(*) from liga_equipos le where le.liga_id = g) < 2) then
    raise exception 'Cada grupo necesita al menos 2 equipos';
  end if;
  base := grupos[1];

  if n = 2 then
    select equipo_id into a1 from clasificacion where liga_id = grupos[1] and pos = 1;
    select equipo_id into a2 from clasificacion where liga_id = grupos[2] and pos = 2;
    select equipo_id into b1 from clasificacion where liga_id = grupos[2] and pos = 1;
    select equipo_id into b2 from clasificacion where liga_id = grupos[1] and pos = 2;
  elsif n = 4 then
    select equipo_id into a1 from clasificacion where liga_id = grupos[1] and pos = 1;
    select equipo_id into a2 from clasificacion where liga_id = grupos[4] and pos = 1;
    select equipo_id into b1 from clasificacion where liga_id = grupos[2] and pos = 1;
    select equipo_id into b2 from clasificacion where liga_id = grupos[3] and pos = 1;
  else
    -- 3 grupos: primeros ordenados por puntos, dif. de goles y goles; y el mejor segundo
    select array_agg(equipo_id order by pts desc, dg desc, gf desc), array_agg(liga_id order by pts desc, dg desc, gf desc)
      into w, wg
      from clasificacion where liga_id = any(grupos) and pos = 1;
    select equipo_id, liga_id into s
      from clasificacion where liga_id = any(grupos) and pos = 2
     order by pts desc, dg desc, gf desc limit 1;
    if s.liga_id = wg[1] then        -- que el mejor segundo no repita contra su primero
      a1 := w[2]; a2 := s.equipo_id; b1 := w[1]; b2 := w[3];
    else
      a1 := w[1]; a2 := s.equipo_id; b1 := w[2]; b2 := w[3];
    end if;
  end if;

  if a1 is null or a2 is null or b1 is null or b2 is null then
    raise exception 'Faltan equipos clasificados en algún grupo';
  end if;

  select * into h1 from hueco_libre(p_sede, p_campos, p_inicio, p_minutos);
  insert into partidos (liga_id, fase, jornada, local_id, visitante_id, sede_id, campo, hora)
  values (base, 'semifinal', 1, a1, a2, p_sede, h1.campo, h1.hora);
  select * into h2 from hueco_libre(p_sede, p_campos, p_inicio, p_minutos);
  insert into partidos (liga_id, fase, jornada, local_id, visitante_id, sede_id, campo, hora)
  values (base, 'semifinal', 2, b1, b2, p_sede, h2.campo, h2.hora);
  select * into h3 from hueco_libre(p_sede, p_campos, greatest(h1.hora, h2.hora) + dur, p_minutos);
  insert into partidos (liga_id, fase, jornada, local_id, visitante_id, sede_id, campo, hora)
  values (base, 'tercer_puesto', 1, null, null, p_sede, h3.campo, h3.hora);
  select * into h4 from hueco_libre(p_sede, p_campos, greatest(h1.hora, h2.hora) + dur, p_minutos);
  insert into partidos (liga_id, fase, jornada, local_id, visitante_id, sede_id, campo, hora)
  values (base, 'final', 1, null, null, p_sede, h4.campo, h4.hora);

  update ligas set final_en = base where id = any(grupos) and id <> base;
end $$;

-- Borrar la fase final de una liga (si es conjunta, la de todos sus grupos)
create or replace function public.borrar_fase_final(p_liga uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  base uuid;
begin
  if not tengo_rol('admin') then raise exception 'Solo administración puede borrar la fase final'; end if;
  select coalesce(final_en, id) into base from ligas where id = p_liga;
  delete from partidos where liga_id = base and fase <> 'liga';
  update ligas set final_en = null where final_en = base;
end $$;

grant execute on function public.generar_fase_conjunta(uuid, timestamptz, uuid, int, int),
  public.borrar_fase_final(uuid) to authenticated;

-- Al dividir o quitar grupos, una fase conjunta anterior deja de valer
create or replace function public.borrar_grupo(p_liga uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  l ligas;
begin
  if not tengo_rol('admin') then raise exception 'Solo administración puede quitar grupos'; end if;
  select * into l from ligas where id = p_liga;
  if l.id is null then raise exception 'Ese grupo no existe'; end if;
  if exists (select 1 from liga_equipos where liga_id = p_liga) then
    raise exception 'Ese grupo tiene equipos. Pásalos a otro grupo antes de quitarlo.';
  end if;
  if exists (select 1 from partidos where liga_id = p_liga) then
    raise exception 'Ese grupo tiene partidos. Bórralos antes de quitarlo.';
  end if;
  if exists (select 1 from ligas where final_en = p_liga) then
    raise exception 'Ese grupo tiene la fase final conjunta. Bórrala antes.';
  end if;
  delete from ligas where id = p_liga;
  update ligas set grupo = null
   where torneo_id = l.torneo_id and categoria_id = l.categoria_id and nivel_id = l.nivel_id
     and (select count(*) from ligas x
           where x.torneo_id = l.torneo_id and x.categoria_id = l.categoria_id and x.nivel_id = l.nivel_id) = 1;
end $$;

-- La Porra: finalistas, campeón y 3er puesto se miran en la fase final
-- conjunta cuando la hay
create or replace function public.ranking_porra(p_liga uuid default null)
returns table (pos int, nombre text, equipo text, puntos int, soy_yo boolean)
language sql stable security definer set search_path = public as $$
  with liga_acabada as (
    select l.id as liga_id from ligas l
     where exists (select 1 from partidos x where x.liga_id = l.id and x.fase = 'liga')
       and not exists (select 1 from partidos x where x.liga_id = l.id and x.fase = 'liga' and x.estado <> 'finalizado')
  ), pr as (
    select p.*, coalesce(l.final_en, l.id) as liga_final
      from predicciones p join ligas l on l.id = p.liga_id
     where p_liga is null or p.liga_id = p_liga
  ), puntos as (
    select pr.usuario_id, pr.liga_id, pr.tipo, pr.equipo_id,
      case pr.tipo
        when 'campeon_liga' then (select 3 from clasificacion c join liga_acabada a using (liga_id)
                                   where c.liga_id = pr.liga_id and c.pos = 1 and c.equipo_id = pr.equipo_id)
        when 'fuera_semis'  then (select 2 from clasificacion c join liga_acabada a using (liga_id)
                                   where c.liga_id = pr.liga_id and c.pos = 5 and c.equipo_id = pr.equipo_id)
        when 'finalista'    then (select 4 from partidos f where f.liga_id = pr.liga_final and f.fase = 'final'
                                   and pr.equipo_id in (f.local_id, f.visitante_id))
        when 'campeon'      then (select 8 from partidos f where f.liga_id = pr.liga_final and f.fase = 'final'
                                   and ganador_partido(f) = pr.equipo_id)
        when 'tercer_puesto' then (select 2 from partidos f where f.liga_id = pr.liga_final and f.fase = 'tercer_puesto'
                                   and ganador_partido(f) = pr.equipo_id)
      end as pts
    from pr
  ), total as (
    select usuario_id, coalesce(sum(pts), 0)::int as puntos from puntos group by usuario_id
  )
  select row_number() over (order by t.puntos desc, lower(coalesce(pf.alias, '~')))::int,
         alias_visible(pf.alias, pf.alias_vetado_en),
         null::text,
         t.puntos,
         coalesce(t.usuario_id = auth.uid(), false)
    from total t
    join perfiles pf on pf.id = t.usuario_id
   order by 1;
$$;
