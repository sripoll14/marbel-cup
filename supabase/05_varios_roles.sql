-- =====================================================================
-- 05 · Varios roles por persona (p. ej. Mesa de sede + Comunicación).
-- Ejecutar después de 04_completo.sql. Se puede ejecutar más de una vez.
--
-- · Nueva columna perfiles.roles (lista). La columna "rol" se mantiene y
--   guarda el rol principal (admin > mesa > comunicacion > usuario), así que
--   "update perfiles set rol = 'admin' where email = '...'" sigue funcionando.
-- · tengo_rol('comunicacion') comprueba si la persona tiene ese rol,
--   aunque tenga otros.
-- =====================================================================

alter table perfiles add column if not exists roles rol_app[] not null default '{}';

-- Las cuentas que ya tenían un rol lo conservan
update perfiles set roles = array[rol]
where rol <> 'usuario' and roles = '{}';

-- Rol principal a partir de la lista
create or replace function public.rol_principal(r rol_app[]) returns rol_app
language sql immutable as $$
  select case
    when 'admin'        = any(r) then 'admin'::rol_app
    when 'mesa'         = any(r) then 'mesa'::rol_app
    when 'comunicacion' = any(r) then 'comunicacion'::rol_app
    else 'usuario'::rol_app end
$$;

-- ¿La persona conectada tiene este rol?
create or replace function public.tengo_rol(r rol_app) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select r = any(roles) from perfiles where id = auth.uid()), false)
$$;

-- Mantiene "rol" y "roles" de acuerdo, se cambie el que se cambie
create or replace function public.sincronizar_roles() returns trigger
language plpgsql set search_path = public as $$
begin
  if tg_op = 'INSERT' or new.roles is distinct from old.roles then
    -- limpia: sin "usuario" y sin repetidos
    new.roles := coalesce((select array_agg(distinct x order by x)
                           from unnest(new.roles) x where x <> 'usuario'), '{}');
    new.rol := rol_principal(new.roles);
  elsif new.rol is distinct from old.rol then
    new.roles := case when new.rol = 'usuario' then '{}'::rol_app[] else array[new.rol] end;
  end if;
  if not ('mesa' = any(new.roles)) then
    new.sede_id := null;
  end if;
  return new;
end $$;

drop trigger if exists sincronizar_roles on perfiles;
create trigger sincronizar_roles
  before insert or update on perfiles
  for each row execute function public.sincronizar_roles();

-- Nadie puede darse a sí mismo roles o sede (salvo admin o el SQL Editor)
create or replace function public.proteger_perfil() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and mi_rol() <> 'admin'
     and (new.rol is distinct from old.rol
       or new.roles is distinct from old.roles
       or new.sede_id is distinct from old.sede_id) then
    raise exception 'Solo administración puede cambiar roles y sedes';
  end if;
  return new;
end $$;

-- ---------- Permisos que dependen de Comunicación ----------
drop policy if exists "comunicacion gestiona avisos" on avisos;
create policy "comunicacion gestiona avisos" on avisos for all to authenticated
  using (tengo_rol('comunicacion')) with check (tengo_rol('comunicacion'));

drop policy if exists "gestion galeria" on fotos;
create policy "gestion galeria" on fotos for all to authenticated
  using (tengo_rol('admin') or tengo_rol('comunicacion'))
  with check (tengo_rol('admin') or tengo_rol('comunicacion'));

drop policy if exists "marbel sube galeria" on storage.objects;
create policy "marbel sube galeria" on storage.objects for insert to authenticated
  with check (bucket_id = 'galeria' and (public.tengo_rol('admin') or public.tengo_rol('comunicacion')));
drop policy if exists "marbel borra galeria" on storage.objects;
create policy "marbel borra galeria" on storage.objects for delete to authenticated
  using (bucket_id = 'galeria' and (public.tengo_rol('admin') or public.tengo_rol('comunicacion')));

-- ---------- Permisos de la Mesa de sede ----------
drop policy if exists "mesa actualiza su sede" on partidos;
create policy "mesa actualiza su sede" on partidos for update to authenticated
  using (tengo_rol('mesa') and sede_id = mi_sede())
  with check (tengo_rol('mesa') and sede_id = mi_sede());

drop policy if exists "mesa mete goles de su sede" on goles;
create policy "mesa mete goles de su sede" on goles for insert to authenticated
  with check (tengo_rol('mesa') and exists (
    select 1 from partidos p where p.id = partido_id and p.sede_id = mi_sede()));

drop policy if exists "mesa borra goles de su sede" on goles;
create policy "mesa borra goles de su sede" on goles for delete to authenticated
  using (tengo_rol('mesa') and exists (
    select 1 from partidos p where p.id = partido_id and p.sede_id = mi_sede()));

drop policy if exists "mesa publica avisos" on avisos;
create policy "mesa publica avisos" on avisos for insert to authenticated
  with check (tengo_rol('mesa') and ambito in ('sede', 'equipo'));
