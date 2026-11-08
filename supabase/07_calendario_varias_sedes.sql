-- =====================================================================
-- 07 · Calendario en varias sedes y varios días.
-- Ejecutar después de 06. Se puede ejecutar más de una vez.
--
-- Una liga puede jugarse en varias "franjas" (un día, de una hora a otra,
-- en una o varias sedes a la vez). Por ejemplo, Infantil F11 · Medio:
--   · Sáb 26, 9:00–21:00, Albatera (2 campos) + Granja (2 campos)
--   · Dom 3,  9:00–21:00, Granja (2 campos) + Rafal (2 campos)
--
-- Reglas al repartir los partidos:
--   · Ningún equipo juega dos partidos a la vez.
--   · Se intenta que nadie juegue dos partidos seguidos.
--   · Se intenta que un equipo no cambie de sede dentro del mismo día.
--   · Respeta los campos que ya ocupan otras ligas en esa sede y hora.
-- =====================================================================

-- Primer campo libre en una sede a partir de una hora (para la fase final)
create or replace function public.hueco_libre(
  p_sede uuid, p_campos int, p_desde timestamptz, p_minutos int,
  out hora timestamptz, out campo text)
language plpgsql stable set search_path = public as $$
declare
  t timestamptz := p_desde;
  dur interval := make_interval(mins => p_minutos);
  k int;
begin
  for i in 1 .. 48 loop                      -- busca hasta 48 turnos más tarde
    for k in 1 .. greatest(p_campos, 1) loop
      if not exists (
        select 1 from partidos p
        where p.sede_id = p_sede and p.campo = 'Campo ' || k
          and p.hora < t + dur and p.hora + dur > t) then
        hora := t; campo := 'Campo ' || k;
        return;
      end if;
    end loop;
    t := t + dur;
  end loop;
  raise exception 'No hay campos libres en esa sede';
end $$;

-- ---------- Liguilla en varias franjas ----------
-- p_franjas: [{"inicio": "...", "fin": "...", "sedes": [{"sede": "<id>", "campos": 2}, ...]}, ...]
-- p_repartir: true = reparte los partidos entre las franjas; false = llena la primera y sigue.
create or replace function public.generar_liga(
  p_liga uuid, p_franjas jsonb, p_minutos int default 30, p_repartir boolean default true)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  arr uuid[]; n int; r int; i int; a uuid; b uuid;
  m_r int[] := '{}'; m_a uuid[] := '{}'; m_b uuid[] := '{}'; m_ok boolean[] := '{}';
  total int; hechos int := 0;
  dur interval := make_interval(mins => p_minutos);
  f jsonb; s jsonb; nf int; fi int := 0;
  t timestamptz; fin timestamptz;
  capacidad int[] := '{}'; cap_total int := 0; cupo int; en_franja int;
  campos text[]; csede uuid[];
  ocupados uuid[]; anteriores uuid[];
  ultima_sede jsonb;
  pasada int; nivel int; j int; k int; mejor int; puntos int;
  restantes int; turnos_quedan int; campos_franja int; seguidos_ok boolean;
  ultimo timestamptz;
begin
  if auth.uid() is not null and mi_rol() <> 'admin' then
    raise exception 'Solo administración puede generar el calendario';
  end if;
  if exists (select 1 from partidos where liga_id = p_liga and fase = 'liga') then
    raise exception 'Esta liga ya tiene partidos. Bórralos antes de volver a generarla.';
  end if;
  nf := coalesce(jsonb_array_length(p_franjas), 0);
  if nf = 0 then raise exception 'Añade al menos un día con su sede'; end if;
  if p_minutos < 5 then raise exception 'Los minutos por partido no son válidos'; end if;

  -- Emparejamientos: todos contra todos (método del círculo)
  select array_agg(equipo_id order by random()) into arr from liga_equipos where liga_id = p_liga;
  n := coalesce(array_length(arr, 1), 0);
  if n < 2 then raise exception 'La liga necesita al menos 2 equipos'; end if;
  if n % 2 = 1 then arr := arr || null::uuid; n := n + 1; end if;
  for r in 0 .. n - 2 loop
    for i in 0 .. n / 2 - 1 loop
      a := arr[1 + i]; b := arr[n - i];
      if a is not null and b is not null then
        m_r := m_r || (r + 1);
        m_a := m_a || case when r % 2 = 0 then a else b end;
        m_b := m_b || case when r % 2 = 0 then b else a end;
        m_ok := m_ok || false;
      end if;
    end loop;
    arr := array[arr[1]] || arr[n:n] || arr[2:n - 1];
  end loop;
  total := array_length(m_r, 1);

  -- Capacidad de cada franja (para repartir)
  for f in select value from jsonb_array_elements(p_franjas) loop
    if (f->>'fin')::timestamptz <= (f->>'inicio')::timestamptz then
      raise exception 'En una franja la hora de fin es anterior a la de inicio';
    end if;
    if coalesce(jsonb_array_length(f->'sedes'), 0) = 0 then
      raise exception 'Cada día tiene que tener al menos una sede';
    end if;
    i := floor(extract(epoch from ((f->>'fin')::timestamptz - (f->>'inicio')::timestamptz)) / (p_minutos * 60))::int
         * (select coalesce(sum(greatest((x->>'campos')::int, 1)), 0)::int from jsonb_array_elements(f->'sedes') x);
    capacidad := capacidad || i;
    cap_total := cap_total + i;
  end loop;

  -- Reparto turno a turno
  for f in select value from jsonb_array_elements(p_franjas) loop
    fi := fi + 1;
    t := (f->>'inicio')::timestamptz;
    fin := (f->>'fin')::timestamptz;
    anteriores := '{}';
    ultima_sede := '{}';
    en_franja := 0;
    cupo := case when p_repartir and fi < nf and cap_total > 0
                 then ceil(total::numeric * capacidad[fi] / cap_total)::int
                 else total end;

    while t + dur <= fin and hechos < total and en_franja < cupo loop
      -- campos libres en este turno
      campos := '{}'; csede := '{}';
      for s in select value from jsonb_array_elements(f->'sedes') loop
        for k in 1 .. greatest((s->>'campos')::int, 1) loop
          if not exists (
            select 1 from partidos p
            where p.sede_id = (s->>'sede')::uuid and p.campo = 'Campo ' || k
              and p.hora < t + dur and p.hora + dur > t) then
            campos := campos || ('Campo ' || k);
            csede := csede || (s->>'sede')::uuid;
          end if;
        end loop;
      end loop;

      ocupados := '{}';
      -- ¿Hace falta que alguien juegue dos turnos seguidos para que quepa todo?
      restantes := cupo - en_franja;
      turnos_quedan := floor(extract(epoch from (fin - (t + dur))) / (p_minutos * 60))::int;
      campos_franja := (select coalesce(sum(greatest((x->>'campos')::int, 1)), 0)::int from jsonb_array_elements(f->'sedes') x);
      seguidos_ok := restantes > turnos_quedan * greatest(1, least(campos_franja, n / 2)::numeric / 2);

      -- Pasada 1: solo equipos que descansaron el turno anterior (2: cualquiera libre, si hace falta).
      -- Nivel 2: los dos equipos siguen en la misma sede; 1: uno de ellos; 0: da igual.
      for pasada in 1 .. 2 loop
        continue when pasada = 2 and not seguidos_ok;
        for nivel in reverse 2 .. 0 loop
          for j in 1 .. total loop
            exit when coalesce(array_length(campos, 1), 0) = 0 or en_franja >= cupo;
            continue when m_ok[j];
            continue when m_a[j] = any(ocupados) or m_b[j] = any(ocupados);
            continue when pasada = 1 and (m_a[j] = any(anteriores) or m_b[j] = any(anteriores));

            -- el campo en la sede donde ya estaban sus equipos ese día (sin sede aún = cualquiera)
            mejor := 1; puntos := -1;
            for k in 1 .. array_length(campos, 1) loop
              i := (case when coalesce(ultima_sede->>(m_a[j]::text), csede[k]::text) = csede[k]::text then 1 else 0 end)
                 + (case when coalesce(ultima_sede->>(m_b[j]::text), csede[k]::text) = csede[k]::text then 1 else 0 end);
              if i > puntos then puntos := i; mejor := k; end if;
            end loop;
            continue when puntos < nivel;

            insert into partidos (liga_id, fase, jornada, local_id, visitante_id, sede_id, campo, hora)
            values (p_liga, 'liga', m_r[j], m_a[j], m_b[j], csede[mejor], campos[mejor], t);

            m_ok[j] := true;
            hechos := hechos + 1;
            en_franja := en_franja + 1;
            ultimo := t;
            ocupados := ocupados || m_a[j] || m_b[j];
            ultima_sede := ultima_sede || jsonb_build_object(m_a[j]::text, csede[mejor]::text, m_b[j]::text, csede[mejor]::text);
            campos := campos[1:mejor - 1] || campos[mejor + 1:];
            csede := csede[1:mejor - 1] || csede[mejor + 1:];
          end loop;
        end loop;
      end loop;

      anteriores := ocupados;
      t := t + dur;
    end loop;
  end loop;

  if hechos < total then
    raise exception 'No caben todos los partidos: faltan % de %. Añade más horas, más campos u otro día.', total - hechos, total;
  end if;
  return jsonb_build_object('partidos', total, 'ultimo', ultimo);
end $$;

-- La forma antigua (una sede) sigue funcionando: se convierte en una sola franja de 12 horas
create or replace function public.generar_liga(
  p_liga uuid, p_inicio timestamptz, p_sede uuid,
  p_minutos int default 30, p_campos int default 2)
returns int
language plpgsql security definer set search_path = public as $$
begin
  return (public.generar_liga(p_liga,
    jsonb_build_array(jsonb_build_object(
      'inicio', p_inicio, 'fin', p_inicio + interval '12 hours',
      'sedes', jsonb_build_array(jsonb_build_object('sede', p_sede, 'campos', p_campos)))),
    p_minutos, false)->>'partidos')::int;
end $$;

-- ---------- Fase final en campos libres ----------
drop function if exists public.generar_fase_final(uuid, timestamptz, uuid, int);
create or replace function public.generar_fase_final(
  p_liga uuid, p_inicio timestamptz, p_sede uuid, p_minutos int default 30, p_campos int default 2)
returns void
language plpgsql security definer set search_path = public as $$
declare
  top uuid[];
  h1 record; h2 record; h3 record; h4 record;
  dur interval := make_interval(mins => p_minutos);
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

  -- Semifinales (a la vez si hay dos campos libres)
  select * into h1 from hueco_libre(p_sede, p_campos, p_inicio, p_minutos);
  insert into partidos (liga_id, fase, jornada, local_id, visitante_id, sede_id, campo, hora)
  values (p_liga, 'semifinal', 1, top[1], top[4], p_sede, h1.campo, h1.hora);
  select * into h2 from hueco_libre(p_sede, p_campos, p_inicio, p_minutos);
  insert into partidos (liga_id, fase, jornada, local_id, visitante_id, sede_id, campo, hora)
  values (p_liga, 'semifinal', 2, top[2], top[3], p_sede, h2.campo, h2.hora);

  -- 3er puesto y final, cuando acaben las dos semifinales
  select * into h3 from hueco_libre(p_sede, p_campos, greatest(h1.hora, h2.hora) + dur, p_minutos);
  insert into partidos (liga_id, fase, jornada, local_id, visitante_id, sede_id, campo, hora)
  values (p_liga, 'tercer_puesto', 1, null, null, p_sede, h3.campo, h3.hora);
  select * into h4 from hueco_libre(p_sede, p_campos, greatest(h1.hora, h2.hora) + dur, p_minutos);
  insert into partidos (liga_id, fase, jornada, local_id, visitante_id, sede_id, campo, hora)
  values (p_liga, 'final', 1, null, null, p_sede, h4.campo, h4.hora);
end $$;
