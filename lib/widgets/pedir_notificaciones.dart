import 'package:flutter/material.dart';

import '../data/notificaciones.dart';
import '../data/push_js_stub.dart' if (dart.library.js_interop) '../data/push_js_web.dart' as js;
import '../theme/app_theme.dart';
import 'comunes.dart';

bool _yaPreguntado = false; // una vez por visita

/// Al seguir un equipo, si las notificaciones no están activadas, ofrece activarlas
/// (o, en un iPhone sin la app instalada, explica que primero hay que instalarla).
Future<void> ofrecerNotificaciones(BuildContext context, String equipo) async {
  final n = notificaciones;
  if (_yaPreguntado) return;
  if (n.estado != EstadoPush.desactivado && n.estado != EstadoPush.instalarPrimero) return;
  _yaPreguntado = true;
  final instalar = n.estado == EstadoPush.instalarPrimero;

  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: MarbelColors.tarjeta,
      icon: Icon(instalar ? Icons.install_mobile_rounded : Icons.notifications_active_rounded, color: MarbelColors.cian, size: 40),
      title: Text(instalar ? 'Instala la app para recibir avisos' : '¿Te avisamos de sus partidos?', textAlign: TextAlign.center),
      content: Text(
        instalar
            ? 'En el iPhone las notificaciones solo llegan con Marbel Cup instalada en la pantalla de inicio. '
                'Instálala y te avisaremos de los partidos, goles y resultados de $equipo aunque tengas la app cerrada.'
            : 'Activa las notificaciones y te llegarán los goles, resultados y cambios de campo de $equipo '
                'aunque tengas la app cerrada.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: MarbelColors.texto2, height: 1.4),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Ahora no')),
        FilledButton(
          onPressed: () async {
            if (instalar) {
              Navigator.pop(c);
              js.mostrarInstalar(); // abre los pasos de instalación
              return;
            }
            final pedido = n.activar(); // el permiso se pide en este mismo toque
            Navigator.pop(c);
            final error = await pedido;
            if (context.mounted) avisar(context, error ?? '¡Listo! Te avisaremos.', error: error != null);
          },
          child: Text(instalar ? 'CÓMO INSTALARLA' : 'ACTIVAR'),
        ),
      ],
    ),
  );
}
