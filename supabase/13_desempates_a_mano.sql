-- =====================================================================
-- 13 · Desempates a mano (reglamento 2026).
-- Ejecutar después de 12. Se puede ejecutar más de una vez.
--
-- La app calcula los datos de la tabla (PJ, G, E, P, GF, GC, DG, PTS) y
-- ordena por puntos. Cuando hay empate a puntos, el orden lo decide la
-- organización a mano (enfrentamiento directo, goles, penaltis, sorteo…):
-- Panel → Calendario y sedes → «Ordenar empates».
-- Quién pasa a la fase final también se elige a mano.
-- =====================================================================

alter table liga_equipos add column if not exists orden_manual int;

-- Clasificación: puntos y, si empatan, el orden puesto a mano.
-- (Mientras no se ordene a mano, los empatados salen por orden alfabético.)
create or replace view public.clasificacion with (security_invoker = true) as
with r as (
  select liga_id, local_id as equipo_id, goles_local as gf, goles_visitante as gc
    from partidos where fase = 'liga' and estado = 'finalizado'
     and local_id is not null and goles_local is not null and goles_visitante is not null
  union all
  select liga_id, visitante_id, goles_visitante, goles_local
    from partidos where fase = 'liga' and estado = 'finalizado'
     and visitante_id is not null and goles_local is not null and goles_visitante is not null
), t as (
  select le.liga_id, le.equipo_id,
         count(r.equipo_id)::int                               as pj,
         count(*) filter (where r.gf > r.gc)::int              as g,
         count(*) filter (where r.gf = r.gc)::int              as e,
         count(*) filter (where r.gf < r.gc)::int              as p,
         coalesce(sum(r.gf), 0)::int                           as gf,
         coalesce(sum(r.gc), 0)::int                           as gc,
         coalesce(sum(r.gf - r.gc), 0)::int                    as dg,
         (3 * count(*) filter (where r.gf > r.gc)
            + count(*) filter (where r.gf = r.gc))::int        as pts,
         max(le.orden_manual)                                  as orden_manual
    from liga_equipos le
    left join r on r.liga_id = le.liga_id and r.equipo_id = le.equipo_id
   group by le.liga_id, le.equipo_id
)
select t.liga_id, t.equipo_id, t.pj, t.g, t.e, t.p, t.gf, t.gc, t.dg, t.pts,
       row_number() over (partition by t.liga_id
                          order by t.pts desc, t.orden_manual nulls last, e.nombre, t.equipo_id)::int as pos
  from t join equipos e on e.id = t.equipo_id;

-- Administración: orden de la tabla para resolver empates.
-- p_equipos: los equipos de la liga en el orden final (vacío = quitar el orden a mano).
create or replace function public.ordenar_empates(p_liga uuid, p_equipos uuid[]) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not tengo_rol('admin') then raise exception 'Solo administración puede ordenar la clasificación'; end if;
  update liga_equipos le
     set orden_manual = (select i::int from unnest(p_equipos) with ordinality u(id, i) where u.id = le.equipo_id)
   where le.liga_id = p_liga;
end $$;

-- Fase final conjunta a mano: crea los partidos vacíos en el primer grupo
-- y une a él el resto de grupos de esa categoría y nivel.
create or replace function public.crear_fase_conjunta_vacia(
  p_liga uuid, p_inicio timestamptz, p_sede uuid, p_minutos int default 30, p_campos int default 2)
returns void
language plpgsql security definer set search_path = public as $$
declare
  l ligas;
  grupos uuid[];
begin
  if not tengo_rol('admin') then raise exception 'Solo administración puede crear la fase final'; end if;
  select * into l from ligas where id = p_liga;
  select array_agg(id order by grupo) into grupos
    from ligas where torneo_id = l.torneo_id and categoria_id = l.categoria_id and nivel_id = l.nivel_id;
  if coalesce(array_length(grupos, 1), 0) < 2 then raise exception 'Esta categoría no tiene grupos'; end if;
  if exists (select 1 from partidos where liga_id = any(grupos) and fase <> 'liga')
     or exists (select 1 from ligas where id = any(grupos) and final_en is not null) then
    raise exception 'Algún grupo ya tiene fase final. Bórrala antes.';
  end if;
  perform crear_fase_final_vacia(grupos[1], p_inicio, p_sede, p_minutos, p_campos);
  update ligas set final_en = grupos[1] where id = any(grupos) and id <> grupos[1];
end $$;

grant execute on function public.ordenar_empates(uuid, uuid[]),
  public.crear_fase_conjunta_vacia(uuid, timestamptz, uuid, int, int) to authenticated;
