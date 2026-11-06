-- =====================================================================
-- 06 · Notificaciones push (con la app cerrada).
-- Ejecutar después de 05. Se puede ejecutar más de una vez.
--
-- ANTES DE EJECUTAR: cambia TU-PROYECTO en la línea marcada con  <<<
-- por la dirección de tu proyecto (la misma SUPABASE_URL de env.json).
--
-- Cómo funciona:
--  · Cada móvil que activa las notificaciones guarda aquí su "suscripción"
--    (anónima: solo la dirección de push y los equipos que sigue).
--  · Cuando un partido empieza, hay gol, termina o cambia de hora/campo,
--    o se publica un aviso, se apunta en cola_push y se llama a la función
--    "notificar", que es la que envía.
--  · Cada 5 minutos se apuntan los partidos que empiezan en 15 minutos y el
--    cierre de La Porra.
-- =====================================================================

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

-- ---------- Configuración ----------
create table if not exists config_push (
  clave text primary key,
  valor text not null
);
alter table config_push enable row level security; -- nadie desde la app

insert into config_push (clave, valor)
values ('url_supabase', 'https://pdgmznkinacnbocoygmr.supabase.co')   -- <<< cambia esto
on conflict (clave) do update set valor = excluded.valor
  where excluded.valor not like '%TU-PROYECTO%'; -- si se vuelve a ejecutar sin cambiar, no borra la buena

-- ---------- Suscripciones (una por móvil/navegador) ----------
create table if not exists suscripciones_push (
  endpoint    text primary key,
  p256dh      text not null,
  auth        text not null,
  equipos     uuid[]    not null default '{}',
  prefs       boolean[] not null default '{true,true,true,true,false}',
  creada      timestamptz not null default now(),
  actualizada timestamptz not null default now()
);
alter table suscripciones_push enable row level security; -- solo mediante las funciones de abajo

-- La app guarda o actualiza su suscripción (no hace falta cuenta)
create or replace function public.guardar_suscripcion(
  p_endpoint text, p_p256dh text, p_auth text, p_equipos uuid[], p_prefs boolean[]
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_endpoint !~ '^https://' or length(p_endpoint) > 1000
     or length(p_p256dh) > 200 or length(p_auth) > 100
     or coalesce(array_length(p_equipos, 1), 0) > 100 then
    raise exception 'Suscripción no válida';
  end if;
  insert into suscripciones_push (endpoint, p256dh, auth, equipos, prefs)
  values (p_endpoint, p_p256dh, p_auth, coalesce(p_equipos, '{}'), coalesce(p_prefs, '{true,true,true,true,false}'))
  on conflict (endpoint) do update
    set p256dh = excluded.p256dh, auth = excluded.auth,
        equipos = excluded.equipos, prefs = excluded.prefs, actualizada = now();
end $$;

create or replace function public.borrar_suscripcion(p_endpoint text) returns void
language sql security definer set search_path = public as $$
  delete from suscripciones_push where endpoint = p_endpoint
$$;

grant execute on function public.guardar_suscripcion(text, text, text, uuid[], boolean[]) to anon, authenticated;
grant execute on function public.borrar_suscripcion(text) to anon, authenticated;

-- ---------- Cola de envíos ----------
create table if not exists cola_push (
  id      bigserial primary key,
  tipo    text not null,
  datos   jsonb not null default '{}',
  creado  timestamptz not null default now(),
  enviado timestamptz
);
alter table cola_push enable row level security;
create index if not exists cola_push_pendientes on cola_push (id) where enviado is null;

-- Avisa a la función "notificar" de que hay cosas en cola
create or replace function public.llamar_notificar() returns void
language plpgsql security definer set search_path = public, extensions as $$
declare
  u text := (select valor from config_push where clave = 'url_supabase');
begin
  if u is null or u like '%TU-PROYECTO%' then
    return; -- aún sin configurar
  end if;
  perform net.http_post(
    url := rtrim(u, '/') || '/functions/v1/notificar',
    body := '{}'::jsonb,
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
exception when others then
  raise warning 'No se ha podido llamar a notificar: %', sqlerrm; -- nunca bloquear un resultado por esto
end $$;

create or replace function public.encolar_push(p_tipo text, p_datos jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from suscripciones_push) then
    return; -- nadie a quien avisar
  end if;
  insert into cola_push (tipo, datos) values (p_tipo, p_datos);
  perform llamar_notificar();
end $$;

-- ---------- Partidos: empieza, gol, final, cambio de hora/campo ----------
create or replace function public.push_partido() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  d jsonb;
begin
  if new.local_id is null or new.visitante_id is null then
    return new;
  end if;
  d := jsonb_build_object(
    'partido_id', new.id, 'local_id', new.local_id, 'visitante_id', new.visitante_id,
    'goles_local', new.goles_local, 'goles_visitante', new.goles_visitante,
    'penaltis_local', new.penaltis_local, 'penaltis_visitante', new.penaltis_visitante,
    'sede_id', new.sede_id, 'campo', new.campo,
    'hora_real', new.hora + make_interval(mins => coalesce(new.retraso_min, 0)));

  if new.estado = 'en_juego' and old.estado is distinct from 'en_juego' then
    perform encolar_push('empieza', d);
  end if;

  if new.estado = 'finalizado' and old.estado is distinct from 'finalizado' then
    perform encolar_push('final', d);
  elsif new.estado = 'en_juego' then
    if coalesce(new.goles_local, 0) > coalesce(old.goles_local, 0) then
      perform encolar_push('gol', d || jsonb_build_object('gol_de', new.local_id));
    end if;
    if coalesce(new.goles_visitante, 0) > coalesce(old.goles_visitante, 0) then
      perform encolar_push('gol', d || jsonb_build_object('gol_de', new.visitante_id));
    end if;
  end if;

  if new.estado = 'programado' and (
       new.hora is distinct from old.hora
    or new.sede_id is distinct from old.sede_id
    or new.campo is distinct from old.campo) then
    perform encolar_push('cambio', d);
  end if;
  return new;
end $$;

drop trigger if exists push_partido on partidos;
create trigger push_partido
  after update on partidos
  for each row execute function public.push_partido();

-- ---------- Avisos de la organización ----------
create or replace function public.push_aviso() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform encolar_push('aviso', jsonb_build_object(
    'aviso_id', new.id, 'texto', new.texto, 'ambito', coalesce(new.ambito, 'todos'),
    'ambito_ref', new.ambito_ref, 'automatico', coalesce(new.automatico, false)));
  return new;
end $$;

drop trigger if exists push_aviso on avisos;
create trigger push_aviso
  after insert on avisos
  for each row execute function public.push_aviso();

-- ---------- Recordatorios (cada 5 minutos) ----------
create table if not exists push_recordados (
  clave  text primary key,          -- 'pronto:<partido>' o 'porra:<liga>'
  creado timestamptz not null default now()
);
alter table push_recordados enable row level security;

create or replace function public.encolar_recordatorios() returns void
language plpgsql security definer set search_path = public as $$
declare
  p record;
  cierre timestamptz;
begin
  if not exists (select 1 from suscripciones_push) then
    return;
  end if;

  -- Partidos que empiezan en los próximos 15 minutos
  for p in
    select pa.*, pa.hora + make_interval(mins => coalesce(pa.retraso_min, 0)) as hora_real
    from partidos pa
    where pa.estado = 'programado'
      and pa.local_id is not null and pa.visitante_id is not null
      and pa.hora + make_interval(mins => coalesce(pa.retraso_min, 0)) between now() and now() + interval '15 minutes'
      and not exists (select 1 from push_recordados r where r.clave = 'pronto:' || pa.id)
  loop
    insert into push_recordados (clave) values ('pronto:' || p.id);
    insert into cola_push (tipo, datos) values ('pronto', jsonb_build_object(
      'partido_id', p.id, 'local_id', p.local_id, 'visitante_id', p.visitante_id,
      'sede_id', p.sede_id, 'campo', p.campo, 'hora_real', p.hora_real));
  end loop;

  -- La Porra: una hora antes del primer cierre de cada día
  select min(c.cierre) into cierre
  from (
    select l.id, min(pa.hora) - interval '30 minutes' as cierre
    from ligas l
    join torneos t on t.id = l.torneo_id and t.activo
    join partidos pa on pa.liga_id = l.id
    group by l.id
  ) c
  where c.cierre between now() and now() + interval '60 minutes'
    and not exists (select 1 from push_recordados r
                    where r.clave = 'porra:' || to_char(c.cierre at time zone 'Europe/Madrid', 'YYYY-MM-DD'));
  if cierre is not null then
    insert into push_recordados (clave) values ('porra:' || to_char(cierre at time zone 'Europe/Madrid', 'YYYY-MM-DD'));
    insert into cola_push (tipo, datos) values ('porra', jsonb_build_object('cierre', cierre));
  end if;

  if exists (select 1 from cola_push where enviado is null) then
    perform llamar_notificar();
  end if;

  -- Limpieza: lo enviado hace más de 7 días
  delete from cola_push where enviado < now() - interval '7 days';
end $$;

-- Programar cada 5 minutos (si ya existía, se sustituye)
do $$ begin
  perform cron.unschedule('marbel-recordatorios');
exception when others then null;
end $$;
select cron.schedule('marbel-recordatorios', '*/5 * * * *', $$select public.encolar_recordatorios()$$);
