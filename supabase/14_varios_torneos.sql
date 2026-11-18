-- =====================================================================
-- 14 · Varios torneos a la vez, cada uno con su proyecto (actualización 1).
-- Ejecutar después de 13. Se puede ejecutar más de una vez.
-- Es compatible con la web que hay publicada ahora: se puede ejecutar antes
-- de subir la actualización a GitHub.
--
-- · Cada torneo puede estar «en curso» (activo) y «publicado» por separado.
--   En la web salen, en «Torneos actuales», los que estén en curso Y publicados.
-- · Todo el contenido de un torneo (portada, información, horarios, precios,
--   preguntas...) es su PROYECTO: un archivo .json que se sube desde el panel
--   (ver PROYECTOS.md). Aquí se le pone su proyecto al IV Torneo Navideño,
--   como si se hubiera subido el archivo proyectos/iv-torneo-navideno.json.
-- · La Porra y las opiniones van por torneo.
-- =====================================================================

alter table torneos add column if not exists proyecto jsonb;
alter table torneos add column if not exists sedes uuid[] not null default '{}';

-- El IV Torneo Navideño: su proyecto y sus 4 sedes (solo si aún no tiene proyecto)
update torneos t
   set proyecto = '{"formato": "marbel-cup-torneo", "version": 1, "nombre": "IV Torneo Navideño 26-27", "fechas": "26-27 dic · 2-3 ene", "inicio": "2026-12-26T09:00:00+01:00", "inscripcion_hasta": "2026-12-20", "jornadas": ["2026-12-26", "2026-12-27", "2027-01-02", "2027-01-03"], "horas": {"desde": "09:00", "hasta": "21:00"}, "sedes": ["Albatera", "Granja de Rocamora", "Rafal", "Bigastro"], "equipos": "todos", "portada": {"etiqueta": "Fútbol base · F8 y F11 · Masculino y femenino", "lema": "Fútbol, diversión y competición en un torneo único. Tú eliges el nivel y la categoría: cuatro sedes en la Vega Baja, a 10–15 minutos entre ellas.", "donde": "Vega Baja · 4 sedes", "titulo_info": ["IV Torneo", "Navideño"], "datos": [["Fechas", "26–27 dic · 2–3 ene"], ["Sedes", "4 en la Vega Baja"], ["Modalidades", "Fútbol 8 y 11"], ["Partidos", "Mínimo 4 por equipo"]], "inscripcion": "Inscripción hasta el 20 de diciembre · plazas limitadas"}, "inicio_bloques": [{"tipo": "niveles", "etiqueta": "3 niveles + femenino", "titulo": "Tú eliges el nivel", "subtitulo": "En masculino, tres niveles en cada categoría y año; en femenino, nivel único. Mínimo cuatro partidos asegurados para cada equipo.", "niveles": [["iniciacion", "Para equipos que empiezan"], ["medio", "Competición equilibrada"], ["elite", "Máximo nivel competitivo"], ["femenino", "Sub 12 e Infantil F8"]], "listas": [{"titulo": "Masculino", "items": ["Prebenjamín 1º y 2º año", "Benjamín 1º y 2º año", "Alevín 1º y 2º año", "Infantil 1º y 2º año (mixto) · F11"]}, {"titulo": "Femenino", "items": ["Sub 12", "Infantil · F8"]}, {"titulo": "¿Quién puede participar?", "items": ["Equipos federados y no federados", "Escuelas", "Ligas asociadas (Brave, Faler…)", "Academias"], "prefijo": "→ "}]}, {"tipo": "mapa_sedes", "etiqueta": "Vega Baja · Alicante", "titulo": "4 sedes, 10–15 min entre ellas", "subtitulo": "Amplía la Vega Baja y pasa el ratón (o toca) una chincheta para ver la sede, qué se juega allí y cómo llegar."}], "info_bloques": [{"tipo": "horario", "titulo": "Qué se juega, cuándo y dónde", "nota": "Dos sedes con la misma categoría «todo el día» = esa categoría juega repartida entre las dos. Toca un nivel para resaltar solo sus partidos.", "dias": [{"dia": "2026-12-26", "sedes": [[{"categoria": "Infantil F11", "niveles": ["iniciacion", "medio"], "franja": "todo"}], [{"categoria": "Infantil F11", "niveles": ["iniciacion", "medio"], "franja": "todo"}], [{"categoria": "Benjamín 1º año", "niveles": ["medio"], "franja": "manana"}, {"categoria": "Benjamín 2º año", "niveles": ["medio"], "franja": "tarde"}], [{"categoria": "Sub 12", "niveles": ["femenino"], "franja": "manana"}, {"categoria": "F8 Infantil", "niveles": ["femenino"], "franja": "tarde"}]]}, {"dia": "2026-12-27", "sedes": [[], [{"categoria": "Prebenjamín 1º año", "niveles": ["medio"], "franja": "manana"}, {"categoria": "Prebenjamín 2º año", "niveles": ["medio"], "franja": "tarde"}], [{"categoria": "Prebenjamín 1º año", "niveles": ["iniciacion"], "franja": "manana"}, {"categoria": "Prebenjamín 2º año", "niveles": ["iniciacion"], "franja": "tarde"}], [{"categoria": "Prebenjamín 1º año", "niveles": ["elite"], "franja": "manana"}, {"categoria": "Prebenjamín 2º año", "niveles": ["elite"], "franja": "tarde"}]]}, {"dia": "2027-01-02", "sedes": [[{"categoria": "Alevín 1º año", "niveles": ["medio"], "franja": "manana"}, {"categoria": "Alevín 2º año", "niveles": ["medio"], "franja": "tarde"}], [{"categoria": "Alevín 1º año", "niveles": ["elite"], "franja": "manana"}, {"categoria": "Alevín 2º año", "niveles": ["elite"], "franja": "tarde"}], [], [{"categoria": "Alevín 1º año", "niveles": ["iniciacion"], "franja": "manana"}, {"categoria": "Alevín 2º año", "niveles": ["iniciacion"], "franja": "tarde"}]]}, {"dia": "2027-01-03", "sedes": [[{"categoria": "Benjamín 1º año", "niveles": ["iniciacion"], "franja": "manana"}, {"categoria": "Benjamín 2º año", "niveles": ["iniciacion"], "franja": "tarde"}], [{"categoria": "Infantil F11", "niveles": ["medio", "elite"], "franja": "todo"}], [{"categoria": "Infantil F11", "niveles": ["medio", "elite"], "franja": "todo"}], [{"categoria": "Benjamín 1º año", "niveles": ["elite"], "franja": "manana"}, {"categoria": "Benjamín 2º año", "niveles": ["elite"], "franja": "tarde"}]]}]}, {"tipo": "sedes", "titulo": "Las sedes"}, {"tipo": "lista_iconos", "titulo": "Qué incluye", "items": [["calendario", "Mínimo 4 partidos asegurados"], ["silbato", "Árbitros federados"], ["balon", "Balones federados"], ["agua", "Fruta y agua durante todo el torneo"], ["musica", "Speaker y animación musical"], ["camara", "Servicio de fotografía"], ["micro", "Entrevistas a jugadores y entrenadores"], ["seguro", "Seguro de R.C. y de lesiones"], ["pulsera", "Pulsera acreditativa del torneo"], ["medalla", "Medallas a los 1º, 2º y 3º"], ["trofeo", "Trofeo a todos los equipos"], ["estrella", "Gala final para todos los equipos"]], "destacados": [{"icono": "medalla", "texto": "Los 3 primeros: trofeo por equipo y medalla individual. El resto: trofeo por equipo y obsequio individual.", "estilo": "relleno"}, {"icono": "fiesta", "texto": "Todos los equipos pasan por la ceremonia final de entrega de trofeos.", "estilo": "borde"}]}, {"tipo": "equipos_destacados", "etiqueta": "Cabezas de serie confirmados", "titulo": "Categoría Élite", "equipos": ["F.C. Cartagena SAD", "Albacete Balompié", null, null, null, null]}, {"tipo": "precios", "titulo": "Precios y cómo participar", "pastilla": "Plazas limitadas", "precios": [["Fútbol 8", "200€", "por equipo"], ["Fútbol 11", "250€", "por equipo"]], "pasos": [["Reserva del equipo", "Con una cuota de 100€."], ["Resto del pago", "Antes del 10 de diciembre."], ["Inscripción rellenada", "Entregarla antes del 20 de diciembre."]], "aviso": "El importe de la reserva no se devuelve. Las plazas no se guardan sin el pago.", "botones": true}, {"tipo": "preguntas", "titulo": "Preguntas frecuentes", "items": [["¿Puedo elegir el nivel de mi equipo?", "Sí. Al inscribiros elegís categoría y nivel (iniciación, medio o élite). La organización puede reubicar a un equipo si el nivel no encaja."], ["¿Qué pasa si hay empate a puntos en la liguilla?", "Si empatan DOS equipos:\n1. El enfrentamiento directo entre ambos.\n2. El equipo con más goles a favor.\n3. El equipo con menos goles en contra.\n4. Una tanda de 3 penaltis por equipo.\n\nSi empatan TRES equipos:\n1. Pasa el equipo (o los equipos) con más goles a favor.\n2. El enfrentamiento directo.\n3. Si siguen empatados dos equipos, pasa el que haya recibido menos goles.\n4. Si sigue el empate, por sorteo."], ["¿Cuántos partidos jugamos como mínimo?", "Cada equipo juega 4 partidos en su liga. Los 4 primeros pasan a semifinales (1º vs 4º y 2º vs 3º). Los ganadores juegan la final y los perdedores, el partido por el 3er y 4º puesto."], ["¿Cómo me entero de horarios y cambios de campo?", "En el calendario de la web y en la app. Si sigues a tu equipo (★), en Avisos verás al momento cualquier cambio."], ["¿Qué pasa si reservo y luego no podemos ir?", "El importe de la reserva (100€) no se devuelve. Para cualquier otro caso, consultad con la organización."], ["¿Hay sitio para aparcar y algo para comer?", "Sí. Las cuatro sedes tienen cantina, zona de aparcamiento y espacios alternos."], ["¿Se publican datos de los jugadores?", "No. No publicamos plantillas, nombres, edades ni fotos de perfil de los jugadores: en resultados, estadísticas y notificaciones solo salen los equipos. Las fotos de la galería están autorizadas por los clubes."]]}, {"tipo": "opinion", "etiqueta": "Cuéntanos qué te ha parecido", "titulo": "Déjanos tu opinión"}]}'::jsonb,
       sedes = case when t.sedes = '{}'
                    then (select coalesce(array_agg(s.id order by s.orden), '{}') from sedes s
                           where s.nombre in ('Albatera', 'Granja de Rocamora', 'Rafal', 'Bigastro'))
                    else t.sedes end
 where t.proyecto is null and t.nombre ilike '%navide%';

-- ---------- La Porra: ranking de un torneo ----------
create or replace function public.ranking_torneo(p_torneo uuid, p_liga uuid default null)
returns table (pos int, nombre text, equipo text, puntos int, soy_yo boolean)
language sql stable security definer set search_path = public as $$
  with liga_acabada as (
    select l.id as liga_id from ligas l
     where exists (select 1 from partidos x where x.liga_id = l.id and x.fase = 'liga')
       and not exists (select 1 from partidos x where x.liga_id = l.id and x.fase = 'liga' and x.estado <> 'finalizado')
  ), pr as (
    select p.*, coalesce(l.final_en, l.id) as liga_final
      from predicciones p join ligas l on l.id = p.liga_id
     where (p_liga is null or p.liga_id = p_liga)
       and (p_torneo is null or l.torneo_id = p_torneo)
  ), puntos as (
    select pr.usuario_id, pr.liga_id, pr.tipo, pr.equipo_id,
      case pr.tipo
        when 'campeon_liga' then (select 3 from clasificacion c join liga_acabada a using (liga_id)
                                   where c.liga_id = pr.liga_id and c.pos = 1 and c.equipo_id = pr.equipo_id)
        when 'fuera_semis'  then (select 2 from clasificacion c join liga_acabada a using (liga_id)
                                   where c.liga_id = pr.liga_id and c.pos = 5 and c.equipo_id = pr.equipo_id)
        when 'finalista'    then (select 4 from partidos f where f.liga_id = pr.liga_final and f.fase = 'final'
                                   and pr.equipo_id in (f.local_id, f.visitante_id))
        when 'campeon'      then (select 8 from partidos f where f.liga_id = pr.liga_final and f.fase = 'final'
                                   and ganador_partido(f) = pr.equipo_id)
        when 'tercer_puesto' then (select 2 from partidos f where f.liga_id = pr.liga_final and f.fase = 'tercer_puesto'
                                   and ganador_partido(f) = pr.equipo_id)
      end as pts
    from pr
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

grant execute on function public.ranking_torneo(uuid, uuid) to anon, authenticated;

-- ---------- Opiniones: a qué torneo van ----------
create or replace function public.opinar(p_texto text, p_torneo uuid) returns void
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
  values (coalesce((select id from torneos where id = p_torneo),
                   (select id from torneos where activo order by inicio desc limit 1)),
          uid, coalesce(p.alias, btrim(p.nombre || ' ' || coalesce(left(p.apellidos, 1) || '.', ''))), t,
          case when texto_filtrado(t) then 'Lleva palabras del filtro' end)
  returning id into v_id;

  insert into comentarios_autor (comentario_id, usuario_id, alias, nombre, apellidos, email, equipo_id)
  values (v_id, uid, p.alias, p.nombre, p.apellidos, coalesce(v_email, p.email), p.equipo_id);
end $$;

revoke all on function public.opinar(text, uuid) from public;
grant execute on function public.opinar(text, uuid) to authenticated;
