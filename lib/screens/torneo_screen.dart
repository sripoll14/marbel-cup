import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/datos.dart';
import '../theme/app_theme.dart';
import '../widgets/bloques.dart';
import '../widgets/comunes.dart';
import '../widgets/torneos.dart';

/// Información del torneo elegido: cabecera con sus datos y, debajo, los
/// bloques de su proyecto (horarios, sedes, qué incluye, precios, preguntas...).
class TorneoScreen extends StatelessWidget {
  const TorneoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ConDatos(builder: (context) {
      final ancho = esAncho(context);
      final t = datos.torneo;
      final p = datos.proyecto;
      final hueco = SizedBox(height: ancho ? 56 : 36);

      // Título en líneas: el del proyecto o, si no trae, el nombre partido en dos
      var lineas = p?.tituloInfo ?? const <String>[];
      if (lineas.isEmpty) {
        final partes = (t?.nombre ?? '').split(' ');
        lineas = partes.length > 2
            ? [partes.sublist(0, partes.length - 1).join(' '), partes.last]
            : [t?.nombre ?? ''];
      }

      // Tarjetas de datos: las del proyecto o, si no trae, las básicas
      final cats = categoriasDelTorneo();
      final datosT = (p?.datos.isNotEmpty ?? false)
          ? p!.datos
          : [
              if (t != null) ('Fechas', t.fechasTexto),
              if (t?.lugar != null) ('Dónde', t!.lugar!),
              if (cats.isNotEmpty) ('Categorías', cats),
            ];

      var bloques = p?.bloquesInfo ?? const <Map<String, dynamic>>[];
      // «Déjanos tu opinión» siempre al final de la página del torneo
      if (bloques.isNotEmpty && !bloques.any((b) => b['tipo'] == 'opinion')) {
        bloques = [
          ...bloques,
          {'tipo': 'opinion', 'etiqueta': 'Cuéntanos qué te ha parecido', 'titulo': 'Déjanos tu opinión'},
        ];
      }

      final contenido = <Widget>[
        Text.rich(TextSpan(children: [
          for (final (i, l) in lineas.indexed) ...[
            if (i > 0) const TextSpan(text: '\n'),
            TextSpan(
              text: l.toUpperCase(),
              style: MarbelText.titular(ancho ? 96 : 54,
                  color: i == lineas.length - 1 && lineas.length > 1 ? MarbelColors.cian : MarbelColors.blanco),
            ),
          ],
        ])),
        const SizedBox(height: 18),
        if (datosT.isNotEmpty)
          LayoutBuilder(builder: (context, c) {
            final cols = ancho ? (datosT.length < 4 ? datosT.length : 4) : 2;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final (k, v) in datosT)
                SizedBox(
                  width: w,
                  child: Tarjeta(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(k.toUpperCase(), style: MarbelText.etiqueta(color: MarbelColors.apagado, size: 13)),
                      const SizedBox(height: 4),
                      Text(v, style: MarbelText.titular(ancho ? 26 : 20).copyWith(fontStyle: FontStyle.normal)),
                    ]),
                  ),
                ),
            ]);
          }),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (t != null && faseDe(t).fase != FaseTorneo.finalizado)
            BotonCian('Inscribe tu equipo', icono: Marca.whatsapp, onTap: () => abrir(enlaceInscripcion(t))),
          BotonContorno('Calendario y clasificación', onTap: () => context.go(rutaTorneo('calendario'))),
          BotonContorno('Juega a La Porra', onTap: () => context.go(rutaTorneo('porra'))),
        ]),
        hueco,
        // Lo que trae el proyecto. Sin proyecto: sedes, contacto y opinión.
        BloquesProyecto(bloques.isNotEmpty
            ? bloques
            : const [
                {'tipo': 'sedes', 'titulo': 'Dónde se juega'},
                {'tipo': 'contacto', 'titulo': '¿Dudas o inscripciones?'},
                {'tipo': 'opinion', 'etiqueta': 'Cuéntanos qué te ha parecido', 'titulo': 'Déjanos tu opinión'},
              ]),
      ];

      if (!ancho) {
        return ListView(padding: const EdgeInsets.only(top: 16, bottom: 32), children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: contenido),
          ),
        ]);
      }
      return PaginaPublica(children: [
        const SizedBox(height: 32),
        AnchoMax(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: contenido)),
      ]);
    });
  }
}
