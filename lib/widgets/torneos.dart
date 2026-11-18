import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/contenido.dart';
import '../data/datos.dart';
import '../data/modelos.dart';
import '../theme/app_theme.dart';
import 'comunes.dart';
import 'mapa_sedes.dart';

/// "Benjamín 1º año · Benjamín 2º año": categorías del torneo elegido.
String categoriasDelTorneo() {
  final vistas = <String>[];
  for (final l in datos.ligasActuales) {
    final c = datos.categoria(l.categoriaId)?.nombre;
    if (c != null && !vistas.contains(c)) vistas.add(c);
  }
  return vistas.join(' · ');
}

// ---------------------------------------------------------------------------
// Rutas de un torneo: /torneos/<id>/<apartado>
// ---------------------------------------------------------------------------

/// Apartados de la página de cada torneo (ruta, nombre).
const apartadosTorneo = [
  ('', 'Información'),
  ('calendario', 'Calendario'),
  ('equipos', 'Equipos'),
  ('estadisticas', 'Estadísticas'),
  ('porra', 'La Porra'),
  ('avisos', 'Avisos'),
];

/// "/torneos/<id>/calendario" del torneo [id] (o del que se está viendo).
String rutaTorneo([String apartado = '', String? id]) {
  final t = id ?? datos.torneo?.id;
  if (t == null) return '/torneos';
  return apartado.isEmpty ? '/torneos/$t' : '/torneos/$t/$apartado';
}

/// Enlace para inscribirse en un torneo (el de su proyecto o el WhatsApp de Marbel).
String enlaceInscripcion(Torneo t) => t.proyecto?.inscripcionUrl ?? Contenido.whatsappUrl1;

// ---------------------------------------------------------------------------
// En qué momento está un torneo (cuenta atrás, «en juego», finalizado)
// ---------------------------------------------------------------------------
enum FaseTorneo { antes, descanso, jugando, finalizado }

({FaseTorneo fase, DateTime objetivo, int jornada, int total}) faseDe(Torneo t) {
  final ahora = DateTime.now();
  final js = datos.jornadasDe(t);
  final desde = t.proyecto?.horaDesde ?? 9, hasta = t.proyecto?.horaHasta ?? 21;
  for (var i = 0; i < js.length; i++) {
    final ini = js[i].add(Duration(hours: desde));
    final fin = js[i].add(Duration(hours: hasta));
    if (!ahora.isBefore(ini) && !ahora.isAfter(fin)) {
      return (fase: FaseTorneo.jugando, objetivo: ini, jornada: i, total: js.length);
    }
  }
  for (var i = 0; i < js.length; i++) {
    final ini = js[i].add(Duration(hours: desde));
    if (ini.isAfter(ahora)) {
      return (fase: i == 0 ? FaseTorneo.antes : FaseTorneo.descanso, objetivo: ini, jornada: i, total: js.length);
    }
  }
  return (fase: FaseTorneo.finalizado, objetivo: ahora, jornada: js.length - 1, total: js.length);
}

/// Pastilla con el momento del torneo: «Próximamente», «En juego ahora»...
Widget pastillaFase(Torneo t, {double tamano = 12}) {
  if (t.anterior) return Pastilla('Finalizado', fondo: const Color(0xFF1E2672), color: MarbelColors.texto2, tamano: tamano);
  final f = faseDe(t);
  final (texto, fondo, color) = switch (f.fase) {
    FaseTorneo.antes => ('Próximamente', MarbelColors.cian, MarbelColors.fondo),
    FaseTorneo.descanso => ('En juego · próxima jornada ${f.objetivo.day} ${mesCorto(f.objetivo)}', MarbelColors.enJuego, MarbelColors.blanco),
    FaseTorneo.jugando => ('En juego ahora', MarbelColors.enJuego, MarbelColors.blanco),
    FaseTorneo.finalizado => ('Finalizado', const Color(0xFF1E2672), MarbelColors.texto2),
  };
  return Pastilla(texto, fondo: fondo, color: color, tamano: tamano);
}

// ---------------------------------------------------------------------------
// Banners de los torneos
// ---------------------------------------------------------------------------

/// Banners de varios torneos, en rejilla. Al tocar uno se entra en su página.
class BannersTorneos extends StatelessWidget {
  const BannersTorneos(this.torneos, {super.key});
  final List<Torneo> torneos;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 2 : 1;
      final w = (c.maxWidth - 16 * (cols - 1)) / cols;
      return Wrap(spacing: 16, runSpacing: 16, children: [
        for (final t in torneos) SizedBox(width: w, child: BannerTorneo(t)),
      ]);
    });
  }
}

class BannerTorneo extends StatelessWidget {
  const BannerTorneo(this.t, {super.key});
  final Torneo t;

  @override
  Widget build(BuildContext context) {
    final p = t.proyecto;
    return Semantics(
      button: true,
      label: '${t.nombre}. Entrar',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => context.go(rutaTorneo('', t.id)),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: MarbelColors.borde),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MarbelColors.azul, Color(0xFF1A1FA8), MarbelColors.tarjeta],
                stops: [0, .45, 1],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  pastillaFase(t, tamano: 11),
                  const SizedBox(height: 10),
                  Text(t.nombre.toUpperCase(), style: MarbelText.titular(30)),
                  if (p?.etiqueta != null) ...[
                    const SizedBox(height: 4),
                    Text(p!.etiqueta!.toUpperCase(), style: MarbelText.etiqueta(size: 12)),
                  ],
                  const SizedBox(height: 10),
                  Wrap(spacing: 16, runSpacing: 4, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.event_rounded, size: 16, color: MarbelColors.texto2),
                      const SizedBox(width: 6),
                      Text(t.fechasTexto, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                    if (t.lugar != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.place_rounded, size: 16, color: MarbelColors.texto2),
                        const SizedBox(width: 6),
                        Text(t.lugar!, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                  ]),
                  if (!t.anterior) ContadorTorneo(t),
                ]),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: MarbelColors.cian, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_rounded, color: MarbelColors.fondo),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Cuenta atrás pequeña de un torneo (para su banner): cuánto falta para que
/// empiece o para su próxima jornada; mientras se juega, «Se está jugando ahora».
class ContadorTorneo extends StatefulWidget {
  const ContadorTorneo(this.t, {super.key});
  final Torneo t;

  @override
  State<ContadorTorneo> createState() => _ContadorTorneoState();
}

class _ContadorTorneoState extends State<ContadorTorneo> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = faseDe(widget.t);
    if (f.fase == FaseTorneo.finalizado) return const SizedBox.shrink();

    if (f.fase == FaseTorneo.jugando) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: MarbelColors.enJuego, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              f.total > 1 ? 'SE ESTÁ JUGANDO · JORNADA ${f.jornada + 1} DE ${f.total}' : 'SE ESTÁ JUGANDO AHORA',
              style: MarbelText.etiqueta(size: 13),
            ),
          ),
        ]),
      );
    }

    var resta = f.objetivo.difference(DateTime.now());
    if (resta.isNegative) resta = Duration.zero;
    final d = resta.inDays, h = resta.inHours % 24, m = resta.inMinutes % 60, sg = resta.inSeconds % 60;
    String dos(int x) => x.toString().padLeft(2, '0');
    final unidades = [
      if (d > 0) ('$d', d == 1 ? 'DÍA' : 'DÍAS'),
      (dos(h), 'H'),
      (dos(m), 'MIN'),
      (dos(sg), 'SEG'),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(f.fase == FaseTorneo.antes ? 'EMPIEZA EN' : 'PRÓXIMA JORNADA EN',
            style: MarbelText.etiqueta(color: MarbelColors.texto2, size: 11)),
        const SizedBox(height: 6),
        Semantics(
          label: '${f.fase == FaseTorneo.antes ? 'Empieza en' : 'Próxima jornada en'} '
              '${d > 0 ? '$d días, ' : ''}$h horas y $m minutos',
          excludeSemantics: true,
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (i, (n, u)) in unidades.indexed)
              Container(
                constraints: const BoxConstraints(minWidth: 52),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: MarbelColors.fondo.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MarbelColors.borde),
                ),
                child: Column(children: [
                  Text(n,
                      style: MarbelText.titular(24, color: i == 0 ? MarbelColors.cian : MarbelColors.blanco)
                          .copyWith(fontStyle: FontStyle.normal, height: 1.05)),
                  Text(u, style: MarbelText.etiqueta(color: MarbelColors.apagado, size: 10)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Aviso cuando no hay ningún torneo en marcha.
class SinTorneos extends StatelessWidget {
  const SinTorneos({super.key, this.enlaceAnteriores = true});

  /// Botón «Ver torneos anteriores» (si los hay). En la página Torneos no
  /// hace falta: salen justo debajo.
  final bool enlaceAnteriores;

  // Se vuelve a pintar cuando cambian los datos (aunque se use con `const`)
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: datos, builder: (context, _) => _pintar(context));

  Widget _pintar(BuildContext context) {
    final ancho = esAncho(context);
    return Tarjeta(
      padding: EdgeInsets.all(ancho ? 32 : 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.emoji_events_outlined, color: MarbelColors.cian, size: 40),
        const SizedBox(height: 10),
        Text('AHORA MISMO NO HAY NINGÚN TORNEO EN MARCHA', style: MarbelText.titular(ancho ? 34 : 26).copyWith(fontStyle: FontStyle.normal)),
        const SizedBox(height: 8),
        const Text(
          'Muy pronto anunciaremos el próximo. Síguenos en Instagram o escríbenos por WhatsApp para enterarte el primero.',
          style: TextStyle(color: MarbelColors.texto2, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (enlaceAnteriores && datos.torneosAnteriores.isNotEmpty)
            BotonCian('Ver torneos anteriores', icono: Icons.emoji_events_rounded, onTap: () => context.go('/torneos')),
          BotonCian('Instagram', icono: Marca.instagram, onTap: () => abrir(Contenido.instagramUrl)),
          BotonContorno('WhatsApp', icono: Marca.whatsapp, onTap: () => abrir(Contenido.whatsappUrl1)),
          BotonContorno('Galería', onTap: () => context.go('/galeria')),
        ]),
      ]),
    );
  }
}

/// Ficha de una sede: foto, servicios y cómo llegar.
class TarjetaSede extends StatelessWidget {
  const TarjetaSede(this.s, {super.key});
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

/// Las sedes del torneo en tarjetas (una o dos columnas).
class SedesDelTorneo extends StatelessWidget {
  const SedesDelTorneo({super.key});

  // Se vuelve a pintar cuando cambian los datos (aunque se use con `const`)
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: datos, builder: (context, _) => _pintar(context));

  Widget _pintar(BuildContext context) {
    final sedes = datos.sedesTorneo;
    if (sedes.isEmpty) return const EstadoVacio('La sede se publicará pronto.');
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 700 && sedes.length > 1 ? 2 : 1;
      final w = (c.maxWidth - 16 * (cols - 1)) / cols;
      return Wrap(spacing: 16, runSpacing: 16, children: [
        for (final s in sedes) SizedBox(width: cols == 1 && c.maxWidth >= 700 ? c.maxWidth / 2 : w, child: TarjetaSede(s)),
      ]);
    });
  }
}
