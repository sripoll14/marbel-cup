-- =====================================================================
-- 10 · «Déjanos tu opinión» (privado) y grupos dentro de una liga.
-- Ejecutar después de 09. Se puede ejecutar más de una vez.
--
-- OPINIONES
-- · Los comentarios dejan de ser públicos: cada persona escribe su opinión
--   y SOLO administración la lee (Panel → Opiniones).
-- · Se quitan el chat de los partidos, las respuestas, las reacciones y las
--   denuncias. Lo ya escrito se conserva (solo lo ve administración).
-- · El alias, su veto y el filtro de palabras siguen igual (para La Porra).
--
-- GRUPOS
-- · Una misma categoría y nivel puede tener varios grupos (A, B, C...), y
--   cada grupo funciona como una liga aparte: su calendario, su
--   clasificación, su fase final y su porra.
-- · Donde no hay grupos todo sigue igual (una sola liga, sin letra).
-- =====================================================================

-- ---------- Opiniones: solo administración ----------
create or replace function public.puedo_ver_opiniones() returns boolean
language sql stable security definer set search_path = public as $$
  select tengo_rol('admin')
$$;

drop policy if exists "ver comentarios" on comentarios;
drop policy if exists "ver opiniones" on comentarios;
create policy "ver opiniones" on comentarios for select to authenticated
  using (usuario_id = auth.uid() or puedo_ver_opiniones());
revoke select on comentarios from anon;

drop policy if exists "personal ve autores" on comentarios_autor;
create policy "personal ve autores" on comentarios_autor for select to authenticated
  using (puedo_ver_opiniones());

drop policy if exists "ver denuncias" on denuncias;
create policy "ver denuncias" on denuncias for select to authenticated using (puedo_ver_opiniones());

-- Ya no se emiten en directo (no son públicas)
do $$ begin
  alter publication supabase_realtime drop table comentarios;
exception when others then null;
end $$;

-- Lo que ya no se usa
drop function if exists public.comentar(text, uuid, uuid);
drop function if exists public.reaccionar(uuid, text);
drop function if exists public.denunciar(uuid);

-- Enviar una opinión (hace falta cuenta; no hace falta alias)
create or replace function public.opinar(p_texto text) returns void
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p perfiles;
  t text := btrim(coalesce(p_texto, ''));
  v_id uuid;
  v_email text;
begin
  if uid is null then raise exception 'Tienes que iniciar sesión para dejar tu opinión'; end if;
  select * into p from perfiles where id = uid;
  if p.id is null then raise exception 'No encontramos tu cuenta. Cierra sesión y vuelve a entrar.'; end if;
  if p.comentarios_bloqueado then
    raise exception 'Tu cuenta no puede enviar opiniones. Si crees que es un error, habla con la organización.';
  end if;
  if char_length(t) < 2 then raise exception 'Escribe algo antes de enviar'; end if;
  if char_length(t) > 1000 then raise exception 'Máximo 1000 caracteres'; end if;
  if exists (select 1 from comentarios where usuario_id = uid and creado > now() - interval '30 seconds') then
    raise exception 'Espera unos segundos antes de enviar otra';
  end if;

  select email into v_email from auth.users where id = uid;

  insert into comentarios (torneo_id, usuario_id, autor, texto, motivo)
  values ((select id from torneos where activo order by inicio desc limit 1),
          uid, coalesce(p.alias, btrim(p.nombre || ' ' || coalesce(left(p.apellidos, 1) || '.', ''))), t,
          case when texto_filtrado(t) then 'Lleva palabras del filtro' end)
  returning id into v_id;

  insert into comentarios_autor (comentario_id, usuario_id, alias, nombre, apellidos, email, equipo_id)
  values (v_id, uid, p.alias, p.nombre, p.apellidos, coalesce(v_email, p.email), p.equipo_id);
end $$;

-- Administración: archivar ('oculto') o volver a dejar como nueva ('publicado')
create or replace function public.moderar_comentario(p_id uuid, p_estado text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not puedo_ver_opiniones() then raise exception 'Solo administración puede gestionar las opiniones'; end if;
  if p_estado not in ('publicado', 'oculto') then raise exception 'Estado no válido'; end if;
  update comentarios
     set estado = p_estado, revisado_por = auth.uid(), revisado_en = now()
   where id = p_id;
end $$;

create or replace function public.borrar_comentario(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update comentarios set estado = 'borrado', motivo = coalesce(motivo, 'Borrado')
  where id = p_id and (usuario_id = auth.uid() or puedo_ver_opiniones());
  if not found then raise exception 'No puedes borrar esa opinión'; end if;
end $$;

create or replace function public.bloquear_comentarios(p_usuario uuid, p_bloquear boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not puedo_ver_opiniones() then raise exception 'Solo administración puede bloquear'; end if;
  perform set_config('marbel.sistema', '1', true);
  update perfiles set comentarios_bloqueado = p_bloquear where id = p_usuario;
  perform set_config('marbel.sistema', '0', true);
end $$;

drop function if exists public.bloqueados_comentarios();
create or replace function public.bloqueados_comentarios()
returns table (id uuid, alias text, nombre text, apellidos text, email text)
language sql stable security definer set search_path = public as $$
  select p.id, p.alias, p.nombre, p.apellidos, p.email from perfiles p
  where p.comentarios_bloqueado and puedo_ver_opiniones()
  order by p.nombre
$$;

revoke all on function public.opinar(text) from public;
grant execute on function public.opinar(text), public.moderar_comentario(uuid, text),
  public.borrar_comentario(uuid), public.bloquear_comentarios(uuid, boolean),
  public.bloqueados_comentarios() to authenticated;

-- ---------- Grupos ----------
alter table ligas add column if not exists grupo text;
alter table ligas drop constraint if exists ligas_grupo_letra;
alter table ligas add constraint ligas_grupo_letra check (grupo is null or grupo ~ '^[A-Z]$');
alter table ligas drop constraint if exists ligas_torneo_id_categoria_id_nivel_id_key;
create unique index if not exists ligas_unica on ligas (torneo_id, categoria_id, nivel_id, coalesce(grupo, ''));

-- Añadir un grupo a una categoría y nivel. Si solo había una liga sin
-- letra, pasa a ser el grupo A y la nueva el B. Devuelve la liga nueva.
create or replace function public.nuevo_grupo(p_torneo uuid, p_categoria uuid, p_nivel text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_letra text;
  v_id uuid;
begin
  if not tengo_rol('admin') then raise exception 'Solo administración puede crear grupos'; end if;
  perform 1 from ligas where torneo_id = p_torneo and categoria_id = p_categoria and nivel_id = p_nivel for update;

  update ligas set grupo = 'A'
   where torneo_id = p_torneo and categoria_id = p_categoria and nivel_id = p_nivel and grupo is null;

  select coalesce(chr(ascii(max(grupo)) + 1), 'A') into v_letra
    from ligas where torneo_id = p_torneo and categoria_id = p_categoria and nivel_id = p_nivel;
  if v_letra > 'Z' then raise exception 'No caben más grupos'; end if;

  insert into ligas (torneo_id, categoria_id, nivel_id, grupo)
  values (p_torneo, p_categoria, p_nivel, v_letra)
  returning id into v_id;
  return v_id;
end $$;

-- Quitar un grupo vacío (sin equipos ni partidos). Si solo queda uno, pierde la letra.
create or replace function public.borrar_grupo(p_liga uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  l ligas;
begin
  if not tengo_rol('admin') then raise exception 'Solo administración puede quitar grupos'; end if;
  select * into l from ligas where id = p_liga;
  if l.id is null then raise exception 'Ese grupo no existe'; end if;
  if exists (select 1 from liga_equipos where liga_id = p_liga) then
    raise exception 'Ese grupo tiene equipos. Pásalos a otro grupo antes de quitarlo.';
  end if;
  if exists (select 1 from partidos where liga_id = p_liga) then
    raise exception 'Ese grupo tiene partidos. Bórralos antes de quitarlo.';
  end if;
  delete from ligas where id = p_liga;
  -- Si solo queda una liga de esa categoría y nivel, vuelve a no tener letra
  update ligas set grupo = null
   where torneo_id = l.torneo_id and categoria_id = l.categoria_id and nivel_id = l.nivel_id
     and (select count(*) from ligas x
           where x.torneo_id = l.torneo_id and x.categoria_id = l.categoria_id and x.nivel_id = l.nivel_id) = 1;
end $$;

grant execute on function public.nuevo_grupo(uuid, uuid, text), public.borrar_grupo(uuid) to authenticated;
