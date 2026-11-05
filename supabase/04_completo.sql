-- =====================================================================
-- Marbel Football Cup · Todo lo que falta para la versión completa
-- Ejecutar en Supabase > SQL Editor DESPUÉS de 01, 02 y 03.
-- =====================================================================

-- ---------- Columnas nuevas ----------
alter table partidos add column if not exists penaltis_local int check (penaltis_local >= 0);
alter table partidos add column if not exists penaltis_visitante int check (penaltis_visitante >= 0);
alter table partidos add column if not exists aviso_retraso boolean not null default false;

alter table torneos add column if not exists publicado boolean not null default true;

alter table avisos add column if not exists ambito text not null default 'todos'
  check (ambito in ('todos', 'sede', 'categoria', 'equipo'));
alter table avisos add column if not exists ambito_ref text;          -- nombre de sede / categoría / equipo
alter table avisos add column if not exists automatico boolean not null default false;

alter table perfiles add column if not exists email text;
update perfiles p set email = u.email from auth.users u where u.id = p.id and p.email is null;

-- El perfil guarda también el email (para que administración identifique al personal)
create or replace function public.crear_perfil() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into perfiles (id, nombre, apellidos, equipo_id, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nombre', ''),
    coalesce(new.raw_user_meta_data ->> 'apellidos', ''),
    nullif(new.raw_user_meta_data ->> 'equipo_id', '')::uuid,
    new.email
  );
  return new;
end $$;

-- Los cambios automáticos (rellenar cruces) no deben chocar con la protección de la mesa
create or replace function public.proteger_partido() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_setting('marbel.sistema', true), '') <> '1'
     and auth.uid() is not null and mi_rol() = 'mesa' and (
       new.liga_id      is distinct from old.liga_id
    or new.fase         is distinct from old.fase
    or new.local_id     is distinct from old.local_id
    or new.visitante_id is distinct from old.visitante_id
    or new.sede_id      is distinct from old.sede_id
    or new.hora         is distinct from old.hora) then
    raise exception 'La mesa de sede solo puede cambiar resultado, estado, retraso y campo';
  end if;
  new.actualizado := now();
  new.actualizado_por := auth.uid();
  return new;
end $$;

-- ---------- Clasificación de cada liga ----------
-- Orden: puntos, diferencia de goles, goles a favor.
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
            + count(*) filter (where r.gf = r.gc))::int        as pts
    from liga_equipos le
    left join r on r.liga_id = le.liga_id and r.equipo_id = le.equipo_id
   group by le.liga_id, le.equipo_id
)
select t.*, row_number() over (partition by t.liga_id
                               order by t.pts desc, t.dg desc, t.gf desc, t.equipo_id)::int as pos
  from t;

-- Máximos goleadores ("Nombre I." + equipo)
create or replace view public.goleadores with (security_invoker = true) as
select g.jugador, g.equipo_id, p.liga_id, count(*)::int as goles
  from goles g join partidos p on p.id = g.partido_id
 group by g.jugador, g.equipo_id, p.liga_id;

-- ---------- Ganador / perdedor de un partido (con penaltis) ----------
create or replace function public.ganador_partido(p partidos) returns uuid
language sql stable as $$
  select case
    when p.estado <> 'finalizado' or p.goles_local is null or p.goles_visitante is null then null
    when p.goles_local > p.goles_visitante then p.local_id
    when p.goles_local < p.goles_visitante then p.visitante_id
    when coalesce(p.penaltis_local, -1) > coalesce(p.penaltis_visitante, -1) then p.local_id
    when coalesce(p.penaltis_local, -1) < coalesce(p.penaltis_visitante, -1) then p.visitante_id
  end
$$;

create or replace function public.perdedor_partido(p partidos) returns uuid
language sql stable as $$
  select case
    when ganador_partido(p) is null then null
    when ganador_partido(p) = p.local_id then p.visitante_id
    else p.local_id
  end
$$;

-- ---------- Generar el calendario de una liga (todos contra todos) ----------
create or replace function public.generar_liga(
  p_liga uuid, p_inicio timestamptz, p_sede uuid,
  p_minutos int default 30, p_campos int default 2)
returns int
language plpgsql security definer set search_path = public as $$
declare
  arr uuid[]; n int; r int; i int; a uuid; b uuid; hueco int := 0;
begin
  if auth.uid() is not null and mi_rol() <> 'admin' then
    raise exception 'Solo administración puede generar el calendario';
  end if;
  if exists (select 1 from partidos where liga_id = p_liga and fase = 'liga') then
    raise exception 'Esta liga ya tiene partidos. Bórralos antes de volver a generarla.';
  end if;
  select array_agg(equipo_id order by random()) into arr from liga_equipos where liga_id = p_liga;
  n := coalesce(array_length(arr, 1), 0);
  if n < 2 then raise exception 'La liga necesita al menos 2 equipos'; end if;
  if n % 2 = 1 then arr := arr || null::uuid; n := n + 1; end if;   -- con impares, uno descansa

  for r in 0 .. n - 2 loop
    for i in 0 .. n / 2 - 1 loop
      a := arr[1 + i]; b := arr[n - i];
      if a is not null and b is not null then
        insert into partidos (liga_id, fase, jornada, local_id, visitante_id, sede_id, campo, hora)
        values (p_liga, 'liga', r + 1,
                case when r % 2 = 0 then a else b end,
                case when r % 2 = 0 then b else a end,
                p_sede, 'Campo ' || ((hueco % greatest(p_campos, 1)) + 1),
                p_inicio + make_interval(mins => (hueco / greatest(p_campos, 1)) * p_minutos));
        hueco := hueco + 1;
      end if;
    end loop;
    arr := array[arr[1]] || arr[n:n] || arr[2:n - 1];   -- rotación (método del círculo)
  end loop;
  return hueco;
end $$;

-- ---------- Generar semifinales, final y 3er puesto ----------
create or replace function public.generar_fase_final(
  p_liga uuid, p_inicio timestamptz, p_sede uuid, p_minutos int default 30)
returns void
language plpgsql security definer set search_path = public as $$
declare top uuid[];
begin
  if auth.uid() is not null and mi_rol() <> 'admin' then
    raise exception 'Solo administración puede generar la fase final';
  end if;
  if exists (select 1 from partidos where liga_id = p_liga and fase <> 'liga') then
    raise exception 'La fase final de esta liga ya existe';
  end if;
  select array_agg(equipo_id order by pos) into top
    from clasificacion where liga_id = p_liga and pos <= 4;
  if coalesce(array_length(top, 1), 0) < 4 then
    raise exception 'Hacen falta 4 equipos clasificados';
  end if;
  insert into partidos (liga_id, fase, jornada, local_id, visitante_id, sede_id, campo, hora) values
    (p_liga, 'semifinal',     1, top[1], top[4], p_sede, 'Campo 1', p_inicio),
    (p_liga, 'semifinal',     2, top[2], top[3], p_sede, 'Campo 2', p_inicio),
    (p_liga, 'tercer_puesto', 1, null,   null,   p_sede, 'Campo 2', p_inicio + make_interval(mins => p_minutos)),
    (p_liga, 'final',         1, null,   null,   p_sede, 'Campo 1', p_inicio + make_interval(mins => p_minutos));
end $$;

-- Al terminar una semifinal, se rellenan la final y el 3er puesto solos
create or replace function public.completar_cruces() returns trigger
language plpgsql security definer set search_path = public as $$
declare g uuid; p uuid;
begin
  if new.fase = 'semifinal' and new.estado = 'finalizado' then
    g := ganador_partido(new); p := perdedor_partido(new);
    if g is null then return new; end if;               -- empate sin penaltis: aún no
    perform set_config('marbel.sistema', '1', true);
    if new.jornada = 1 then
      update partidos set local_id = g where liga_id = new.liga_id and fase = 'final';
      update partidos set local_id = p where liga_id = new.liga_id and fase = 'tercer_puesto';
    else
      update partidos set visitante_id = g where liga_id = new.liga_id and fase = 'final';
      update partidos set visitante_id = p where liga_id = new.liga_id and fase = 'tercer_puesto';
    end if;
    perform set_config('marbel.sistema', '', true);
  end if;
  return new;
end $$;

drop trigger if exists completar_cruces on partidos;
create trigger completar_cruces after update on partidos
  for each row execute function public.completar_cruces();

-- ---------- Ranking de La Porra ----------
-- Puntos: ganador de la liga 3 · 5º (sin semis) 2 · cada finalista 4 · campeón 8 · 3er puesto 2.
-- Solo muestra "Nombre I." y equipo; nunca email ni apellidos.
create or replace function public.ranking_porra(p_liga uuid default null)
returns table (pos int, nombre text, equipo text, puntos int, soy_yo boolean)
language sql stable security definer set search_path = public as $$
  with liga_acabada as (
    select l.id as liga_id from ligas l
     where exists (select 1 from partidos x where x.liga_id = l.id and x.fase = 'liga')
       and not exists (select 1 from partidos x where x.liga_id = l.id and x.fase = 'liga' and x.estado <> 'finalizado')
  ), puntos as (
    select pr.usuario_id, pr.liga_id, pr.tipo, pr.equipo_id,
      case pr.tipo
        when 'campeon_liga' then (select 3 from clasificacion c join liga_acabada a using (liga_id)
                                   where c.liga_id = pr.liga_id and c.pos = 1 and c.equipo_id = pr.equipo_id)
        when 'fuera_semis'  then (select 2 from clasificacion c join liga_acabada a using (liga_id)
                                   where c.liga_id = pr.liga_id and c.pos = 5 and c.equipo_id = pr.equipo_id)
        when 'finalista'    then (select 4 from partidos f where f.liga_id = pr.liga_id and f.fase = 'final'
                                   and pr.equipo_id in (f.local_id, f.visitante_id))
        when 'campeon'      then (select 8 from partidos f where f.liga_id = pr.liga_id and f.fase = 'final'
                                   and ganador_partido(f) = pr.equipo_id)
        when 'tercer_puesto' then (select 2 from partidos f where f.liga_id = pr.liga_id and f.fase = 'tercer_puesto'
                                   and ganador_partido(f) = pr.equipo_id)
      end as pts
    from predicciones pr
    where p_liga is null or pr.liga_id = p_liga
  ), total as (
    select usuario_id, coalesce(sum(pts), 0)::int as puntos from puntos group by usuario_id
  )
  select row_number() over (order by t.puntos desc, pf.nombre)::int,
         trim(pf.nombre || ' ' || coalesce(left(pf.apellidos, 1) || '.', '')),
         coalesce(e.nombre, 'Sin equipo'),
         t.puntos,
         coalesce(t.usuario_id = auth.uid(), false)
    from total t
    join perfiles pf on pf.id = t.usuario_id
    left join equipos e on e.id = pf.equipo_id
   order by 1;
$$;

-- ---------- Borrar mi cuenta (derecho de supresión) ----------
create or replace function public.borrar_mi_cuenta() returns void
language sql security definer set search_path = public, auth as $$
  delete from auth.users where id = auth.uid();
$$;

-- ---------- Galería ----------
create table if not exists fotos (
  id        uuid primary key default gen_random_uuid(),
  url       text not null,          -- assets/... (incluidas) o https://... (subidas)
  pie       text not null default '',
  vertical  boolean not null default false,
  orden     int not null default 0,
  creado    timestamptz not null default now()
);
alter table fotos enable row level security;
drop policy if exists "lectura publica" on fotos;
create policy "lectura publica" on fotos for select using (true);
drop policy if exists "gestion galeria" on fotos;
create policy "gestion galeria" on fotos for all to authenticated
  using (mi_rol() in ('admin', 'comunicacion')) with check (mi_rol() in ('admin', 'comunicacion'));

insert into fotos (url, pie, vertical, orden)
select * from (values
  ('assets/images/galeria/01-campeones.jpg',     '¡Campeones! Celebración con medallas',     false, 1),
  ('assets/images/galeria/02-grada.jpg',         'La grada a tope',                          false, 2),
  ('assets/images/galeria/03-charla.jpg',        'Charla antes del partido',                 true,  3),
  ('assets/images/galeria/04-arbitro.jpg',       'Salida al campo con el árbitro',           false, 4),
  ('assets/images/galeria/05-arco.jpg',          'Foto de equipo en el arco de entrada',     false, 5),
  ('assets/images/galeria/06-medallas.jpg',      'Las medallas del torneo',                  false, 6),
  ('assets/images/galeria/07-carpas.jpg',        'Zona de carpas',                           true,  7),
  ('assets/images/galeria/08-pulseras.jpg',      'Las pulseras de la Marea azul',            false, 8),
  ('assets/images/galeria/09-familia.jpg',       'Foto de familia de un equipo',             false, 9),
  ('assets/images/galeria/10-fruta.jpg',         'Fruta y bebida para todos',                false, 10),
  ('assets/images/galeria/11-fisioterapia.jpg',  'Fisioterapia a pie de campo',              true,  11),
  ('assets/images/galeria/12-sanitaria.jpg',     'Asistencia sanitaria durante el torneo',   false, 12)
) v(url, pie, vertical, orden)
where not exists (select 1 from fotos);

-- ---------- Escudos (incluidos en la app) ----------
update equipos e set escudo_url = 'assets/images/escudos/' || v.archivo || '.jpg'
from (values
  ('Academia Afán','academia-afan'), ('Academia Paquito','academia-paquito'),
  ('Albacete Balompié','albacete-balompie'), ('Amigos Futboleros Fortuna','amigos-futboleros-fortuna'),
  ('Archena F.C.','archena-fc'), ('C.F. Albatera Sporting','cf-albatera-sporting'),
  ('C.F. Rafal','cf-rafal'), ('C.F.S. El Progreso','cfs-el-progreso'),
  ('CFO Sant Joan','cfo-sant-joan'), ('Club Deportivo Lumbreras','cd-lumbreras'),
  ('Costa City UMH','costa-city-umh'), ('E.F. Santa Ana - Cartagena','ef-santa-ana-cartagena'),
  ('Elche Dream C.F.','elche-dream'), ('Elda Unión C.F.','elda-union'),
  ('F.C. Cartagena SAD','fc-cartagena'), ('Garra Ilicitana C.F.','garra-ilicitana'),
  ('Kelme C.F.','kelme-cf'), ('Lacross Babel C.F.','lacross-babel'),
  ('Ovejos F.C.','ovejos-fc'), ('Promesas Elche','promesas-elche'),
  ('Racing Akra C.F.','racing-akra'), ('Ranero Club de Fútbol','ranero-cf'),
  ('Real Murcia C.F.','real-murcia'), ('Selección Arsenal','seleccion-arsenal'),
  ('Selección Murciana','seleccion-murciana'), ('Sporting Saladar','sporting-saladar'),
  ('Triple A Academy','triple-a-academy'), ('U.E. Crevillent','ue-crevillent'),
  ('UCAM Murcia C.F.','ucam-murcia')
) v(nombre, archivo)
where e.nombre = v.nombre and e.escudo_url is null;

-- ---------- Almacenamiento de fotos y escudos subidos desde el panel ----------
insert into storage.buckets (id, name, public) values
  ('galeria', 'galeria', true), ('escudos', 'escudos', true)
on conflict (id) do nothing;

drop policy if exists "marbel sube galeria" on storage.objects;
create policy "marbel sube galeria" on storage.objects for insert to authenticated
  with check (bucket_id = 'galeria' and public.mi_rol() in ('admin', 'comunicacion'));
drop policy if exists "marbel borra galeria" on storage.objects;
create policy "marbel borra galeria" on storage.objects for delete to authenticated
  using (bucket_id = 'galeria' and public.mi_rol() in ('admin', 'comunicacion'));
drop policy if exists "marbel sube escudos" on storage.objects;
create policy "marbel sube escudos" on storage.objects for insert to authenticated
  with check (bucket_id = 'escudos' and public.mi_rol() = 'admin');
drop policy if exists "marbel cambia escudos" on storage.objects;
create policy "marbel cambia escudos" on storage.objects for update to authenticated
  using (bucket_id = 'escudos' and public.mi_rol() = 'admin');

-- ---------- Tiempo real también para fotos ----------
do $$ begin
  alter publication supabase_realtime add table fotos;
exception when duplicate_object then null;
end $$;

-- ---------- La mesa de sede puede publicar avisos de su sede y a seguidores ----------
drop policy if exists "mesa publica avisos" on avisos;
create policy "mesa publica avisos" on avisos for insert to authenticated
  with check (mi_rol() = 'mesa' and ambito in ('sede', 'equipo'));
