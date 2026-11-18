import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/sesion.dart';
import 'screens/galeria_screen.dart';
import 'screens/gestion/panel_screen.dart';
import 'screens/inicio_screen.dart';
import 'screens/mas_screen.dart';
import 'screens/recuperar_screen.dart';
import 'screens/torneos_screen.dart';
import 'widgets/marco_app.dart';

Page<void> _p(Widget w) => NoTransitionPage(child: w);

/// Rutas. En la web se ven como .../#/torneos/<id>/calendario...
/// El panel de gestión (/gestion) no aparece en ningún menú público.
final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: sesion,
  redirect: (context, state) {
    // Al abrir el enlace del email de recuperar contraseña.
    if (sesion.modoNuevaPassword && state.uri.path != '/recuperar') return '/recuperar';
    return null;
  },
  routes: [
    ShellRoute(
      builder: (context, state, child) => MarcoApp(ubicacion: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', pageBuilder: (c, s) => _p(const InicioScreen())),
        GoRoute(path: '/torneos', pageBuilder: (c, s) => _p(const TorneosScreen())),
        GoRoute(
          path: '/torneos/:id',
          pageBuilder: (c, s) => _p(TorneoPagina(id: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/torneos/:id/:apartado',
          pageBuilder: (c, s) => _p(TorneoPagina(id: s.pathParameters['id']!, apartado: s.pathParameters['apartado']!)),
        ),
        GoRoute(path: '/galeria', pageBuilder: (c, s) => _p(const GaleriaScreen())),
        // Direcciones de antes y de las notificaciones: al apartado del torneo que toque
        GoRoute(path: '/torneo', pageBuilder: (c, s) => _p(const RedirigirTorneo(''))),
        GoRoute(path: '/calendario', pageBuilder: (c, s) => _p(const RedirigirTorneo('calendario'))),
        GoRoute(path: '/equipos', pageBuilder: (c, s) => _p(const RedirigirTorneo('equipos'))),
        GoRoute(path: '/estadisticas', pageBuilder: (c, s) => _p(const RedirigirTorneo('estadisticas'))),
        GoRoute(path: '/porra', pageBuilder: (c, s) => _p(const RedirigirTorneo('porra'))),
        GoRoute(path: '/avisos', pageBuilder: (c, s) => _p(const RedirigirTorneo('avisos'))),
        GoRoute(path: '/mas', pageBuilder: (c, s) => _p(const MasScreen())),
      ],
    ),
    GoRoute(path: '/recuperar', pageBuilder: (c, s) => _p(const RecuperarScreen())),
    GoRoute(path: '/gestion', pageBuilder: (c, s) => _p(const PanelScreen())),
  ],
  errorPageBuilder: (c, s) => _p(const InicioScreen()),
);
