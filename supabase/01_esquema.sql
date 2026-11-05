-- =====================================================================
-- Marbel Football Cup · Esquema de la base de datos (paso 1)
-- Ejecutar UNA vez en Supabase > SQL Editor, antes de 02_datos_iniciales.sql
-- =====================================================================
-- Resumen de permisos:
--   · Cualquiera (sin cuenta) puede LEER torneo, sedes, equipos, partidos,
--     goles y avisos.
--   · admin         → puede cambiarlo todo.
--   · mesa          → mete resultados, retrasos y goles SOLO de su sede.
--   · comunicacion  → publica y edita avisos.
--   · usuario       → solo su perfil y sus predicciones de La Porra.
--   Los roles solo los cambia administración (o tú desde el SQL Editor).
-- No se guarda NINGÚN dato de jugadores salvo "Nombre I." en los goles.
-- =====================================================================

-- ---------- Tipos ----------
create type rol_app         as enum ('usuario', 'comunicacion', 'mesa', 'admin');
create type fase_partido    as enum ('liga', 'semifinal', 'tercer_puesto', 'final');
create type estado_partido  as enum ('programado', 'en_juego', 'finalizado', 'aplazado');
create type tipo_prediccion as enum ('campeon_liga', 'fuera_semis', 'finalista', 'campeon', 'tercer_puesto');

-- ---------- Tablas del torneo ----------
create table torneos (
  id                uuid primary key default gen_random_uuid(),
  nombre            text not null,
  fechas_texto      text not null,              -- "26-27 dic · 2-3 ene"
  inicio            timestamptz not null,        -- primer partido (cuenta atrás)
  inscripcion_hasta date,
  activo            boolean not null default true
);

create table sedes (
  id             uuid primary key default gen_random_uuid(),
  nombre         text not null unique,           -- "Albatera"
  nombre_oficial text not null,                  -- "Campo de Fútbol Municipal Nuevo Calvario"
  maps_url       text,
  foto_url       text,
  servicios      text[] not null default '{}',
  orden          int not null default 0
);

create table niveles (
  id     text primary key,                       -- 'iniciacion', 'medio', 'elite', 'femenino'
  nombre text not null,
  color  text not null,
  orden  int  not null
);

create table categorias (
  id        uuid primary key default gen_random_uuid(),
  nombre    text not null unique,
  femenina  boolean not null default false,
  orden     int not null
);

create table equipos (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null unique,
  localidad  text,
  escudo_url text,
  creado     timestamptz not null default now()
);

-- Una liga = una categoría + un nivel dentro de un torneo (5 equipos, 4 partidos cada uno)
create table ligas (
  id           uuid primary key default gen_random_uuid(),
  torneo_id    uuid not null references torneos on delete cascade,
  categoria_id uuid not null references categorias,
  nivel_id     text not null references niveles,
  unique (torneo_id, categoria_id, nivel_id)
);

create table liga_equipos (
  liga_id   uuid not null references ligas on delete cascade,
  equipo_id uuid not null references equipos on delete cascade,
  primary key (liga_id, equipo_id)
);

create table partidos (
  id              uuid primary key default gen_random_uuid(),
  liga_id         uuid not null references ligas on delete cascade,
  fase            fase_partido not null default 'liga',
  jornada         int,
  local_id        uuid references equipos,       -- vacío en cruces aún sin decidir
  visitante_id    uuid references equipos,
  sede_id         uuid references sedes,
  campo           text,                          -- "Campo 1"
  hora            timestamptz not null,
  retraso_min     int not null default 0 check (retraso_min >= 0),
  estado          estado_partido not null default 'programado',
  goles_local     int check (goles_local >= 0),
  goles_visitante int check (goles_visitante >= 0),
  actualizado     timestamptz not null default now(),
  actualizado_por uuid references auth.users,
  check (local_id is null or visitante_id is null or local_id <> visitante_id)
);
create index on partidos (liga_id);
create index on partidos (hora);

-- Goles con autor: solo "Nombre I." + equipo (nunca más datos del jugador)
create table goles (
  id         uuid primary key default gen_random_uuid(),
  partido_id uuid not null references partidos on delete cascade,
  equipo_id  uuid not null references equipos,
  jugador    text not null check (char_length(jugador) between 2 and 30),  -- formato "Nombre I."
  minuto     int check (minuto between 0 and 120),
  creado     timestamptz not null default now()
);

create table avisos (
  id        uuid primary key default gen_random_uuid(),
  torneo_id uuid references torneos on delete cascade,
  texto     text not null check (char_length(texto) between 1 and 500),
  fijado    boolean not null default false,
  creado    timestamptz not null default now(),
  autor     uuid references auth.users default auth.uid()
);

-- ---------- Personas ----------
create table perfiles (
  id        uuid primary key references auth.users on delete cascade,
  nombre    text not null,
  apellidos text not null,
  equipo_id uuid references equipos on delete set null,   -- null = "sin equipo"
  rol       rol_app not null default 'usuario',
  sede_id   uuid references sedes,                        -- solo para rol 'mesa'
  creado    timestamptz not null default now()
);

create table predicciones (
  id        uuid primary key default gen_random_uuid(),
  usuario_id uuid not null default auth.uid() references auth.users on delete cascade,
  liga_id   uuid not null references ligas on delete cascade,
  tipo      tipo_prediccion not null,
  equipo_id uuid not null references equipos,
  creado    timestamptz not null default now(),
  unique (usuario_id, liga_id, tipo, equipo_id)
);

create table registro_cambios (
  id      bigint generated always as identity primary key,
  tabla   text not null,
  fila    uuid,
  accion  text not null,
  quien   uuid default auth.uid(),
  cuando  timestamptz not null default now(),
  antes   jsonb,
  despues jsonb
);

-- ---------- Funciones de ayuda ----------
create or replace function public.mi_rol() returns rol_app
language sql stable security definer set search_path = public as $$
  select coalesce((select rol from perfiles where id = auth.uid()), 'usuario'::rol_app)
$$;

create or replace function public.mi_sede() returns uuid
language sql stable security definer set search_path = public as $$
  select sede_id from perfiles where id = auth.uid()
$$;

-- La Porra de una liga se cierra 30 minutos antes de su primer partido
create or replace function public.porra_abierta(p_liga uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(
    now() < (select min(hora) from partidos where liga_id = p_liga) - interval '30 minutes',
    true)
$$;

-- ---------- Triggers ----------
-- Al registrarse alguien, se crea su perfil con los datos del formulario
create or replace function public.crear_perfil() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into perfiles (id, nombre, apellidos, equipo_id)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nombre', ''),
    coalesce(new.raw_user_meta_data ->> 'apellidos', ''),
    nullif(new.raw_user_meta_data ->> 'equipo_id', '')::uuid
  );
  return new;
end $$;

create trigger al_registrarse
  after insert on auth.users
  for each row execute function public.crear_perfil();

-- Nadie puede darse a sí mismo un rol o una sede (salvo admin o el SQL Editor)
create or replace function public.proteger_perfil() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and mi_rol() <> 'admin'
     and (new.rol is distinct from old.rol or new.sede_id is distinct from old.sede_id) then
    raise exception 'Solo administración puede cambiar roles y sedes';
  end if;
  return new;
end $$;

create trigger proteger_perfil
  before update on perfiles
  for each row execute function public.proteger_perfil();

-- La mesa de sede solo puede tocar marcador, estado, retraso y campo
create or replace function public.proteger_partido() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and mi_rol() = 'mesa' and (
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

create trigger proteger_partido
  before update on partidos
  for each row execute function public.proteger_partido();

-- Registro de quién cambia qué
create or replace function public.registrar_cambio() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into registro_cambios (tabla, fila, accion, antes, despues)
  values (
    tg_table_name,
    case when tg_op = 'DELETE' then old.id else new.id end,
    tg_op,
    case when tg_op <> 'INSERT' then to_jsonb(old) end,
    case when tg_op <> 'DELETE' then to_jsonb(new) end
  );
  return coalesce(new, old);
end $$;

create trigger registro_partidos after insert or update or delete on partidos
  for each row execute function public.registrar_cambio();
create trigger registro_goles after insert or update or delete on goles
  for each row execute function public.registrar_cambio();
create trigger registro_avisos after insert or update or delete on avisos
  for each row execute function public.registrar_cambio();
create trigger registro_equipos after insert or update or delete on equipos
  for each row execute function public.registrar_cambio();

-- ---------- Seguridad por filas (RLS) ----------
alter table torneos          enable row level security;
alter table sedes            enable row level security;
alter table niveles          enable row level security;
alter table categorias       enable row level security;
alter table equipos          enable row level security;
alter table ligas            enable row level security;
alter table liga_equipos     enable row level security;
alter table partidos         enable row level security;
alter table goles            enable row level security;
alter table avisos           enable row level security;
alter table perfiles         enable row level security;
alter table predicciones     enable row level security;
alter table registro_cambios enable row level security;

-- Lectura pública + administración total en las tablas del torneo
do $$
declare t text;
begin
  foreach t in array array['torneos','sedes','niveles','categorias','equipos',
                           'ligas','liga_equipos','partidos','goles','avisos'] loop
    execute format('create policy "lectura publica" on %I for select using (true)', t);
    execute format('create policy "admin gestiona" on %I for all to authenticated
                    using (mi_rol() = ''admin'') with check (mi_rol() = ''admin'')', t);
  end loop;
end $$;

-- Mesa de sede: resultados de los partidos de SU sede
create policy "mesa actualiza su sede" on partidos for update to authenticated
  using (mi_rol() = 'mesa' and sede_id = mi_sede())
  with check (mi_rol() = 'mesa' and sede_id = mi_sede());

create policy "mesa mete goles de su sede" on goles for insert to authenticated
  with check (mi_rol() = 'mesa' and exists (
    select 1 from partidos p where p.id = partido_id and p.sede_id = mi_sede()));

create policy "mesa borra goles de su sede" on goles for delete to authenticated
  using (mi_rol() = 'mesa' and exists (
    select 1 from partidos p where p.id = partido_id and p.sede_id = mi_sede()));

-- Comunicación: avisos
create policy "comunicacion gestiona avisos" on avisos for all to authenticated
  using (mi_rol() = 'comunicacion') with check (mi_rol() = 'comunicacion');

-- Perfiles: cada uno el suyo; administración, todos
create policy "ver mi perfil" on perfiles for select to authenticated
  using (id = auth.uid() or mi_rol() = 'admin');
create policy "editar mi perfil" on perfiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy "admin edita perfiles" on perfiles for update to authenticated
  using (mi_rol() = 'admin') with check (mi_rol() = 'admin');

-- Predicciones: cada uno las suyas, y solo mientras la porra esté abierta
create policy "ver mis predicciones" on predicciones for select to authenticated
  using (usuario_id = auth.uid());
create policy "crear predicciones" on predicciones for insert to authenticated
  with check (usuario_id = auth.uid() and porra_abierta(liga_id));
create policy "borrar predicciones" on predicciones for delete to authenticated
  using (usuario_id = auth.uid() and porra_abierta(liga_id));

-- Registro de cambios: solo lo ve administración
create policy "admin ve registro" on registro_cambios for select to authenticated
  using (mi_rol() = 'admin');

-- ---------- Tiempo real (resultados y avisos al momento) ----------
alter publication supabase_realtime add table partidos, goles, avisos;
