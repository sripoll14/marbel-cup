import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/contenido.dart';
import '../data/datos.dart';
import '../data/modelos.dart';
import '../theme/app_theme.dart';
import '../widgets/comentarios.dart';
import '../widgets/comunes.dart';
import '../widgets/mapa_sedes.dart';
import '../widgets/marco_app.dart';
import 'calendario_screen.dart';

/// Ficha del torneo: datos, qué se juega, sedes, qué incluye, élite, precios y FAQ.
class TorneoScreen extends StatefulWidget {
  const TorneoScreen({super.key});

  @override
  State<TorneoScreen> createState() => _TorneoScreenState();
}

class _TorneoScreenState extends State<TorneoScreen> {
  String _nivel = 'todos';
  int _abierta = 0;

  @override
  Widget build(BuildContext context) {
    return ConDatos(builder: (context) {
      final ancho = esAncho(context);
      final t = datos.torneo;
      final hueco = SizedBox(height: ancho ? 56 : 36);

      final contenido = <Widget>[
        // Cabecera
        TextButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Volver al inicio'),
        ),
        const SizedBox(height: 8),
        Text.rich(TextSpan(children: [
          TextSpan(text: 'IV TORNEO\n', style: MarbelText.titular(ancho ? 96 : 54)),
          TextSpan(text: 'NAVIDEÑO', style: MarbelText.titular(ancho ? 96 : 54, color: MarbelColors.cian)),
        ])),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) {
          final datosT = [
            ('Fechas', t?.fechasTexto ?? '26–27 dic · 2–3 ene'),
            ('Sedes', '4 en la Vega Baja'),
            ('Modalidades', 'Fútbol 8 y 11'),
            ('Partidos', 'Mínimo 4 por equipo'),
          ];
          final cols = ancho ? 4 : 2;
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
          BotonCian('Calendario y clasificación', onTap: () => context.go('/calendario')),
          BotonContorno('Equipos inscritos', onTap: () => context.go('/equipos')),
          BotonContorno('Estadísticas', onTap: () => context.go('/estadisticas')),
          BotonContorno('Juega a La Porra', onTap: () => context.go('/porra')),
        ]),
        hueco,

        // Qué se juega
        const TituloSeccion(titulo: 'Qué se juega, cuándo y dónde'),
        const SizedBox(height: 14),
        FilaChips(children: [
          ChipFiltro(texto: 'Todos', punto: MarbelColors.blanco, elegido: _nivel == 'todos', colorElegido: MarbelColors.blanco, onTap: () => setState(() => _nivel = 'todos')),
          for (final n in Nivel.todos)
            ChipFiltro(texto: n.nombre, punto: n.color, elegido: _nivel == n.id, colorElegido: MarbelColors.blanco, onTap: () => setState(() => _nivel = n.id)),
        ]),
        const SizedBox(height: 14),
        for (final d in Contenido.horario) ...[RejillaDia(dia: d, nivel: _nivel), const SizedBox(height: 12)],
        const Text(
          'Dos sedes con la misma categoría «todo el día» = esa categoría juega repartida entre las dos. Toca un nivel para resaltar solo sus partidos.',
          style: TextStyle(color: MarbelColors.apagado, fontSize: 14),
        ),
        hueco,

        // Sedes
        const TituloSeccion(titulo: 'Las sedes'),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 700 ? 2 : 1;
          final w = (c.maxWidth - 16 * (cols - 1)) / cols;
          return Wrap(spacing: 16, runSpacing: 16, children: [
            for (final s in datos.sedes) SizedBox(width: w, child: _TarjetaSede(s)),
          ]);
        }),
        hueco,

        // Qué incluye
        const TituloSeccion(titulo: 'Qué incluye'),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 900 ? 4 : 2;
          final w = (c.maxWidth - 12 * (cols - 1)) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final (icono, texto) in Contenido.incluye)
              SizedBox(
                width: w,
                height: ancho ? 150 : 140,
                child: Tarjeta(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: MarbelColors.azul, borderRadius: BorderRadius.circular(16)),
                      child: Icon(icono, color: MarbelColors.cian, size: 26),
                    ),
                    const Spacer(),
                    Text(texto, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.3)),
                  ]),
                ),
              ),
          ]);
        }),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 700 ? 2 : 1;
          final w = (c.maxWidth - 12 * (cols - 1)) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: MarbelColors.enJuego, borderRadius: BorderRadius.circular(18)),
                child: const Row(children: [
                  Icon(Icons.military_tech_rounded, size: 30),
                  SizedBox(width: 14),
                  Expanded(child: Text(Contenido.premiosTexto, style: TextStyle(fontWeight: FontWeight.w700, height: 1.4))),
                ]),
              ),
            ),
            SizedBox(
              width: w,
              child: Tarjeta(
                borde: MarbelColors.enJuego,
                child: const Row(children: [
                  Icon(Icons.celebration_rounded, size: 30, color: MarbelColors.enJuego),
                  SizedBox(width: 14),
                  Expanded(child: Text(Contenido.ceremoniaTexto, style: TextStyle(fontWeight: FontWeight.w700, height: 1.4))),
                ]),
              ),
            ),
          ]);
        }),
        hueco,

        // Élite
        const TituloSeccion(etiqueta: 'Cabezas de serie confirmados', titulo: 'Categoría Élite'),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 900 ? 3 : 2;
          final w = (c.maxWidth - 12 * (cols - 1)) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final nombre in Contenido.elite)
              SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: nombre == null ? MarbelColors.fondoAlto : MarbelColors.azul,
                    borderRadius: BorderRadius.circular(18),
                    border: nombre == null ? Border.all(color: const Color(0xFF2B35A6), width: 2) : null,
                  ),
                  child: Row(children: [
                    if (nombre == null)
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFF131B6B), borderRadius: BorderRadius.circular(12)),
                        child: const Text('?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF8F99D6))),
                      )
                    else
                      Escudo(datos.equipos.where((e) => e.nombre == nombre).firstOrNull, tamano: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(nombre ?? 'Por anunciar',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: nombre == null ? const Color(0xFF8F99D6) : MarbelColors.blanco)),
                    ),
                  ]),
                ),
              ),
          ]);
        }),
        hueco,

        // Precios
        TituloSeccion(
          titulo: 'Precios y cómo participar',
          derecha: const Pastilla('Plazas limitadas', fondo: MarbelColors.enJuego, color: MarbelColors.blanco, tamano: 13),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final ancho2 = c.maxWidth >= 800;
          final precios = Row(children: [
            for (final (i, (m, p)) in Contenido.precios.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: i == 0 ? MarbelColors.azul : MarbelColors.cian,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.toUpperCase(), style: MarbelText.etiqueta(color: i == 0 ? MarbelColors.cian : MarbelColors.fondo)),
                    Text(p, style: MarbelText.titular(64, color: i == 0 ? MarbelColors.blanco : MarbelColors.fondo)),
                    Text('por equipo', style: TextStyle(fontWeight: FontWeight.w700, color: i == 0 ? MarbelColors.texto2 : MarbelColors.fondo)),
                  ]),
                ),
              ),
            ],
          ]);
          final pasos = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (i, (titulo, texto)) in Contenido.pasos.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Tarjeta(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: MarbelColors.cian, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: MarbelText.titular(22, color: MarbelColors.fondo).copyWith(fontStyle: FontStyle.normal)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(texto, style: const TextStyle(color: MarbelColors.texto2)),
                      ]),
                    ),
                  ]),
                ),
              ),
            const Text(Contenido.avisoReserva, style: TextStyle(color: MarbelColors.apagado, fontSize: 13)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              BotonCian('Reservar por WhatsApp', icono: Marca.whatsapp, onTap: () => abrir(Contenido.whatsappUrl1)),
              BotonContorno('Escribir un email', icono: Marca.gmail, onTap: () => abrir('mailto:${Contenido.email}')),
            ]),
          ]);
          return ancho2
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: precios),
                  const SizedBox(width: 20),
                  Expanded(child: pasos),
                ])
              : Column(children: [precios, const SizedBox(height: 14), pasos]);
        }),
        hueco,

        // Preguntas frecuentes
        const TituloSeccion(titulo: 'Preguntas frecuentes'),
        const SizedBox(height: 14),
        for (final (i, (q, a)) in Contenido.faqs.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Tarjeta(
              padding: EdgeInsets.zero,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _abierta = _abierta == i ? -1 : i),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      Expanded(child: Text(q, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                      Text(_abierta == i ? '−' : '+', style: MarbelText.titular(30, color: MarbelColors.cian)),
                    ]),
                  ),
                ),
                if (_abierta == i)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Text(a, style: const TextStyle(color: MarbelColors.texto2, fontSize: 16, height: 1.5)),
                  ),
              ]),
            ),
          ),
        hueco,

        // Comentarios del torneo (para escribir hace falta cuenta)
        const TituloSeccion(etiqueta: 'Escribe a la Marea Azul', titulo: 'Comentarios'),
        const SizedBox(height: 14),
        Comentarios(key: ValueKey(datos.torneo?.id), torneoId: datos.torneo?.id),
      ];

      if (!ancho) {
        return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          const CabeceraMovil('Info del torneo', atras: true),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: contenido)),
        ]);
      }
      return PaginaPublica(children: [
        const SizedBox(height: 32),
        AnchoMax(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: contenido)),
      ]);
    });
  }
}

class _TarjetaSede extends StatelessWidget {
  const _TarjetaSede(this.s);
  final Sede s;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: MarbelColors.tarjeta,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MarbelColors.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (s.fotoUrl != null) SizedBox(height: 240, child: Imagen(s.fotoUrl!, etiqueta: '${s.nombreOficial}, ${s.nombre}')),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.nombre.toUpperCase(), style: MarbelText.titular(26).copyWith(fontStyle: FontStyle.normal)),
            Text(s.nombreOficial, style: const TextStyle(color: MarbelColors.texto2, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final x in s.servicios) ChipServicio(x)]),
            if (s.mapsUrl != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: () => abrir(s.mapsUrl!), child: const Text('Cómo llegar ↗')),
            ],
          ]),
        ),
      ]),
    );
  }
}
