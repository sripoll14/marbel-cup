import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/datos.dart';
import '../data/sesion.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/marco_app.dart';
import '../widgets/torneos.dart';
import 'avisos_screen.dart';
import 'calendario_screen.dart';
import 'equipos_screen.dart';
import 'estadisticas_screen.dart';
import 'porra_screen.dart';
import 'resumen_screen.dart';
import 'torneo_screen.dart';

/// «Torneos»: un banner por cada torneo en marcha (aunque solo haya uno).
class TorneosScreen extends StatelessWidget {
  const TorneosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ConDatos(builder: (context) {
      final ancho = esAncho(context);
      final visibles = datos.torneosVisibles;
      final anteriores = datos.torneosAnteriores;
      final cuerpo = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        visibles.isEmpty ? const SinTorneos(enlaceAnteriores: false) : BannersTorneos(visibles),
        if (anteriores.isNotEmpty) ...[
          SizedBox(height: ancho ? 56 : 36),
          Text('TORNEOS ANTERIORES', style: MarbelText.titular(ancho ? 40 : 30)),
          const SizedBox(height: 4),
          const Text('Resultados, clasificaciones y estadísticas de los torneos que ya se han jugado.',
              style: TextStyle(color: MarbelColors.texto2)),
          const SizedBox(height: 16),
          BannersTorneos(anteriores),
        ],
      ]);
      if (!ancho) {
        return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          const CabeceraMovil('Torneos'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: cuerpo),
        ]);
      }
      return PaginaPublica(children: [
        const SizedBox(height: 48),
        AnchoMax(
          child: TituloSeccion(
            etiqueta: visibles.length == 1 ? 'Torneo en marcha' : (visibles.isEmpty ? null : 'Torneos en marcha'),
            titulo: 'Torneos',
            tamano: 80,
          ),
        ),
        const SizedBox(height: 24),
        AnchoMax(child: cuerpo),
      ]);
    });
  }
}

/// Página de un torneo: su cabecera con las pestañas (Información, Calendario,
/// Equipos, Estadísticas, La Porra, Avisos) y debajo el apartado elegido.
class TorneoPagina extends StatelessWidget {
  const TorneoPagina({super.key, required this.id, this.apartado = ''});
  final String id;
  final String apartado;

  @override
  Widget build(BuildContext context) {
    return ConDatos(builder: (context) {
      datos.fijarTorneo(id);
      final t = datos.torneo;
      // No existe, o está oculto y quien mira no es del personal
      if (t == null || t.id != id || (!t.visible && !t.anterior && !sesion.esPersonal)) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.emoji_events_outlined, size: 48, color: MarbelColors.apagado),
              const SizedBox(height: 12),
              const Text('Este torneo no está disponible ahora mismo.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              BotonCian('Ver los torneos', onTap: () => context.go('/torneos')),
            ]),
          ),
        );
      }
      // Torneo terminado: una sola página con el resumen
      if (t.anterior) {
        return DentroDeTorneo(child: KeyedSubtree(key: ValueKey('resumen/$id'), child: const ResumenTorneo()));
      }
      final cuerpo = switch (apartado) {
        'calendario' => const CalendarioScreen(),
        'equipos' => const EquiposScreen(),
        'estadisticas' => const EstadisticasScreen(),
        'porra' => const PorraScreen(),
        'avisos' => const AvisosScreen(),
        _ => const TorneoScreen(),
      };
      return DentroDeTorneo(
        child: Column(children: [
          _CabeceraTorneo(apartado: apartado),
          Expanded(child: KeyedSubtree(key: ValueKey('$id/$apartado'), child: cuerpo)),
        ]),
      );
    });
  }
}

class _CabeceraTorneo extends StatelessWidget {
  const _CabeceraTorneo({required this.apartado});
  final String apartado;

  @override
  Widget build(BuildContext context) {
    final t = datos.torneo!;
    final ancho = esAncho(context);
    final pestanas = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final (ruta, nombre) in apartadosTorneo)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _Pestana(
              nombre,
              elegida: ruta == apartado || (ruta.isEmpty && !apartadosTorneo.any((a) => a.$1 == apartado)),
              onTap: () => context.go(rutaTorneo(ruta, t.id)),
            ),
          ),
      ]),
    );
    final nombre = Row(children: [
      if (!ancho)
        IconButton(
          tooltip: 'Torneos',
          onPressed: () => context.go('/torneos'),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(t.nombre.toUpperCase(),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: MarbelText.titular(ancho ? 30 : 22)),
          Text([t.fechasTexto, if (t.lugar != null) t.lugar!].join(' · '),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
        ]),
      ),
      if (ancho) ...[
        const SizedBox(width: 12),
        FilledButton(onPressed: () => abrir(enlaceInscripcion(t)), child: const Text('INSCRIBE TU EQUIPO')),
      ],
    ]);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: MarbelColors.fondoAlto,
        border: Border(bottom: BorderSide(color: Color(0xFF1A2170))),
      ),
      child: AnchoMax(
        padding: EdgeInsets.fromLTRB(ancho ? 24 : 4, ancho ? 16 : 8, ancho ? 24 : 12, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          nombre,
          const SizedBox(height: 8),
          Padding(padding: EdgeInsets.only(left: ancho ? 0 : 12), child: pestanas),
        ]),
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana(this.texto, {required this.elegida, required this.onTap});
  final String texto;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: elegida,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: elegida ? MarbelColors.cian : Colors.transparent, width: 3)),
          ),
          child: Text(texto,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: elegida ? MarbelColors.cian : MarbelColors.texto2,
              )),
        ),
      ),
    );
  }
}

/// Las direcciones de antes (/calendario, /porra, /avisos...): si hay un solo
/// torneo en marcha, a ese apartado; si hay varios o ninguno, a «Torneos».
class RedirigirTorneo extends StatefulWidget {
  const RedirigirTorneo(this.apartado, {super.key});
  final String apartado;

  @override
  State<RedirigirTorneo> createState() => _RedirigirTorneoState();
}

class _RedirigirTorneoState extends State<RedirigirTorneo> {
  bool _hecho = false;

  @override
  Widget build(BuildContext context) {
    return ConDatos(builder: (context) {
      if (!_hecho) {
        _hecho = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // Un torneo en marcha: a ese. Varios o ninguno: a la lista de Torneos.
          final visibles = datos.torneosVisibles;
          context.go(visibles.length == 1 ? rutaTorneo(widget.apartado, visibles.first.id) : '/torneos');
        });
      }
      return const Center(child: CircularProgressIndicator());
    });
  }
}
