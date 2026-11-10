import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/contenido.dart';
import '../data/sesion.dart';
import '../theme/app_theme.dart';
import 'comunes.dart';
import 'conexion.dart';

class _Seccion {
  const _Seccion(this.ruta, this.nombre, this.icono);
  final String ruta;
  final String nombre;
  final IconData icono;
}

/// Menú de la web (ordenador).
const _web = [
  _Seccion('/', 'Inicio', Icons.home_rounded),
  _Seccion('/torneo', 'El torneo', Icons.info_rounded),
  _Seccion('/calendario', 'Calendario', Icons.calendar_month_rounded),
  _Seccion('/equipos', 'Equipos', Icons.shield_rounded),
  _Seccion('/estadisticas', 'Estadísticas', Icons.bar_chart_rounded),
  _Seccion('/porra', 'La Porra', Icons.emoji_events_rounded),
  _Seccion('/galeria', 'Galería', Icons.photo_library_rounded),
];

/// Pestañas de la app (móvil).
const _app = [
  _Seccion('/', 'Inicio', Icons.home_rounded),
  _Seccion('/calendario', 'Partidos', Icons.calendar_month_rounded),
  _Seccion('/porra', 'Porra', Icons.emoji_events_rounded),
  _Seccion('/equipos', 'Equipos', Icons.shield_rounded),
  _Seccion('/mas', 'Más', Icons.more_horiz_rounded),
];

int _indice(List<_Seccion> s, String ruta, {int siNo = -1}) {
  final i = s.indexWhere((x) => x.ruta == '/' ? ruta == '/' : ruta.startsWith(x.ruta));
  return i < 0 ? siNo : i;
}

/// Marco común: barra superior en ordenador, pestañas abajo en móvil.
class MarcoApp extends StatelessWidget {
  const MarcoApp({super.key, required this.ubicacion, required this.child});
  final String ubicacion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (esAncho(context)) {
      return Scaffold(
        body: Column(
          children: [
            _BarraSuperior(indice: _indice(_web, ubicacion)),
            const FranjaConexion(),
            Expanded(child: child),
          ],
        ),
      );
    }
    // En móvil, lo que no es una pestaña cuelga de "Más".
    final i = _indice(_app, ubicacion, siNo: 4);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [const FranjaConexion(), Expanded(child: child)]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (n) => context.go(_app[n].ruta),
        destinations: [
          for (final s in _app) NavigationDestination(icon: Icon(s.icono), label: s.nombre),
        ],
      ),
    );
  }
}

class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior({required this.indice});
  final int indice;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MarbelColors.fondo,
        border: Border(bottom: BorderSide(color: Color(0xFF1A2170))),
      ),
      child: AnchoMax(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            InkWell(
              onTap: () => context.go('/'),
              borderRadius: BorderRadius.circular(30),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LogoMarbel(tamano: 52),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MARBEL', style: MarbelText.titular(24)),
                      Text('FOOTBALL CUP', style: MarbelText.etiqueta(size: 15)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < _web.length; i++)
                      TextButton(
                        onPressed: () => context.go(_web[i].ruta),
                        style: TextButton.styleFrom(
                          foregroundColor: i == indice ? MarbelColors.cian : MarbelColors.texto2,
                          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        child: Text(_web[i].nombre),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            ListenableBuilder(
              listenable: sesion,
              builder: (context, _) {
                final p = sesion.perfil;
                if (p == null) {
                  return TextButton(
                    onPressed: () => context.go('/porra'),
                    style: TextButton.styleFrom(foregroundColor: MarbelColors.texto2),
                    child: const Text('Entrar', style: TextStyle(fontWeight: FontWeight.w700)),
                  );
                }
                return PopupMenuButton<String>(
                  tooltip: 'Mi cuenta',
                  color: MarbelColors.tarjeta,
                  onSelected: (v) async {
                    if (v == 'salir') {
                      await sesion.salir();
                    } else if (context.mounted) {
                      context.go(v);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: '/porra', child: Text('Mi porra')),
                    if (p.esPersonal) const PopupMenuItem(value: '/gestion', child: Text('Panel de gestión')),
                    const PopupMenuItem(value: 'salir', child: Text('Cerrar sesión')),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: MarbelColors.azul,
                        child: Text(p.iniciales,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13, color: MarbelColors.blanco)),
                      ),
                      const SizedBox(width: 8),
                      Text(p.nombreCorto, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            FilledButton(
              onPressed: () => abrir(Contenido.whatsappUrl1),
              child: const Text('INSCRIBE TU EQUIPO'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Escudo redondo de Marbel con el aro cian.
class LogoMarbel extends StatelessWidget {
  const LogoMarbel({super.key, this.tamano = 52, this.brillo = false});
  final double tamano;
  final bool brillo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: MarbelColors.cian, width: tamano * .04 + 1),
        boxShadow: brillo
            ? const [BoxShadow(color: Color(0x592EE6F2), blurRadius: 80, spreadRadius: 10)]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.jpg',
          fit: BoxFit.cover,
          semanticLabel: 'Escudo de Marbel Football Cup',
        ),
      ),
    );
  }
}

/// Cabecera de las pantallas en móvil (título grande + acciones).
class CabeceraMovil extends StatelessWidget {
  const CabeceraMovil(this.titulo, {super.key, this.atras = false, this.derecha});
  final String titulo;
  final bool atras;
  final Widget? derecha;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (atras) ...[
            Material(
              color: MarbelColors.tarjeta,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Volver',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => context.canPop() ? context.pop() : context.go('/mas'),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(titulo.toUpperCase(),
                style: MarbelText.titular(atras ? 32 : 38)),
          ),
          if (derecha != null) derecha!,
        ],
      ),
    );
  }
}
