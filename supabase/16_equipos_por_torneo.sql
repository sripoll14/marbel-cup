-- =====================================================================
-- 16 · Equipos de cada torneo
-- Un club se puede apuntar a un torneo aunque todavía no se sepa su liga.
-- Cada torneo enseña solo sus equipos (los apuntados y los de sus ligas).
-- Se puede ejecutar más de una vez.
-- =====================================================================

create table if not exists public.torneo_equipos (
  torneo_id uuid not null references public.torneos on delete cascade,
  equipo_id uuid not null references public.equipos on delete cascade,
  creado    timestamptz not null default now(),
  primary key (torneo_id, equipo_id)
);

alter table public.torneo_equipos enable row level security;
drop policy if exists "lectura publica" on public.torneo_equipos;
create policy "lectura publica" on public.torneo_equipos for select using (true);
drop policy if exists "admin gestiona" on public.torneo_equipos;
create policy "admin gestiona" on public.torneo_equipos for all to authenticated
  using (public.tengo_rol('admin')) with check (public.tengo_rol('admin'));
grant select on public.torneo_equipos to anon, authenticated;
grant insert, update, delete on public.torneo_equipos to authenticated;

-- 1. Los clubes que ya están en una liga, apuntados a ese torneo
insert into public.torneo_equipos (torneo_id, equipo_id)
select distinct l.torneo_id, le.equipo_id
  from public.liga_equipos le join public.ligas l on l.id = le.liga_id
on conflict do nothing;

-- 2. Todos los clubes que hay ahora son del IV Torneo Navideño
--    (menos los que solo estén en ligas de otro torneo)
insert into public.torneo_equipos (torneo_id, equipo_id)
select t.id, e.id
  from public.torneos t cross join public.equipos e
 where t.nombre ilike '%navideño%'
   and not exists (
     select 1 from public.liga_equipos le join public.ligas l on l.id = le.liga_id
      where le.equipo_id = e.id and l.torneo_id <> t.id)
on conflict do nothing;

-- 3. El Navideño deja de enseñar «todos los clubes»: solo los suyos
update public.torneos
   set proyecto = proyecto - 'equipos'
 where nombre ilike '%navideño%' and proyecto ? 'equipos';

select 'sql_16' as paso, true as hecho,
       (select count(*) from public.torneo_equipos te join public.torneos t on t.id = te.torneo_id
         where t.nombre ilike '%navideño%') as equipos_del_navideno;
