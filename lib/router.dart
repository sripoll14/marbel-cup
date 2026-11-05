import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/sesion.dart';
import 'screens/avisos_screen.dart';
import 'screens/calendario_screen.dart';
import 'screens/equipos_screen.dart';
import 'screens/estadisticas_screen.dart';
import 'screens/galeria_screen.dart';
import 'screens/gestion/panel_screen.dart';
import 'screens/inicio_screen.dart';
import 'screens/mas_screen.dart';
import 'screens/porra_screen.dart';
import 'screens/recuperar_screen.dart';
import 'screens/torneo_screen.dart';
import 'widgets/marco_app.dart';

Page<void> _p(Widget w) => NoTransitionPage(child: w);

/// Rutas. En la web se ven como .../#/calendario, .../#/equipos...
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
        GoRoute(path: '/calendario', pageBuilder: (c, s) => _p(const CalendarioScreen())),
        GoRoute(path: '/equipos', pageBuilder: (c, s) => _p(const EquiposScreen())),
        GoRoute(path: '/estadisticas', pageBuilder: (c, s) => _p(const EstadisticasScreen())),
        GoRoute(path: '/porra', pageBuilder: (c, s) => _p(const PorraScreen())),
        GoRoute(path: '/galeria', pageBuilder: (c, s) => _p(const GaleriaScreen())),
        GoRoute(path: '/torneo', pageBuilder: (c, s) => _p(const TorneoScreen())),
        GoRoute(path: '/avisos', pageBuilder: (c, s) => _p(const AvisosScreen())),
        GoRoute(path: '/mas', pageBuilder: (c, s) => _p(const MasScreen())),
      ],
    ),
    GoRoute(path: '/recuperar', pageBuilder: (c, s) => _p(const RecuperarScreen())),
    GoRoute(path: '/gestion', pageBuilder: (c, s) => _p(const PanelScreen())),
  ],
  errorPageBuilder: (c, s) => _p(const InicioScreen()),
);
