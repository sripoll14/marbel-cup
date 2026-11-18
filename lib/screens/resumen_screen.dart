import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/datos.dart';
import '../data/modelos.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/competicion.dart';
import '../widgets/partidos.dart';
import '../widgets/torneos.dart';
import 'estadisticas_screen.dart';
import 'porra_screen.dart';

/// Resumen de un torneo que ya ha terminado («Torneos anteriores»): campeones,
/// clasificaciones y fase final, estadísticas y el ranking final de La Porra.
class ResumenTorneo extends StatelessWidget {
  const ResumenTorneo({super.key});

  @override
  Widget build(BuildContext context) {
    return ConDatos(builder: (context) {
      final t = datos.torneo;
      if (t == null) return const SizedBox.shrink();
      final ancho = esAncho(context);
      final hueco = SizedBox(height: ancho ? 56 : 36);

      final jugados = datos.finalizados();
      final goles = jugados.fold<int>(0, (s, p) => s + p.golesLocal! + p.golesVisitante!);
      final equipos = {for (final l in datos.ligasActuales) ...(datos.equiposDeLiga[l.id] ?? const <String>[])};
      final podios = _podios();

      Widget titulo(String texto, [String? sub]) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(texto.toUpperCase(), style: MarbelText.titular(ancho ? 48 : 32)),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(color: MarbelColors.texto2)),
            ],
            const SizedBox(height: 16),
          ]);

      final contenido = <Widget>[
        // Cifras del torneo
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final (v, k) in [
            ('${jugados.length}', 'Partidos jugados'),
            ('$goles', 'Goles'),
            ('${equipos.length}', 'Equipos'),
            ('${datos.ligasActuales.length}', 'Ligas'),
          ])
            SizedBox(
              width: ancho ? 200 : 150,
              child: Tarjeta(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v, style: MarbelText.titular(ancho ? 44 : 34, color: MarbelColors.cian).copyWith(fontStyle: FontStyle.normal)),
                  Text(k.toUpperCase(), style: MarbelText.etiqueta(color: MarbelColors.apagado, size: 12)),
                ]),
              ),
            ),
        ]),
        if (podios.isNotEmpty) ...[
          hueco,
          titulo('🏆 Campeones', 'Toca un equipo para ver todos sus partidos.'),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final p in podios) SizedBox(width: w, child: _TarjetaPodio(p)),
            ]);
          }),
        ],
        hueco,
        titulo('Clasificaciones y fase final', 'Elige la categoría. Toca un equipo de la clasificación para ver su ficha.'),
        const Competicion(titulo: false),
        hueco,
        titulo('Estadísticas'),
        const EstadisticasScreen(incrustada: true),
        hueco,
        titulo('La Porra'),
        const RankingPorra(ligaId: null, terminado: true),
      ];

      final cabecera = _Cabecera(t);
      if (!ancho) {
        return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          cabecera,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: contenido),
          ),
        ]);
      }
      return PaginaPublica(children: [
        cabecera,
        const SizedBox(height: 32),
        AnchoMax(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: contenido)),
      ]);
    });
  }
}

/// Campeón, subcampeón y tercero de una liga (o de la fase final conjunta de
/// sus grupos). Si no se jugó fase final, el primero de la liguilla.
typedef _Podio = ({String liga, Nivel nivel, String? primero, String? segundo, String? tercero, bool conFinal});

List<_Podio> _podios() {
  final out = <_Podio>[];
  for (final l in datos.ligasActuales) {
    // Los grupos que juegan la fase final en otro grupo, salen con ese
    if (l.finalEn != null) continue;
    final nombre = datos.nombreLiga(l.id, corto: false, sinGrupo: datos.tieneFaseConjunta(l.id));
    final nivel = datos.nivelDeLiga(l.id);
    final ps = datos.partidosDeLiga(l.id);
    final fin = ps.where((p) => p.fase == Fase.final_ && p.estado == Estado.finalizado && p.ganadorId != null).firstOrNull;
    if (fin != null) {
      final g = fin.ganadorId!;
      final tercer = ps.where((p) => p.fase == Fase.tercerPuesto && p.estado == Estado.finalizado).firstOrNull;
      out.add((
        liga: nombre,
        nivel: nivel,
        primero: g,
        segundo: g == fin.localId ? fin.visitanteId : fin.localId,
        tercero: tercer?.ganadorId,
        conFinal: true,
      ));
      continue;
    }
    // Sin final: el primero de la liguilla (solo si es un único grupo)
    if (datos.gruposDe(l).length > 1) continue;
    final c = datos.clasificacion(l.id);
    if (c.isEmpty || c.first.pj == 0) continue;
    out.add((
      liga: nombre,
      nivel: nivel,
      primero: c.first.equipoId,
      segundo: c.length > 1 ? c[1].equipoId : null,
      tercero: c.length > 2 ? c[2].equipoId : null,
      conFinal: false,
    ));
  }
  return out;
}

class _TarjetaPodio extends StatelessWidget {
  const _TarjetaPodio(this.p);
  final _Podio p;

  @override
  Widget build(BuildContext context) {
    Widget fila(String medalla, String texto, String? id, {bool grande = false}) {
      if (id == null) return const SizedBox.shrink();
      final e = datos.equipo(id);
      return Semantics(
        button: true,
        label: '$texto: ${e?.nombre ?? ''}. Ver su ficha',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => abrirEquipo(context, id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(children: [
              SizedBox(width: 30, child: Text(medalla, style: TextStyle(fontSize: grande ? 22 : 18))),
              Escudo(e, tamano: grande ? 34 : 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e?.nombre ?? '?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: grande ? 17 : 15)),
                  Text(texto, style: const TextStyle(color: MarbelColors.apagado, fontSize: 12)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: MarbelColors.apagado),
            ]),
          ),
        ),
      );
    }

    return Tarjeta(
      borde: p.nivel.color,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(alignment: Alignment.centerLeft, child: Pastilla.nivel(p.nivel, texto: p.liga, tamano: 11)),
        const SizedBox(height: 10),
        fila('🏆', p.conFinal ? 'Campeón' : '1º de la liguilla', p.primero, grande: true),
        fila('🥈', p.conFinal ? 'Subcampeón' : '2º de la liguilla', p.segundo),
        fila('🥉', p.conFinal ? 'Tercer puesto' : '3º de la liguilla', p.tercero),
      ]),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera(this.t);
  final Torneo t;

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: MarbelColors.fondoAlto,
        border: Border(bottom: BorderSide(color: Color(0xFF1A2170))),
      ),
      child: AnchoMax(
        padding: EdgeInsets.fromLTRB(ancho ? 24 : 4, ancho ? 20 : 8, ancho ? 24 : 12, ancho ? 20 : 12),
        child: Row(children: [
          IconButton(
            tooltip: 'Torneos',
            onPressed: () => context.go('/torneos'),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              pastillaFase(t, tamano: 11),
              const SizedBox(height: 6),
              Text(t.nombre.toUpperCase(),
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: MarbelText.titular(ancho ? 40 : 26)),
              Text(['Resumen del torneo', t.fechasTexto, if (t.lugar != null) t.lugar!].join(' · '),
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
            ]),
          ),
        ]),
      ),
    );
  }
}
