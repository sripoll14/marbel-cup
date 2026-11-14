import 'package:flutter/material.dart';

import '../data/datos.dart';
import '../data/favoritos.dart';
import '../data/modelos.dart';
import '../theme/app_theme.dart';
import 'comunes.dart';

/// Texto y colores del estado de un partido.
(String, Color, Color) estadoPartido(Partido p) {
  if (p.estado == Estado.enJuego) return ('En juego', MarbelColors.enJuego, MarbelColors.blanco);
  if (p.estado == Estado.finalizado) {
    return ('Final', const Color(0xFF1E2672), MarbelColors.texto2);
  }
  if (p.estado == Estado.aplazado) return ('Aplazado', const Color(0xFF3A2A00), const Color(0xFFFFE08A));
  if (p.retrasado) {
    return ('Retraso +${p.minutosDeRetraso} min', const Color(0xFF3A2A00), const Color(0xFFFFE08A));
  }
  if (p.retrasoMin > 0) {
    return ('Retraso ${p.retrasoMin} min', const Color(0xFF3A2A00), const Color(0xFFFFE08A));
  }
  return ('Próximo', const Color(0xFF1E2672), MarbelColors.texto2);
}

/// Tarjeta de un partido: hora, categoría, equipos, marcador, sede y estado.
class TarjetaPartido extends StatelessWidget {
  const TarjetaPartido(this.p, {super.key, this.compacta = false, this.tocable = true});
  final Partido p;
  final bool compacta;

  /// Al tocarla se abre el partido (marcador y goles).
  final bool tocable;

  @override
  Widget build(BuildContext context) {
    final nivel = datos.nivelDeLiga(p.ligaId);
    final sede = datos.sede(p.sedeId);
    final (est, estFondo, estColor) = estadoPartido(p);
    final fav = favoritos.es(p.localId ?? '') || favoritos.es(p.visitanteId ?? '');
    final fase = switch (p.fase) {
      Fase.liga => p.jornada == null ? 'Liga' : 'Liga · J${p.jornada}',
      Fase.semifinal => 'Semifinal',
      Fase.tercerPuesto => '3er y 4º puesto',
      Fase.final_ => 'Final',
    };

    Widget equipo(String? id, int? goles, int? pen, bool gana) {
      final e = datos.equipo(id);
      return Row(
        children: [
          Escudo(e, tamano: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(e?.nombre ?? 'Por decidir',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: gana ? FontWeight.w800 : FontWeight.w600,
                  color: e == null
                      ? MarbelColors.apagado
                      : (p.estado == Estado.finalizado && !gana
                          ? const Color(0xFF8F99D6)
                          : MarbelColors.blanco),
                  fontSize: 15,
                )),
          ),
          if (favoritos.es(id ?? '')) const Text(' ★ ', style: TextStyle(color: MarbelColors.medio)),
          Text(
            goles == null ? '' : '$goles${pen != null ? ' ($pen)' : ''}',
            style: MarbelText.titular(22).copyWith(fontStyle: FontStyle.normal),
          ),
        ],
      );
    }

    final ganador = p.ganadorId;
    final tarjeta = Tarjeta(
      padding: const EdgeInsets.all(14),
      borde: fav ? MarbelColors.medio : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pastilla.nivel(nivel, texto: datos.nombreLigaPartido(p), tamano: 11),
              const SizedBox(width: 8),
              Expanded(
                child: Text(fase,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: MarbelColors.apagado, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              Pastilla(est, fondo: estFondo, color: estColor, tamano: 11),
              if (tocable) ...[
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 18, color: MarbelColors.apagado),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 54,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hhmm(p.horaReal),
                        style: MarbelText.titular(20, color: MarbelColors.apagado)
                            .copyWith(fontStyle: FontStyle.normal)),
                    if (p.estado == Estado.enJuego)
                      Text(p.minutoTexto,
                          style: const TextStyle(
                              color: MarbelColors.enJuego, fontWeight: FontWeight.w800, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    equipo(p.localId, p.golesLocal, p.penaltisLocal, ganador != null && ganador == p.localId),
                    const SizedBox(height: 6),
                    equipo(p.visitanteId, p.golesVisitante, p.penaltisVisitante,
                        ganador != null && ganador == p.visitanteId),
                  ],
                ),
              ),
            ],
          ),
          if (!compacta && sede != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: MarbelColors.apagado),
                const SizedBox(width: 4),
                Text('${sede.nombre}${p.campo == null ? '' : ' · ${p.campo}'}',
                    style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
    if (!tocable) return tarjeta;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => abrirPartido(context, p.id),
        child: tarjeta,
      ),
    );
  }
}

/// Tabla de clasificación de una liga.
class TablaClasificacion extends StatelessWidget {
  const TablaClasificacion({super.key, required this.ligaId, this.completa = true});
  final String ligaId;
  final bool completa;

  @override
  Widget build(BuildContext context) {
    final filas = datos.clasificacion(ligaId);
    if (filas.isEmpty) {
      return const EstadoVacio('Esta liga aún no tiene equipos asignados.');
    }
    const cab = TextStyle(
        color: MarbelColors.apagado, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8);
    TableRow fila(FilaClasificacion f) {
      final e = datos.equipo(f.equipoId);
      final clasifica = f.pos <= 4;
      final fav = favoritos.es(f.equipoId);
      Widget n(Object v, {bool fuerte = false}) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text('$v',
                textAlign: TextAlign.center,
                style: fuerte
                    ? MarbelText.titular(20, color: MarbelColors.cian)
                        .copyWith(fontStyle: FontStyle.normal)
                    : const TextStyle(fontSize: 15)),
          );
      return TableRow(
        decoration: BoxDecoration(
          border: const Border(top: BorderSide(color: Color(0xFF1E2672))),
          color: fav ? const Color(0x22FFD400) : null,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Opacity(
              opacity: clasifica ? 1 : .6,
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: clasifica ? MarbelColors.cian : const Color(0xFF1E2672),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text('${f.pos}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: clasifica ? MarbelColors.fondo : MarbelColors.apagado)),
                  ),
                  const SizedBox(width: 8),
                  Escudo(e, tamano: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${e?.nombre ?? '?'}${fav ? ' ★' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
          n(f.pj),
          if (completa) ...[n(f.g), n(f.e), n(f.p)],
          n(f.dgTexto),
          n(f.pts, fuerte: true),
        ],
      );
    }

    return Table(
      columnWidths: {
        0: const FlexColumnWidth(),
        for (var i = 1; i <= (completa ? 6 : 3); i++) i: const FixedColumnWidth(38),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [
          const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('EQUIPO', style: cab)),
          const Text('PJ', textAlign: TextAlign.center, style: cab),
          if (completa) ...const [
            Text('G', textAlign: TextAlign.center, style: cab),
            Text('E', textAlign: TextAlign.center, style: cab),
            Text('P', textAlign: TextAlign.center, style: cab),
          ],
          const Text('DG', textAlign: TextAlign.center, style: cab),
          const Text('PTS', textAlign: TextAlign.center, style: cab),
        ]),
        for (final f in filas) fila(f),
      ],
    );
  }
}

/// Un cruce del cuadro final.
class CruceFinal extends StatelessWidget {
  const CruceFinal({super.key, required this.titulo, this.partido, this.color = MarbelColors.cian, this.borde});
  final String titulo;
  final Partido? partido;
  final Color color;
  final Color? borde;

  @override
  Widget build(BuildContext context) {
    final p = partido;
    final g = p?.ganadorId;
    Widget linea(String? id, int? goles, int? pen) {
      final e = datos.equipo(id);
      final gana = g != null && g == id;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Escudo(e, tamano: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(e?.nombre ?? 'Por decidir',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: gana ? FontWeight.w800 : FontWeight.w600,
                      color: e == null || (g != null && !gana)
                          ? const Color(0xFF8F99D6)
                          : MarbelColors.blanco)),
            ),
            Text(goles == null ? '' : '$goles${pen != null ? ' ($pen)' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: MarbelColors.tarjeta,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borde ?? const Color(0xFF2B35A6), width: borde == null ? 1 : 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              '${titulo.toUpperCase()}${p == null ? '' : ' · ${diaSemanaCorto(p.hora)} ${p.hora.day} · ${hhmm(p.horaReal)}'}',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6),
            ),
          ),
          linea(p?.localId, p?.golesLocal, p?.penaltisLocal),
          const Divider(height: 1, color: Color(0xFF1E2672)),
          linea(p?.visitanteId, p?.golesVisitante, p?.penaltisVisitante),
        ],
      ),
    );
  }
}

/// Cuadro de la fase final: semifinales, final, 3er puesto y campeón.
class CuadroFinal extends StatelessWidget {
  const CuadroFinal({super.key, required this.ligaId});
  final String ligaId;

  @override
  Widget build(BuildContext context) {
    final ps = datos.partidosDeLiga(datos.ligaFaseFinal(ligaId));
    final conjunta = datos.enFaseConjunta(ligaId);
    Partido? de(Fase f, [int? j]) =>
        ps.where((p) => p.fase == f && (j == null || p.jornada == j)).firstOrNull;
    final s1 = de(Fase.semifinal, 1), s2 = de(Fase.semifinal, 2);
    final fin = de(Fase.final_), ter = de(Fase.tercerPuesto);
    final campeon = datos.equipo(fin?.ganadorId);

    if (s1 == null && s2 == null && fin == null) {
      final cl = datos.clasificacion(ligaId);
      String n(int i) => i < cl.length ? datos.nombreEquipo(cl[i].equipoId) : '—';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EstadoVacio(
              'La fase final se publica al terminar la liga. Si acabara ahora, las semifinales serían:',
              icono: Icons.account_tree_rounded),
          const SizedBox(height: 12),
          Text('Semi 1 · 1º ${n(0)} vs 4º ${n(3)}',
              style: const TextStyle(color: MarbelColors.texto2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Semi 2 · 2º ${n(1)} vs 3º ${n(2)}',
              style: const TextStyle(color: MarbelColors.texto2, fontWeight: FontWeight.w600)),
        ],
      );
    }

    final semis = Column(
      children: [
        CruceFinal(titulo: conjunta ? 'Semifinal 1' : 'Semi 1 · 1º vs 4º', partido: s1),
        const SizedBox(height: 12),
        CruceFinal(titulo: conjunta ? 'Semifinal 2' : 'Semi 2 · 2º vs 3º', partido: s2),
      ],
    );
    final finales = Column(
      children: [
        CruceFinal(titulo: 'Final', partido: fin, color: MarbelColors.medio, borde: MarbelColors.medio),
        const SizedBox(height: 12),
        CruceFinal(
            titulo: '3er y 4º puesto',
            partido: ter,
            color: const Color(0xFFE0A060),
            borde: const Color(0xFFCD7F32)),
      ],
    );
    final copa = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.emoji_events_rounded, size: 72, color: MarbelColors.medio),
        Text('CAMPEÓN', style: MarbelText.etiqueta(color: MarbelColors.medio)),
        const SizedBox(height: 6),
        Text((campeon?.nombre ?? '¿?').toUpperCase(),
            textAlign: TextAlign.center,
            style: MarbelText.titular(26).copyWith(fontStyle: FontStyle.normal)),
      ],
    );

    final avisoConjunta = conjunta
        ? const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Fase final conjunta de todos los grupos de esta categoría y nivel.',
                style: TextStyle(color: MarbelColors.cian, fontWeight: FontWeight.w700)),
          )
        : const SizedBox.shrink();

    if (!esAncho(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          avisoConjunta,
          Text('SEMIFINALES', style: MarbelText.etiqueta(color: MarbelColors.apagado)),
          const SizedBox(height: 8),
          semis,
          const SizedBox(height: 18),
          Text('FINALES', style: MarbelText.etiqueta(color: MarbelColors.medio)),
          const SizedBox(height: 8),
          finales,
          const SizedBox(height: 18),
          copa,
        ],
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      avisoConjunta,
      Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: semis),
        const SizedBox(width: 12),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFF3A44B8), size: 36),
        const SizedBox(width: 12),
        Expanded(child: finales),
        const SizedBox(width: 24),
        SizedBox(width: 200, child: copa),
      ],
    ),
    ]);
  }
}

/// Ficha de un partido: marcador en directo y goles.
Future<void> abrirPartido(BuildContext context, String partidoId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: MarbelColors.fondo,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (c, scroll) => ListenableBuilder(
        listenable: datos,
        builder: (c, _) {
          final p = datos.partidos.where((x) => x.id == partidoId).firstOrNull;
          if (p == null) return const Center(child: Text('Este partido ya no existe.'));
          final goles = datos.goles.where((g) => g.partidoId == p.id).toList()
            ..sort((a, b) => (a.minuto ?? 999).compareTo(b.minuto ?? 999));
          return ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 10, 16, 32), children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: MarbelColors.borde, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 14),
            TarjetaPartido(p, tocable: false),
            if (goles.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('GOLES', style: MarbelText.etiqueta(color: MarbelColors.apagado)),
              const SizedBox(height: 6),
              for (final g in goles)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    '⚽ ${g.jugador}${g.minuto == null ? '' : " ${g.minuto}'"} · ${datos.nombreEquipo(g.equipoId)}',
                    style: const TextStyle(color: MarbelColors.texto2),
                  ),
                ),
            ],
          ]);
        },
      ),
    ),
  );
}
