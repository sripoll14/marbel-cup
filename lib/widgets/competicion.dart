import 'package:flutter/material.dart';

import '../data/datos.dart';
import '../data/favoritos.dart';
import '../data/modelos.dart';
import '../theme/app_theme.dart';
import 'comunes.dart';
import 'partidos.dart';

/// Elección de liga: categoría + nivel. Empieza en la liga del primer equipo
/// favorito (si lo hay) o en la primera liga del torneo.
class SelectorLiga extends StatelessWidget {
  const SelectorLiga({super.key, required this.ligaId, required this.onCambio});
  final String? ligaId;
  final ValueChanged<String> onCambio;

  @override
  Widget build(BuildContext context) {
    final ligas = datos.ligasActuales;
    if (ligas.isEmpty) return const SizedBox.shrink();
    final actual = datos.liga(ligaId ?? '') ?? ligas.first;
    final cats = <Categoria>[];
    for (final l in ligas) {
      final c = datos.categoria(l.categoriaId);
      if (c != null && !cats.any((x) => x.id == c.id)) cats.add(c);
    }
    final niveles = <Nivel>[];
    for (final l in ligas.where((l) => l.categoriaId == actual.categoriaId)) {
      final n = Nivel.de(l.nivelId);
      if (!niveles.any((x) => x.id == n.id)) niveles.add(n);
    }
    final grupos = datos.gruposDe(actual);

    Widget desplegable<T>(String etiqueta, T valor, List<(T, String)> opciones, ValueChanged<T> cambio) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(etiqueta.toUpperCase(), style: MarbelText.etiqueta(color: MarbelColors.apagado, size: 12)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: MarbelColors.tarjeta,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2B35A6)),
            ),
            child: DropdownButton<T>(
              value: valor,
              underline: const SizedBox.shrink(),
              dropdownColor: MarbelColors.tarjeta,
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: MarbelColors.blanco),
              items: [
                for (final o in opciones) DropdownMenuItem<T>(value: o.$1, child: Text(o.$2)),
              ],
              onChanged: (v) {
                if (v != null) cambio(v);
              },
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        desplegable<String>('Categoría', actual.categoriaId, [for (final c in cats) (c.id, c.nombre)], (c) {
          final l = ligas.where((x) => x.categoriaId == c && x.nivelId == actual.nivelId).firstOrNull ??
              ligas.firstWhere((x) => x.categoriaId == c);
          onCambio(l.id);
        }),
        if (niveles.length > 1)
          desplegable<String>('Nivel', actual.nivelId, [for (final n in niveles) (n.id, n.nombre)], (n) {
            final l = ligas.firstWhere((x) => x.categoriaId == actual.categoriaId && x.nivelId == n);
            onCambio(l.id);
          }),
        if (grupos.length > 1)
          desplegable<String>('Grupo', actual.id, [for (final g in grupos) (g.id, 'Grupo ${g.grupo ?? ''}')], onCambio),
      ],
    );
  }
}

/// Primera liga a mostrar: la de un equipo favorito, o la primera.
String? ligaInicial() {
  for (final e in favoritos.equipos) {
    final l = datos.ligasDeEquipo(e);
    if (l.isNotEmpty) return l.first.id;
  }
  final ls = datos.ligasActuales;
  return ls.isEmpty ? null : ls.first.id;
}

/// Bloque "Competición": pestañas Liguilla / Fase final de una liga.
class Competicion extends StatefulWidget {
  const Competicion({super.key, this.titulo = true});
  final bool titulo;

  @override
  State<Competicion> createState() => _CompeticionState();
}

class _CompeticionState extends State<Competicion> {
  String? _liga;
  bool _final = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([datos, favoritos]),
      builder: (context, _) {
        final ligas = datos.ligasActuales;
        if (ligas.isEmpty) {
          return const EstadoVacio(
              'Las ligas se publican cuando la organización cierre las inscripciones. '
              'Aquí verás la clasificación y la fase final de cada categoría.',
              icono: Icons.emoji_events_outlined);
        }
        _liga ??= ligaInicial();
        final ligaId = datos.liga(_liga ?? '') == null ? ligas.first.id : _liga!;
        final nivel = datos.nivelDeLiga(ligaId);
        final ancho = esAncho(context);
        final partidos = datos.partidosDeLiga(ligaId).where((p) => p.fase == Fase.liga).toList();

        final pestanas = Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: MarbelColors.tarjeta, borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, t) in [(false, 'Liguilla'), (true, 'Fase final')].indexed)
                Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                  child: Material(
                    color: _final == t.$1 ? MarbelColors.azul : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _final = t.$1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        child: Text(t.$2.toUpperCase(),
                            style: MarbelText.titular(18,
                                    color: _final == t.$1 ? MarbelColors.blanco : MarbelColors.apagado)
                                .copyWith(fontStyle: FontStyle.normal)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        final clasif = Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('CLASIFICACIÓN',
                        style: MarbelText.titular(24).copyWith(fontStyle: FontStyle.normal)),
                  ),
                  Text('Jornada ${datos.jornadaActual(ligaId)} de ${datos.jornadasTotales(ligaId)}',
                      style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              TablaClasificacion(ligaId: ligaId, completa: true),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _Leyenda(),
                  Text('1º vs 4º · 2º vs 3º', style: TextStyle(color: MarbelColors.apagado, fontSize: 13)),
                  Text('Empate a puntos: diferencia de goles, luego goles a favor',
                      style: TextStyle(color: MarbelColors.apagado, fontSize: 13)),
                ],
              ),
            ],
          ),
        );

        final lista = Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PARTIDOS DE LA LIGA',
                  style: MarbelText.titular(24).copyWith(fontStyle: FontStyle.normal)),
              const SizedBox(height: 10),
              if (partidos.isEmpty)
                const Text('El calendario de esta liga aún no está publicado.',
                    style: TextStyle(color: MarbelColors.apagado))
              else
                for (final p in partidos) _FilaPartidoLiga(p),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                if (widget.titulo)
                  Text('COMPETICIÓN', style: MarbelText.titular(ancho ? 40 : 32)),
                pestanas,
                SelectorLiga(ligaId: ligaId, onCambio: (l) => setState(() => _liga = l)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: nivel.color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${datos.nombreLiga(ligaId, corto: false)} · Liga de ${datos.equiposDeLiga[ligaId]?.length ?? 0} equipos · los 4 primeros pasan a semifinales',
                    style: const TextStyle(color: MarbelColors.apagado, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_final)
              CuadroFinal(ligaId: ligaId)
            else if (ancho)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 135, child: clasif),
                  const SizedBox(width: 16),
                  Expanded(flex: 100, child: lista),
                ],
              )
            else
              Column(children: [clasif, const SizedBox(height: 14), lista]),
          ],
        );
      },
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: MarbelColors.cian, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        const Text('Semifinal', style: TextStyle(color: MarbelColors.apagado, fontSize: 13)),
      ],
    );
  }
}

class _FilaPartidoLiga extends StatelessWidget {
  const _FilaPartidoLiga(this.p);
  final Partido p;

  @override
  Widget build(BuildContext context) {
    final fin = p.estado == Estado.finalizado && p.tieneMarcador;
    final vivo = p.estado == Estado.enJuego;
    final g = p.ganadorId;
    TextStyle estilo(String? id) => TextStyle(
          fontSize: 14,
          fontWeight: fin && g == id ? FontWeight.w800 : FontWeight.w600,
          color: fin && g != null && g != id ? const Color(0xFF8F99D6) : MarbelColors.blanco,
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: MarbelColors.fondoAlto, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('J${p.jornada ?? ''}',
                style: const TextStyle(color: MarbelColors.apagado, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(datos.nombreEquipo(p.localId),
                textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: estilo(p.localId)),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            constraints: const BoxConstraints(minWidth: 56),
            decoration: BoxDecoration(
              color: vivo ? MarbelColors.enJuego : (fin ? MarbelColors.azul : const Color(0xFF1E2672)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              fin || vivo ? '${p.golesLocal ?? 0} - ${p.golesVisitante ?? 0}' : hhmm(p.horaReal),
              textAlign: TextAlign.center,
              style: MarbelText.titular(17, color: fin || vivo ? MarbelColors.blanco : MarbelColors.apagado)
                  .copyWith(fontStyle: FontStyle.normal),
            ),
          ),
          Expanded(
            child: Text(datos.nombreEquipo(p.visitanteId),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: estilo(p.visitanteId)),
          ),
        ],
      ),
    );
  }
}
