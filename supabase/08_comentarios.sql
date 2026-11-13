-- =====================================================================
-- 08 · Alias y comentarios (página del torneo y cada partido).
-- Ejecutar después de 07. Se puede ejecutar más de una vez.
--
-- ALIAS
-- · Cada cuenta tiene un alias. Es lo único que se ve en público
--   (ranking de La Porra y comentarios): nada de nombres ni equipos.
-- · 3 a 20 caracteres, único, y pasa el filtro de palabras.
-- · El personal puede vetar un alias: se ve "Alias en revisión" y la persona
--   tiene 24 horas para cambiarlo. Si no lo cambia, no puede jugar a La Porra
--   ni comentar hasta que lo cambie.
--
-- COMENTARIOS
-- · Para escribir, responder o reaccionar hace falta cuenta con alias.
-- · Cada comentario guarda quién lo escribió (nombre, email; solo lo ve el
--   personal). Nada se borra de verdad: lo oculto o borrado queda como prueba.
-- · Con palabras del filtro, o con 3 denuncias, queda pendiente de revisión.
-- · Máximo 300 caracteres y un comentario cada 30 segundos por persona.
-- =====================================================================

-- ---------- Filtro de palabras ----------
-- En minúscula y sin tildes. Con * al final vale todo lo que empiece así
-- ("gilipoll*" pilla "gilipollas"); sin *, solo esa palabra ("cono" no pilla "conocer").
create table if not exists palabras_filtradas (palabra text primary key);
insert into palabras_filtradas (palabra) values
  ('gilipoll*'), ('cabron*'), ('imbecil*'), ('subnormal*'), ('retrasad*'), ('maricon*'),
  ('hijoputa*'), ('hijo de puta'), ('malparid*'), ('bastard*'), ('chupapoll*'), ('capull*'),
  ('estupid*'), ('idiota*'), ('cojon*'), ('jodete'), ('joder'), ('follar*'),
  ('mongol'), ('mongola'), ('marica'), ('puta'), ('puto'), ('putas'), ('putos'), ('hdp'),
  ('mierda'), ('mierdas'), ('cono'), ('polla'), ('pollas'), ('tonto'), ('tonta'),
  ('payaso'), ('payasos'), ('zorra'), ('guarra'), ('mamon'), ('muerete'),
  ('negrata'), ('sudaca'), ('panchito'), ('nazi*'), ('hitler')
on conflict do nothing;
alter table palabras_filtradas enable row level security;

-- Texto en minúscula, sin tildes y sin trucos (0 -> o, 4 -> a, ...)
create or replace function public.normalizar_texto(t text) returns text
language sql immutable as $$
  select translate(lower(t), 'áàäâéèëêíìïîóòöôúùüûñç0134578@$', 'aaaaeeeeiiiioooouuuuncoieastbas')
$$;

create or replace function public.texto_filtrado(t text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from palabras_filtradas p
    where normalizar_texto(t) ~ (
      case when p.palabra like '%*'
           then '\m' || normalizar_texto(rtrim(p.palabra, '*'))
           else '\m' || normalizar_texto(p.palabra) || '\M' end)
  )
$$;

-- ¿Puede moderar? (administración o comunicación)
create or replace function public.puedo_moderar() returns boolean
language sql stable security definer set search_path = public as $$
  select tengo_rol('admin') or tengo_rol('comunicacion')
$$;

drop policy if exists "personal gestiona filtro" on palabras_filtradas;
create policy "personal gestiona filtro" on palabras_filtradas for all to authenticated
  using (puedo_moderar()) with check (puedo_moderar());

-- ---------- Alias ----------
alter table perfiles add column if not exists alias text;
alter table perfiles add column if not exists alias_vetado_en timestamptz;
alter table perfiles add column if not exists comentarios_bloqueado boolean not null default false;
create unique index if not exists perfiles_alias_unico on perfiles (lower(alias));

-- Lo que se ve en público
create or replace function public.alias_visible(p_alias text, p_vetado timestamptz) returns text
language sql immutable as $$
  select case when p_vetado is not null then 'Alias en revisión'
              when p_alias is null or btrim(p_alias) = '' then 'Sin alias'
              else p_alias end
$$;

-- null si el alias vale; si no, el motivo
create or replace function public.problema_alias(p_alias text, p_yo uuid default null) returns text
language plpgsql stable security definer set search_path = public as $$
declare
  a text := btrim(coalesce(p_alias, ''));
begin
  if char_length(a) < 3 then return 'El alias tiene que tener al menos 3 caracteres'; end if;
  if char_length(a) > 20 then return 'El alias puede tener como mucho 20 caracteres'; end if;
  if a !~ '^[A-Za-zÁÉÍÓÚÜÑáéíóúüñÇç0-9 ._-]+$' then
    return 'Usa solo letras, números, espacios, puntos, guiones o guiones bajos';
  end if;
  if texto_filtrado(a) then return 'Ese alias no está permitido. Elige otro'; end if;
  if lower(a) in ('alias en revision', 'alias en revisión', 'sin alias', 'marbel', 'marbel cup', 'organizacion', 'organización', 'admin', 'administrador') then
    return 'Ese alias no está permitido. Elige otro';
  end if;
  if exists (select 1 from perfiles where lower(alias) = lower(a) and (p_yo is null or id <> p_yo)) then
    return 'Ese alias ya lo tiene otra persona';
  end if;
  return null;
end $$;

-- Se puede consultar antes de crear la cuenta
create or replace function public.alias_disponible(p_alias text) returns text
language sql stable security definer set search_path = public as $$
  select problema_alias(p_alias, auth.uid())
$$;
grant execute on function public.alias_disponible(text) to anon, authenticated;

-- ¿Puede jugar a La Porra y comentar? (tiene alias y no lleva más de 24 h vetado)
create or replace function public.puede_participar(p_uid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((
    select alias is not null and (alias_vetado_en is null or alias_vetado_en > now() - interval '24 hours')
    from perfiles where id = p_uid), false)
$$;

-- Nadie cambia a mano lo que no le toca (roles y sede: administración;
-- alias, veto y bloqueo: solo con las funciones de abajo)
create or replace function public.proteger_perfil() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and mi_rol() <> 'admin'
     and (new.rol is distinct from old.rol
       or new.roles is distinct from old.roles
       or new.sede_id is distinct from old.sede_id) then
    raise exception 'Solo administración puede cambiar roles y sedes';
  end if;
  if auth.uid() is not null
     and coalesce(current_setting('marbel.sistema', true), '') <> '1'
     and (new.alias is distinct from old.alias
       or new.alias_vetado_en is distinct from old.alias_vetado_en
       or new.comentarios_bloqueado is distinct from old.comentarios_bloqueado) then
    raise exception 'Eso solo se puede cambiar desde la app (alias) o desde el panel (veto y bloqueo)';
  end if;
  return new;
end $$;

-- El alias llega al crear la cuenta; si no vale o está cogido, se queda vacío
-- y la app pide elegir otro
create or replace function public.crear_perfil() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  a text := nullif(btrim(coalesce(new.raw_user_meta_data ->> 'alias', '')), '');
begin
  if a is not null and problema_alias(a) is not null then
    a := null;
  end if;
  insert into perfiles (id, nombre, apellidos, equipo_id, email, alias)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nombre', ''),
    coalesce(new.raw_user_meta_data ->> 'apellidos', ''),
    nullif(new.raw_user_meta_data ->> 'equipo_id', '')::uuid,
    new.email,
    a
  );
  return new;
end $$;

-- Cambiar mi alias (también quita el veto)
create or replace function public.cambiar_alias(p_alias text) returns void
language plpgsql security definer set search_path = public as $$
declare
  problema text;
begin
  if auth.uid() is null then raise exception 'Tienes que iniciar sesión'; end if;
  problema := problema_alias(p_alias, auth.uid());
  if problema is not null then raise exception '%', problema; end if;
  perform set_config('marbel.sistema', '1', true);
  update perfiles set alias = btrim(p_alias), alias_vetado_en = null where id = auth.uid();
  perform set_config('marbel.sistema', '0', true);
end $$;

-- Personal: vetar (o quitar el veto de) un alias
create or replace function public.vetar_alias(p_usuario uuid, p_vetar boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not puedo_moderar() then raise exception 'Solo administración o comunicación pueden vetar alias'; end if;
  perform set_config('marbel.sistema', '1', true);
  update perfiles set alias_vetado_en = case when p_vetar then now() else null end where id = p_usuario;
  perform set_config('marbel.sistema', '0', true);
end $$;

-- Personal: lista de alias (los vetados primero, con su plazo)
create or replace function public.alias_usuarios()
returns table (id uuid, alias text, nombre text, apellidos text, email text, vetado_en timestamptz, limite timestamptz, vencido boolean)
language sql stable security definer set search_path = public as $$
  select p.id, p.alias, p.nombre, p.apellidos, p.email, p.alias_vetado_en,
         p.alias_vetado_en + interval '24 hours', coalesce(p.alias_vetado_en + interval '24 hours' < now(), false)
  from perfiles p
  where (p.alias is not null or p.alias_vetado_en is not null) and puedo_moderar()
  order by p.alias_vetado_en is null, p.alias_vetado_en, lower(p.alias)
$$;

grant execute on function public.cambiar_alias(text), public.vetar_alias(uuid, boolean),
  public.alias_usuarios() to authenticated;

-- La Porra: sin alias válido no se pueden hacer predicciones
drop policy if exists "crear predicciones" on predicciones;
create policy "crear predicciones" on predicciones for insert to authenticated
  with check (usuario_id = auth.uid() and porra_abierta(liga_id) and puede_participar(auth.uid()));

-- Ranking de La Porra: solo el alias (nada de nombres ni equipos)
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
  select row_number() over (order by t.puntos desc, lower(coalesce(pf.alias, '~')))::int,
         alias_visible(pf.alias, pf.alias_vetado_en),
         null::text,
         t.puntos,
         coalesce(t.usuario_id = auth.uid(), false)
    from total t
    join perfiles pf on pf.id = t.usuario_id
   order by 1;
$$;

-- ---------- Comentarios ----------
create table if not exists comentarios (
  id           uuid primary key default gen_random_uuid(),
  torneo_id    uuid references torneos on delete cascade,
  partido_id   uuid references partidos on delete cascade,      -- null = página del torneo
  respuesta_a  uuid references comentarios on delete cascade,   -- null = comentario principal
  usuario_id   uuid references auth.users on delete set null,
  autor        text not null,                                   -- alias que se ve
  texto        text not null,
  reacciones   jsonb not null default '{}',                     -- {"👏": 3, "⚽": 1}
  estado       text not null default 'publicado'
               check (estado in ('publicado', 'pendiente', 'oculto', 'borrado')),
  motivo       text,
  creado       timestamptz not null default now(),
  revisado_por uuid references auth.users on delete set null,
  revisado_en  timestamptz
);
alter table comentarios add column if not exists respuesta_a uuid references comentarios on delete cascade;
alter table comentarios add column if not exists reacciones jsonb not null default '{}';
alter table comentarios drop column if exists equipo;
create index if not exists comentarios_torneo on comentarios (torneo_id, creado) where partido_id is null;
create index if not exists comentarios_partido on comentarios (partido_id, creado);
create index if not exists comentarios_usuario on comentarios (usuario_id, creado);

-- Quién lo escribió de verdad (solo el personal). Se guarda aunque se borre la cuenta.
create table if not exists comentarios_autor (
  comentario_id uuid primary key references comentarios on delete cascade,
  usuario_id    uuid,
  alias         text,
  nombre        text not null,
  apellidos     text not null,
  email         text,
  equipo_id     uuid
);
alter table comentarios_autor add column if not exists alias text;

create table if not exists denuncias (
  comentario_id uuid not null references comentarios on delete cascade,
  usuario_id    uuid not null references auth.users on delete cascade,
  creado        timestamptz not null default now(),
  primary key (comentario_id, usuario_id)
);

create table if not exists reacciones (
  comentario_id uuid not null references comentarios on delete cascade,
  usuario_id    uuid not null references auth.users on delete cascade,
  emoji         text not null check (emoji in ('👏', '⚽', '❤️', '😂')),
  primary key (comentario_id, usuario_id, emoji)
);

alter table comentarios enable row level security;
alter table comentarios_autor enable row level security;
alter table denuncias enable row level security;
alter table reacciones enable row level security;

drop policy if exists "ver comentarios" on comentarios;
create policy "ver comentarios" on comentarios for select
  using (estado = 'publicado' or usuario_id = auth.uid() or puedo_moderar());

drop policy if exists "personal ve autores" on comentarios_autor;
create policy "personal ve autores" on comentarios_autor for select to authenticated
  using (puedo_moderar());

drop policy if exists "ver denuncias" on denuncias;
create policy "ver denuncias" on denuncias for select to authenticated
  using (usuario_id = auth.uid() or puedo_moderar());

drop policy if exists "ver mis reacciones" on reacciones;
create policy "ver mis reacciones" on reacciones for select to authenticated
  using (usuario_id = auth.uid());

-- Si cambia el alias (o se veta), cambia en todos sus comentarios
create or replace function public.alias_en_comentarios() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.alias is distinct from old.alias or new.alias_vetado_en is distinct from old.alias_vetado_en then
    update comentarios set autor = alias_visible(new.alias, new.alias_vetado_en) where usuario_id = new.id;
  end if;
  return new;
end $$;
drop trigger if exists alias_en_comentarios on perfiles;
create trigger alias_en_comentarios after update on perfiles
  for each row execute function public.alias_en_comentarios();

-- Recuento de reacciones dentro del comentario (así llega en directo)
create or replace function public.contar_reacciones() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  c uuid := coalesce(new.comentario_id, old.comentario_id);
begin
  update comentarios set reacciones = coalesce((
    select jsonb_object_agg(emoji, n) from (
      select emoji, count(*) as n from reacciones where comentario_id = c group by emoji) x), '{}')
  where id = c;
  return null;
end $$;
drop trigger if exists contar_reacciones on reacciones;
create trigger contar_reacciones after insert or delete on reacciones
  for each row execute function public.contar_reacciones();

-- ---------- Escribir ----------
drop function if exists public.comentar(text, uuid);
create or replace function public.comentar(p_texto text, p_partido uuid default null, p_respuesta_a uuid default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p perfiles;
  padre comentarios;
  t text := btrim(coalesce(p_texto, ''));
  v_torneo uuid;
  v_partido uuid := p_partido;
  v_raiz uuid;
  v_estado text := 'publicado';
  v_motivo text;
  v_id uuid;
  v_email text;
begin
  if uid is null then raise exception 'Tienes que iniciar sesión para comentar'; end if;
  select * into p from perfiles where id = uid;
  if p.id is null then raise exception 'No encontramos tu cuenta. Cierra sesión y vuelve a entrar.'; end if;
  if p.alias is null then raise exception 'Elige un alias para poder comentar'; end if;
  if not puede_participar(uid) then
    raise exception 'Tu alias no está permitido y ha pasado el plazo para cambiarlo. Cámbialo para volver a comentar.';
  end if;
  if p.comentarios_bloqueado then
    raise exception 'Tu cuenta no puede comentar. Si crees que es un error, habla con la organización.';
  end if;
  if char_length(t) < 2 then raise exception 'Escribe algo antes de enviar'; end if;
  if char_length(t) > 300 then raise exception 'Máximo 300 caracteres'; end if;
  if exists (select 1 from comentarios where usuario_id = uid and creado > now() - interval '30 seconds') then
    raise exception 'Espera unos segundos antes de volver a comentar';
  end if;

  if p_respuesta_a is not null then
    select * into padre from comentarios where id = p_respuesta_a;
    if padre.id is null or padre.estado <> 'publicado' then
      raise exception 'Ese comentario ya no está disponible';
    end if;
    v_raiz := coalesce(padre.respuesta_a, padre.id);    -- un solo nivel de respuestas
    v_partido := padre.partido_id;
    v_torneo := padre.torneo_id;
  elsif v_partido is not null then
    select l.torneo_id into v_torneo from partidos pa join ligas l on l.id = pa.liga_id where pa.id = v_partido;
    if v_torneo is null then raise exception 'Ese partido no existe'; end if;
  else
    select id into v_torneo from torneos where activo order by inicio desc limit 1;
  end if;

  if texto_filtrado(t) then
    v_estado := 'pendiente';
    v_motivo := 'Filtro de palabras';
  end if;

  select email into v_email from auth.users where id = uid;

  insert into comentarios (torneo_id, partido_id, respuesta_a, usuario_id, autor, texto, estado, motivo)
  values (v_torneo, v_partido, v_raiz, uid, alias_visible(p.alias, p.alias_vetado_en), t, v_estado, v_motivo)
  returning id into v_id;

  insert into comentarios_autor (comentario_id, usuario_id, alias, nombre, apellidos, email, equipo_id)
  values (v_id, uid, p.alias, p.nombre, p.apellidos, coalesce(v_email, p.email), p.equipo_id);

  return jsonb_build_object('id', v_id, 'estado', v_estado);
end $$;

-- Reaccionar (o quitar la reacción)
create or replace function public.reaccionar(p_id uuid, p_emoji text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Tienes que iniciar sesión para reaccionar'; end if;
  if not puede_participar(auth.uid()) then raise exception 'Elige un alias válido para poder reaccionar'; end if;
  if p_emoji not in ('👏', '⚽', '❤️', '😂') then raise exception 'Reacción no válida'; end if;
  if not exists (select 1 from comentarios where id = p_id and estado = 'publicado') then
    raise exception 'Ese comentario ya no está disponible';
  end if;
  if exists (select 1 from reacciones where comentario_id = p_id and usuario_id = auth.uid() and emoji = p_emoji) then
    delete from reacciones where comentario_id = p_id and usuario_id = auth.uid() and emoji = p_emoji;
  else
    insert into reacciones (comentario_id, usuario_id, emoji) values (p_id, auth.uid(), p_emoji);
  end if;
end $$;

-- El autor (o el personal) lo quita: deja de verse, pero queda guardado
create or replace function public.borrar_comentario(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update comentarios set estado = 'borrado', motivo = coalesce(motivo, 'Borrado por su autor')
  where id = p_id and (usuario_id = auth.uid() or puedo_moderar());
  if not found then raise exception 'No puedes borrar ese comentario'; end if;
end $$;

-- Denunciar: con 3 denuncias de personas distintas se oculta hasta revisarlo
create or replace function public.denunciar(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  if auth.uid() is null then raise exception 'Tienes que iniciar sesión para denunciar'; end if;
  if exists (select 1 from comentarios where id = p_id and usuario_id = auth.uid()) then
    raise exception 'No puedes denunciar tu propio comentario';
  end if;
  insert into denuncias (comentario_id, usuario_id) values (p_id, auth.uid()) on conflict do nothing;
  select count(*) into n from denuncias where comentario_id = p_id;
  if n >= 3 then
    update comentarios set estado = 'pendiente', motivo = n || ' denuncias'
    where id = p_id and estado = 'publicado' and revisado_en is null;
  end if;
end $$;

-- Personal: publicar u ocultar
create or replace function public.moderar_comentario(p_id uuid, p_estado text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not puedo_moderar() then raise exception 'Solo administración o comunicación pueden moderar'; end if;
  if p_estado not in ('publicado', 'oculto') then raise exception 'Estado no válido'; end if;
  update comentarios
     set estado = p_estado,
         motivo = case when p_estado = 'oculto' then 'Ocultado por la organización' else null end,
         revisado_por = auth.uid(), revisado_en = now()
   where id = p_id;
end $$;

-- Personal: impedir (o volver a permitir) que una cuenta comente
create or replace function public.bloquear_comentarios(p_usuario uuid, p_bloquear boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not puedo_moderar() then raise exception 'Solo administración o comunicación pueden bloquear'; end if;
  perform set_config('marbel.sistema', '1', true);
  update perfiles set comentarios_bloqueado = p_bloquear where id = p_usuario;
  perform set_config('marbel.sistema', '0', true);
end $$;

drop function if exists public.bloqueados_comentarios();
create or replace function public.bloqueados_comentarios()
returns table (id uuid, alias text, nombre text, apellidos text, email text)
language sql stable security definer set search_path = public as $$
  select p.id, p.alias, p.nombre, p.apellidos, p.email from perfiles p
  where p.comentarios_bloqueado and puedo_moderar()
  order by p.nombre
$$;

revoke all on function public.comentar(text, uuid, uuid) from public;
grant execute on function public.comentar(text, uuid, uuid), public.reaccionar(uuid, text),
  public.borrar_comentario(uuid), public.denunciar(uuid),
  public.moderar_comentario(uuid, text), public.bloquear_comentarios(uuid, boolean),
  public.bloqueados_comentarios() to authenticated;
grant select on comentarios to anon, authenticated;
grant select on comentarios_autor, denuncias, reacciones to authenticated;
grant select, insert, delete on palabras_filtradas to authenticated;

-- En directo
do $$ begin
  alter publication supabase_realtime add table comentarios;
exception when others then null;
end $$;
