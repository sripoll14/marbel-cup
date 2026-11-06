import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/env.dart';
import 'datos.dart';
import 'favoritos.dart';
import 'push_js_stub.dart' if (dart.library.js_interop) 'push_js_web.dart' as js;

enum EstadoPush {
  /// Falta la clave VAPID (no se enseña nada)
  sinConfigurar,

  /// El navegador no las permite
  noSoportado,

  /// iPhone: primero hay que instalar la app en la pantalla de inicio
  instalarPrimero,

  /// La persona las bloqueó en el navegador
  bloqueado,
  desactivado,
  activado,
}

/// Notificaciones push con la app cerrada. No hace falta cuenta: el servidor
/// solo guarda la dirección de push de este móvil, los equipos que sigue y
/// qué quiere recibir.
class Notificaciones extends ChangeNotifier {
  EstadoPush estado = EstadoPush.desactivado;
  bool trabajando = false;
  Timer? _espera;

  Future<void> iniciar() async {
    if (Env.vapidPublica.isEmpty) {
      estado = EstadoPush.sinConfigurar;
    } else if (!js.soportado()) {
      estado = js.necesitaInstalar() ? EstadoPush.instalarPrimero : EstadoPush.noSoportado;
    } else if (js.necesitaInstalar()) {
      estado = EstadoPush.instalarPrimero;
    } else if (js.permiso() == 'denied') {
      estado = EstadoPush.bloqueado;
    } else {
      try {
        final s = await js.actual();
        if (s.isNotEmpty) {
          estado = EstadoPush.activado;
          await _guardar(s); // por si cambiaron los favoritos en otro momento
        }
      } catch (e) {
        debugPrint('push: $e');
      }
    }
    favoritos.addListener(_alCambiarFavoritos);
    notifyListeners();
  }

  /// Llamar directamente al tocar el botón (el permiso se pide en ese momento).
  /// Devuelve un mensaje de error, o null si todo ha ido bien.
  Future<String?> activar() async {
    final pedido = js.activar(Env.vapidPublica); // primero, dentro del toque
    trabajando = true;
    notifyListeners();
    try {
      final s = await pedido;
      if (s.isEmpty) {
        estado = js.permiso() == 'denied' ? EstadoPush.bloqueado : EstadoPush.desactivado;
        return 'Sin permiso no podemos enviarte notificaciones.';
      }
      await _guardar(s);
      estado = EstadoPush.activado;
      return null;
    } catch (e) {
      return 'No se han podido activar: $e';
    } finally {
      trabajando = false;
      notifyListeners();
    }
  }

  Future<String?> desactivar() async {
    trabajando = true;
    notifyListeners();
    try {
      final endpoint = await js.desactivar();
      if (endpoint.isNotEmpty) await db.rpc('borrar_suscripcion', params: {'p_endpoint': endpoint});
      estado = EstadoPush.desactivado;
      return null;
    } catch (e) {
      return 'No se han podido desactivar: $e';
    } finally {
      trabajando = false;
      notifyListeners();
    }
  }

  Future<void> _guardar(String json) async {
    final s = jsonDecode(json) as Map<String, dynamic>;
    final claves = (s['keys'] as Map?) ?? const {};
    await db.rpc('guardar_suscripcion', params: {
      'p_endpoint': s['endpoint'],
      'p_p256dh': claves['p256dh'],
      'p_auth': claves['auth'],
      'p_equipos': favoritos.equipos.toList(),
      'p_prefs': favoritos.preferencias,
    });
  }

  /// Si sigue o deja de seguir un equipo, o cambia qué quiere recibir,
  /// se actualiza en el servidor (con un pequeño margen para agrupar cambios).
  void _alCambiarFavoritos() {
    if (estado != EstadoPush.activado) return;
    _espera?.cancel();
    _espera = Timer(const Duration(seconds: 2), () async {
      try {
        final s = await js.actual();
        if (s.isNotEmpty) await _guardar(s);
      } catch (e) {
        debugPrint('push: $e');
      }
    });
  }
}

final notificaciones = Notificaciones();
