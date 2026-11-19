-- =====================================================================
-- 17 · Varios equipos de un mismo club (B, C...)
-- Un club puede tener más equipos («Granja de Rocamora CF B» y «… C»).
-- Comparten nombre, escudo y localidad: se cambian en el club y pasan
-- solos a sus equipos. Cada equipo se inscribe en sus ligas por separado.
-- Se puede ejecutar más de una vez.
-- =====================================================================

alter table public.equipos add column if not exists nombre_base text;
alter table public.equipos add column if not exists letra text;
alter table public.equipos add column if not exists club_id uuid references public.equipos on delete cascade;

update public.equipos set nombre_base = nombre where nombre_base is null;

alter table public.equipos drop constraint if exists equipos_letra_valida;
alter table public.equipos add constraint equipos_letra_valida
  check (letra is null or letra ~ '^[A-Z]{1,2}$');

-- El nombre que se ve = el del club + la letra. Los equipos copian del club
-- su nombre, escudo y localidad.
create or replace function public.equipos_nombre() returns trigger
language plpgsql as $$
declare c record;
begin
  -- Un equipo de un equipo: se cuelga del club de verdad
  if new.club_id is not null then
    select id, club_id into c from public.equipos where id = new.club_id;
    if c.club_id is not null then new.club_id := c.club_id; end if;
    if new.club_id = new.id then new.club_id := null; end if;
  end if;

  if new.club_id is not null then
    select nombre_base, escudo_url, localidad into c from public.equipos where id = new.club_id;
    new.nombre_base := c.nombre_base;
    new.escudo_url  := c.escudo_url;
    new.localidad   := c.localidad;
  elsif new.nombre_base is null
     or (tg_op = 'UPDATE' and new.nombre is distinct from old.nombre
         and new.nombre_base is not distinct from old.nombre_base) then
    -- Por si alguien cambia directamente «nombre» (versiones antiguas de la app)
    new.nombre_base := new.nombre;
  end if;

  new.letra := nullif(upper(trim(coalesce(new.letra, ''))), '');
  new.nombre := trim(new.nombre_base) || coalesce(' ' || new.letra, '');
  return new;
end $$;

drop trigger if exists equipos_nombre on public.equipos;
create trigger equipos_nombre before insert or update on public.equipos
  for each row execute function public.equipos_nombre();

-- Al cambiar el club, sus equipos se ponen al día
create or replace function public.equipos_al_dia() returns trigger
language plpgsql as $$
begin
  if new.club_id is null and (
       new.nombre_base is distinct from old.nombre_base
    or new.escudo_url  is distinct from old.escudo_url
    or new.localidad   is distinct from old.localidad) then
    update public.equipos set nombre_base = new.nombre_base where club_id = new.id;
  end if;
  return null;
end $$;

drop trigger if exists equipos_al_dia on public.equipos;
create trigger equipos_al_dia after update on public.equipos
  for each row execute function public.equipos_al_dia();

select 'sql_17' as paso, true as hecho;
