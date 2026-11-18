-- =====================================================================
-- 15 · Sin nombres de jugadores
-- La web ya no guarda ni enseña nombres de jugadores: los goles se
-- apuntan solo con su equipo (y el minuto, si se quiere).
-- Se puede ejecutar más de una vez.
-- =====================================================================

-- 1. El nombre deja de ser obligatorio (y se quita su comprobación)
do $$
declare r record;
begin
  for r in
    select conname from pg_constraint
     where conrelid = 'public.goles'::regclass and contype = 'c'
       and pg_get_constraintdef(oid) ilike '%jugador%'
  loop
    execute format('alter table public.goles drop constraint %I', r.conname);
  end loop;
end $$;
alter table public.goles alter column jugador drop not null;

-- 2. Borrar los nombres que hubiera apuntados (los goles se quedan)
update public.goles set jugador = null where jugador is not null;

-- 3. Nadie puede volver a escribir un nombre
alter table public.goles drop constraint if exists goles_sin_nombre;
alter table public.goles add constraint goles_sin_nombre check (jugador is null);

-- 4. Fuera la lista de máximos goleadores por jugador
drop view if exists public.goleadores;

-- 5. La pregunta frecuente del IV Torneo Navideño, con la respuesta nueva
update public.torneos t
   set proyecto = jsonb_set(t.proyecto, array['info_bloques', b.i::text, 'items', q.j::text, '1'],
         to_jsonb('No. No publicamos plantillas, nombres, edades ni fotos de perfil de los jugadores: en resultados, estadísticas y notificaciones solo salen los equipos. Las fotos de la galería están autorizadas por los clubes.'::text))
  from (select t2.id, (x.n - 1) as i, x.bloque
          from public.torneos t2,
               jsonb_array_elements(t2.proyecto -> 'info_bloques') with ordinality as x(bloque, n)) b,
       lateral (select (y.n - 1) as j
                  from jsonb_array_elements(b.bloque -> 'items') with ordinality as y(item, n)
                 where y.item ->> 0 = '¿Se publican datos de los jugadores?') q
 where t.id = b.id and b.bloque ->> 'tipo' = 'preguntas';

select 'sql_15' as paso, true as hecho;
