import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'datos.dart';

/// Identificador único para un gol creado en el móvil (así, si se reenvía,
/// no se duplica).
String nuevoId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Cambios de la mesa (marcador, goles, estado, campo, retraso...).
///
/// Se ven al momento en el móvil y se envían en cuanto se puede. Si no hay
/// cobertura se quedan guardados en el móvil, en orden, y se envían solos
/// cuando vuelve la conexión (se reintenta cada 15 segundos).
class ColaCambios extends ChangeNotifier {
  static const _clave = 'cola_cambios_v1';
  final List<Map<String, dynamic>> _cola = [];
  bool enviando = false;

  /// Último cambio que el servidor rechazó (p. ej. por falta de permiso).
  String? rechazado;
  Timer? _timer;

  int get pendientes => _cola.length;

  Future<void> iniciar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final txt = prefs.getString(_clave);
      if (txt != null) {
        for (final c in jsonDecode(txt) as List) {
          _cola.add(Map<String, dynamic>.from(c as Map));
        }
      }
    } catch (e) {
      debugPrint('cola: $e');
    }
    datos.superponer = _superponer;
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => enviar());
    if (_cola.isNotEmpty) {
      datos.repintar();
      enviar();
    }
  }

  /// Cambia campos de un partido (valores finales, no sumas: reenviarlo no duplica nada).
  Future<void> partido(String id, Map<String, dynamic> cambios) async {
    // Varios cambios seguidos del mismo partido sin enviar se juntan en uno
    final previo = _cola.where((c) => c['tipo'] == 'partido' && c['id'] == id).lastOrNull;
    if (previo != null && !enviando) {
      (previo['datos'] as Map<String, dynamic>).addAll(cambios);
      await _guardado();
    } else {
      _cola.add({'tipo': 'partido', 'id': id, 'datos': Map<String, dynamic>.from(cambios)});
      await _guardado();
    }
    await enviar();
  }

  /// Gol con nombre. [fila] lleva su propio `id` (de [nuevoId]).
  Future<void> nuevoGol(Map<String, dynamic> fila) async {
    _cola.add({'tipo': 'gol', 'id': fila['id'], 'datos': fila});
    await _guardado();
    await enviar();
  }

  Future<void> borrarGol(String id) async {
    // Si ese gol aún no se había enviado, basta con quitarlo de la cola
    final i = _cola.indexWhere((c) => c['tipo'] == 'gol' && c['id'] == id);
    if (i >= 0 && !(enviando && i == 0)) {
      _cola.removeAt(i);
      await _guardado();
      return;
    }
    _cola.add({'tipo': 'borrar_gol', 'id': id});
    await _guardado();
    await enviar();
  }

  /// Envía lo pendiente, en orden. Sin conexión, para y lo deja para luego.
  Future<void> enviar() async {
    if (enviando || _cola.isEmpty) return;
    enviando = true;
    notifyListeners();
    var enviado = false;
    try {
      while (_cola.isNotEmpty) {
        final c = _cola.first;
        try {
          switch (c['tipo']) {
            case 'partido':
              await db.from('partidos').update(Map<String, dynamic>.from(c['datos'] as Map)).eq('id', c['id'] as String);
            case 'gol':
              await db.from('goles').upsert(Map<String, dynamic>.from(c['datos'] as Map), ignoreDuplicates: true);
            case 'borrar_gol':
              await db.from('goles').delete().eq('id', c['id'] as String);
          }
        } on PostgrestException catch (e) {
          // El servidor lo ha recibido y lo rechaza: reintentarlo no serviría
          rechazado = e.message;
          debugPrint('cola rechazado: ${e.message}');
        }
        _cola.removeAt(0);
        enviado = true;
        await _guardar();
      }
    } catch (e) {
      // Sin conexión (u otro fallo de red): se queda en la cola
      debugPrint('cola sin conexión: $e');
    } finally {
      enviando = false;
      notifyListeners();
    }
    if (enviado) {
      try {
        await datos.refrescarPartidos(); // lo que hay de verdad en el servidor
      } catch (_) {
        datos.repintar();
      }
    }
  }

  Future<void> _guardado() async {
    await _guardar();
    datos.repintar();
    notifyListeners();
  }

  Future<void> _guardar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, jsonEncode(_cola));
    } catch (e) {
      debugPrint('cola: $e');
    }
  }

  /// Lo que aún no se ha enviado se pinta encima de lo que dice el servidor.
  Filas _superponer(String tabla, Filas filas) {
    if (_cola.isEmpty) return filas;
    if (tabla == 'partidos') {
      final cambios = <String, Map<String, dynamic>>{};
      for (final c in _cola) {
        if (c['tipo'] != 'partido') continue;
        cambios.putIfAbsent(c['id'] as String, () => {}).addAll(Map<String, dynamic>.from(c['datos'] as Map));
      }
      if (cambios.isEmpty) return filas;
      return [for (final f in filas) cambios.containsKey(f['id']) ? {...f, ...cambios[f['id']]!} : f];
    }
    if (tabla == 'goles') {
      final borrar = {for (final c in _cola) if (c['tipo'] == 'borrar_gol') c['id']};
      final nuevos = [for (final c in _cola) if (c['tipo'] == 'gol') Map<String, dynamic>.from(c['datos'] as Map)];
      final ids = {for (final f in filas) f['id']};
      return [
        for (final f in filas) if (!borrar.contains(f['id'])) f,
        for (final n in nuevos) if (!ids.contains(n['id']) && !borrar.contains(n['id'])) n,
      ];
    }
    return filas;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final cola = ColaCambios();
