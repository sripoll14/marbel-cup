import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Equipos favoritos y qué avisos quiere recibir la persona.
/// Se guarda solo en su dispositivo (no hace falta cuenta).
class Favoritos extends ChangeNotifier {
  Set<String> equipos = {};

  static const preferenciasTexto = [
    'Mis equipos: hora y campo',
    'Resultados de mis equipos',
    'Rachas y récords de mis equipos',
    'Avisos generales de la organización',
    'Recordatorio de cierre de La Porra',
  ];
  List<bool> preferencias = [true, true, true, true, false];

  /// Avisos ya vistos (para el contador de la campana).
  DateTime vistoHasta = DateTime.fromMillisecondsSinceEpoch(0);

  SharedPreferences? _p;

  Future<void> iniciar() async {
    _p = await SharedPreferences.getInstance();
    equipos = (_p!.getStringList('favoritos') ?? const []).toSet();
    final pr = _p!.getStringList('preferencias_avisos');
    if (pr != null && pr.length == preferencias.length) {
      preferencias = pr.map((x) => x == '1').toList();
    }
    final v = _p!.getInt('avisos_vistos');
    if (v != null) vistoHasta = DateTime.fromMillisecondsSinceEpoch(v);
    notifyListeners();
  }

  bool es(String equipoId) => equipos.contains(equipoId);

  void alternar(String equipoId) {
    if (!equipos.remove(equipoId)) equipos.add(equipoId);
    _p?.setStringList('favoritos', equipos.toList());
    notifyListeners();
  }

  void cambiarPreferencia(int i, bool v) {
    preferencias[i] = v;
    _p?.setStringList('preferencias_avisos', preferencias.map((b) => b ? '1' : '0').toList());
    notifyListeners();
  }

  void marcarVistos() {
    vistoHasta = DateTime.now();
    _p?.setInt('avisos_vistos', vistoHasta.millisecondsSinceEpoch);
    notifyListeners();
  }
}

final favoritos = Favoritos();
