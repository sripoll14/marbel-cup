-- Borra el «Torneo de Ejemplo Primavera 2027» y todo lo suyo
-- (ligas, partidos, avisos...) y su sede de ejemplo. No toca nada más.
delete from public.torneos where nombre = 'Torneo de Ejemplo Primavera 2027';
delete from public.sedes s
 where s.nombre = 'Elche (ejemplo)'
   and not exists (select 1 from public.partidos p where p.sede_id = s.id);
select 'ejemplo borrado' as paso, true as hecho;
