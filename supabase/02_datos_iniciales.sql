-- =====================================================================
-- Marbel Football Cup · Datos iniciales (paso 1)
-- Ejecutar en Supabase > SQL Editor DESPUÉS de 01_esquema.sql
-- =====================================================================

insert into torneos (nombre, fechas_texto, inicio, inscripcion_hasta)
values ('IV Torneo Navideño', '26-27 dic · 2-3 ene', '2026-12-26 09:00:00+01', '2026-12-20');

insert into niveles (id, nombre, color, orden) values
  ('iniciacion', 'Iniciación', '#FF7A1A', 1),
  ('medio',      'Medio',      '#FFD400', 2),
  ('elite',      'Élite',      '#22C55E', 3),
  ('femenino',   'Femenino',   '#FF4FB8', 4);

insert into categorias (nombre, femenina, orden) values
  ('Prebenjamín 1º año',   false, 1),
  ('Prebenjamín 2º año',   false, 2),
  ('Benjamín 1º año',      false, 3),
  ('Benjamín 2º año',      false, 4),
  ('Alevín 1º año',        false, 5),
  ('Alevín 2º año',        false, 6),
  ('Infantil F11',         false, 7),
  ('Sub 12 femenino',      true,  8),
  ('Infantil F8 femenino', true,  9);

insert into sedes (nombre, nombre_oficial, maps_url, servicios, orden) values
  ('Albatera',           'Campo de Fútbol Municipal Nuevo Calvario', 'https://maps.app.goo.gl/EHZdc4bnHS19Zor7A',
   array['Césped artificial','Cantina','Aparcamiento','Espacios alternos'], 1),
  ('Granja de Rocamora', 'Polideportivo La Palmera',                 'https://maps.app.goo.gl/2nGBAvpyJT3mufvJA',
   array['Césped artificial','Cantina','Aparcamiento','Espacios alternos'], 2),
  ('Rafal',              'Campo de Fútbol Joaquín Pastor',           'https://maps.app.goo.gl/6Qba8cAghahWCdWBA',
   array['Césped artificial','Cantina','Aparcamiento','Espacios alternos'], 3),
  ('Bigastro',           'Polideportivo El Molino',                  'https://maps.app.goo.gl/kugc3a1At983XCKp8',
   array['Césped artificial','Cantina','Aparcamiento','Espacios alternos'], 4);

-- Equipos confirmados (los escudos se suben en el paso 2)
insert into equipos (nombre, localidad) values
  ('Academia Afán',               'Murcia'),
  ('Academia Paquito',            'Cartagena (Murcia)'),
  ('Albacete Balompié',           'Albacete'),
  ('Amigos Futboleros Fortuna',   'Fortuna (Murcia)'),
  ('Archena F.C.',                'Archena (Murcia)'),
  ('C.F. Albatera Sporting',      'Albatera (Alicante)'),
  ('C.F. Rafal',                  'Rafal (Alicante)'),
  ('C.F.S. El Progreso',          'Murcia'),
  ('CFO Sant Joan',               'Sant Joan d''Alacant (Alicante)'),
  ('Club Deportivo Lumbreras',    'Murcia'),
  ('Costa City UMH',              'Elche (Alicante)'),
  ('E.F. Santa Ana - Cartagena',  'Cartagena (Murcia)'),
  ('Elche Dream C.F.',            'Elche (Alicante)'),
  ('Elda Unión C.F.',             'Elda (Alicante)'),
  ('F.C. Cartagena SAD',          'Cartagena (Murcia)'),
  ('Garra Ilicitana C.F.',        'Elche (Alicante)'),
  ('Kelme C.F.',                  'Elche (Alicante)'),
  ('Lacross Babel C.F.',          'Alicante'),
  ('Ovejos F.C.',                 null),
  ('Promesas Elche',              'Torrellano, Elche (Alicante)'),
  ('Racing Akra C.F.',            'Alicante'),
  ('Ranero Club de Fútbol',       'Murcia'),
  ('Real Murcia C.F.',            'Murcia'),
  ('Selección Arsenal',           null),
  ('Selección Murciana',          'Región de Murcia'),
  ('Sporting Saladar',            'Almoradí (Alicante)'),
  ('Triple A Academy',            'Elche (Alicante)'),
  ('U.E. Crevillent',             'Crevillent (Alicante)'),
  ('UCAM Murcia C.F.',            'Murcia');
