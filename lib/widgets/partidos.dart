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
  const TablaClasificacion({super.key, required this.ligaId, this.completa = true, this.tocable = true});
  final String ligaId;
  final bool completa;

  /// Al tocar un equipo se abre su ficha (partidos, goles, racha).
  final bool tocable;

  @override
  Widget build(BuildContext context) {
    final filas = datos.clasificacion(ligaId);
    if (filas.isEmpty) {
      return const EstadoVacio('Esta liga aún no tiene equipos asignados.');
    }
    const cab = TextStyle(
        color: MarbelColors.apagado, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8);
    final ancho = esAncho(context);
    final cols = <(String, Object Function(FilaClasificacion))>[
      ('PJ', (f) => f.pj),
      if (completa) ...[('G', (f) => f.g), ('E', (f) => f.e), ('P', (f) => f.p)],
      ('GF', (f) => f.gf),
      ('GC', (f) => f.gc),
      ('DG', (f) => f.dgTexto),
    ];
    final anchoCol = ancho ? 38.0 : 34.0;
    final hayEmpate = filas.any((f) => f.empatePendiente);
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
          _TocarEquipo(
            equipoId: tocable ? f.equipoId : null,
            child: Padding(
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
                      child: Text('${e?.nombre ?? '?'}${fav ? ' ★' : ''}${f.empatePendiente ? ' *' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    if (tocable) const Icon(Icons.chevron_right_rounded, size: 16, color: MarbelColors.apagado),
                  ],
                ),
              ),
            ),
          ),
          for (final c in cols) n(c.$2(f)),
          n(f.pts, fuerte: true),
        ],
      );
    }

    // Si no cabe (móvil), la tabla se desliza de lado; el resto de la página no se mueve.
    const anchoEquipo = 170.0;
    Table tabla0(bool cabe) => Table(
      columnWidths: {
        0: cabe ? const FlexColumnWidth() : const FixedColumnWidth(anchoEquipo),
        for (var i = 1; i <= cols.length + 1; i++) i: FixedColumnWidth(anchoCol),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [
          const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('EQUIPO', style: cab)),
          for (final c in cols) Text(c.$1, textAlign: TextAlign.center, style: cab),
          const Text('PTS', textAlign: TextAlign.center, style: cab),
        ]),
        for (final f in filas) fila(f),
      ],
    );
    final tabla = LayoutBuilder(builder: (context, c) {
      final cabe = c.maxWidth >= anchoEquipo + anchoCol * (cols.length + 1);
      if (cabe) return tabla0(true);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: anchoEquipo + anchoCol * (cols.length + 1), child: tabla0(false)),
        ),
        const SizedBox(height: 4),
        const Text('Desliza la tabla hacia el lado para ver todas las columnas →',
            style: TextStyle(color: MarbelColors.apagado, fontSize: 11.5)),
      ]);
    });
    if (!hayEmpate) return tabla;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      tabla,
      const SizedBox(height: 6),
      const Text('* Empate a puntos: el orden lo decide la organización según el reglamento.',
          style: TextStyle(color: MarbelColors.medio, fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }
}

/// Celda tocable que abre la ficha de un equipo.
class _TocarEquipo extends StatelessWidget {
  const _TocarEquipo({required this.equipoId, required this.child});
  final String? equipoId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final id = equipoId;
    if (id == null) return child;
    return Semantics(
      button: true,
      label: 'Ver la ficha de ${datos.nombreEquipo(id)}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => abrirEquipo(context, id),
          child: child,
        ),
      ),
    );
  }
}

/// Ficha de un equipo en el torneo que se está viendo: posición en su liga,
/// números (PJ, G, E, P, GF, GC), racha y todos sus partidos.
Future<void> abrirEquipo(BuildContext context, String equipoId) {
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
        listenable: Listenable.merge([datos, favoritos]),
        builder: (c, _) {
          final e = datos.equipo(equipoId);
          final ps = datos.partidosDeEquipo(equipoId)..sort((a, b) => a.hora.compareTo(b.hora));
          final jugados = ps.where((p) => p.estado == Estado.finalizado && p.tieneMarcador).toList();
          var g = 0, em = 0, pe = 0, gf = 0, gc = 0;
          for (final p in jugados) {
            final local = p.localId == equipoId;
            final a = local ? p.golesLocal! : p.golesVisitante!;
            final b = local ? p.golesVisitante! : p.golesLocal!;
            gf += a;
            gc += b;
            final gan = p.ganadorId;
            if (gan == null) {
              em++;
            } else if (gan == equipoId) {
              g++;
            } else {
              pe++;
            }
          }
          final racha = datos.rachaDe(equipoId);
          final ligas = datos.ligasDeEquipo(equipoId);

          Widget dato(String t, Object v) => Expanded(
                child: Column(children: [
                  Text('$v', style: MarbelText.titular(26, color: MarbelColors.cian).copyWith(fontStyle: FontStyle.normal)),
                  Text(t, style: MarbelText.etiqueta(color: MarbelColors.apagado, size: 11)),
                ]),
              );

          return ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 10, 16, 32), children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: MarbelColors.borde, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Escudo(e, tamano: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((e?.nombre ?? 'Equipo').toUpperCase(),
                      style: MarbelText.titular(26).copyWith(fontStyle: FontStyle.normal)),
                  if (datos.torneo != null)
                    Text(datos.torneo!.nombre, style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
                ]),
              ),
              IconButton(
                tooltip: favoritos.es(equipoId) ? 'Dejar de seguir' : 'Seguir a este equipo',
                onPressed: () => favoritos.alternar(equipoId),
                icon: Icon(favoritos.es(equipoId) ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: MarbelColors.medio),
              ),
            ]),
            const SizedBox(height: 12),
            for (final l in ligas)
              Builder(builder: (c) {
                final fila = datos.clasificacion(l.id).where((f) => f.equipoId == equipoId).firstOrNull;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Pastilla.nivel(datos.nivelDeLiga(l.id), texto: datos.nombreLiga(l.id), tamano: 11),
                    if (fila != null && fila.pj > 0)
                      Text('${fila.pos}º en la liguilla · ${fila.pts} puntos',
                          style: const TextStyle(color: MarbelColors.texto2, fontWeight: FontWeight.w700)),
                  ]),
                );
              }),
            const SizedBox(height: 10),
            Tarjeta(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              child: Row(children: [
                dato('PJ', jugados.length),
                dato('G', g),
                dato('E', em),
                dato('P', pe),
                dato('GF', gf),
                dato('GC', gc),
              ]),
            ),
            if (racha.ultimos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                Text('ÚLTIMOS', style: MarbelText.etiqueta(color: MarbelColors.apagado, size: 12)),
                const SizedBox(width: 10),
                for (final r in racha.ultimos)
                  Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(right: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: switch (r) {
                        'V' => MarbelColors.elite,
                        'E' => MarbelColors.medio,
                        _ => const Color(0xFFFF7A85),
                      },
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(r, style: const TextStyle(color: MarbelColors.fondo, fontWeight: FontWeight.w800)),
                  ),
                if (racha.racha > 1)
                  Flexible(
                    child: Text('${racha.racha} seguidas',
                        overflow: TextOverflow.ellipsis, style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
                  ),
              ]),
            ],
            const SizedBox(height: 18),
            Text('PARTIDOS', style: MarbelText.etiqueta(color: MarbelColors.apagado)),
            const SizedBox(height: 8),
            if (ps.isEmpty)
              const Text('Aún no tiene partidos en el calendario.', style: TextStyle(color: MarbelColors.apagado))
            else
              for (final p in ps) ...[
                Text('${diaCorto(p.hora)} · ${hhmm(p.horaReal)}',
                    style: const TextStyle(color: MarbelColors.apagado, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                TarjetaPartido(p),
                const SizedBox(height: 10),
              ],
          ]);
        },
      ),
    ),
  );
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
              'La fase final la publica la organización al terminar la liga. Con la clasificación de ahora, las semifinales serían:',
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
          final p = datos.todosPartidos.where((x) => x.id == partidoId).firstOrNull;
          if (p == null) return const Center(child: Text('Este partido ya no existe.'));
          final goles = datos.todosGoles.where((g) => g.partidoId == p.id).toList()
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
                    '⚽ ${datos.nombreEquipo(g.equipoId)}${g.minuto == null ? '' : " · minuto ${g.minuto}"}',
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
