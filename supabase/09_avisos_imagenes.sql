-- =====================================================================
-- 09 · Imágenes en los avisos (hasta 4 por aviso: escudos, carteles...).
-- Ejecutar después de 08. Se puede ejecutar más de una vez.
-- =====================================================================

alter table avisos add column if not exists imagenes text[] not null default '{}';
alter table avisos drop constraint if exists avisos_max_imagenes;
alter table avisos add constraint avisos_max_imagenes check (coalesce(array_length(imagenes, 1), 0) <= 4);

-- Carpeta pública para las imágenes de los avisos
insert into storage.buckets (id, name, public) values ('avisos', 'avisos', true)
on conflict (id) do nothing;

-- Suben y borran quienes pueden publicar avisos
drop policy if exists "marbel sube avisos" on storage.objects;
create policy "marbel sube avisos" on storage.objects for insert to authenticated
  with check (bucket_id = 'avisos' and (tengo_rol('admin') or tengo_rol('comunicacion') or tengo_rol('mesa')));
drop policy if exists "marbel borra avisos" on storage.objects;
create policy "marbel borra avisos" on storage.objects for delete to authenticated
  using (bucket_id = 'avisos' and (tengo_rol('admin') or tengo_rol('comunicacion') or tengo_rol('mesa')));
drop policy if exists "marbel ve avisos" on storage.objects;
create policy "marbel ve avisos" on storage.objects for select to authenticated
  using (bucket_id = 'avisos' and (tengo_rol('admin') or tengo_rol('comunicacion') or tengo_rol('mesa')));
