-- =====================================================================
-- Sedes: fotos (van dentro de la app) y coordenadas para el mapa.
-- Se puede ejecutar más de una vez sin problema.
-- =====================================================================
alter table sedes add column if not exists lat double precision;
alter table sedes add column if not exists lon double precision;

update sedes set foto_url = 'assets/images/sedes/albatera.jpg', lat = 38.179, lon = -0.870 where nombre = 'Albatera';
update sedes set foto_url = 'assets/images/sedes/granja.jpg',   lat = 38.151, lon = -0.903 where nombre = 'Granja de Rocamora';
update sedes set foto_url = 'assets/images/sedes/rafal.jpg',    lat = 38.103, lon = -0.848 where nombre = 'Rafal';
update sedes set foto_url = 'assets/images/sedes/bigastro.jpg', lat = 38.062, lon = -0.898 where nombre = 'Bigastro';
