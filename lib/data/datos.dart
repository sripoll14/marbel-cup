import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'modelos.dart';

SupabaseClient get db => Supabase.instance.client;

/// Todos los datos públicos del torneo, cargados una vez y actualizados en
/// tiempo real (partidos, goles, avisos y fotos). Las pantallas lo escuchan
/// con `ListenableBuilder(listenable: datos, ...)`.
class Datos extends ChangeNotifier {
  bool cargando = true;
  String? error;

  Torneo? torneo;
  List<Torneo> torneos = [];
  List<Sede> sedes = [];
  List<Categoria> categorias = [];
  List<Equipo> equipos = [];
  List<Liga> ligas = [];
  Map<String, List<String>> equiposDeLiga = {}; // liga -> equipos
  List<Partido> partidos = [];
  List<Gol> goles = [];
  List<Aviso> avisos = [];
  List<Foto> fotos = [];

  final _subs = <StreamSubscription>[];
  Timer? _reloj;

  Future<void> iniciar() async {
    if (!Env.configurado) {
      cargando = false;
      error = 'Falta conectar Supabase (env.json).';
      notifyListeners();
      return;
    }
    try {
      await recargar();
      _escuchar();
      // Cada 30 s se repinta: minutos de juego, retrasos y cuenta atrás.
      _reloj = Timer.periodic(const Duration(seconds: 30), (_) => notifyListeners());
    } catch (e) {
      error = 'No se han podido cargar los datos: $e';
    }
    cargando = false;
    notifyListeners();
  }

  Future<void> recargar() async {
    final r = await Future.wait<List<Map<String, dynamic>>>([
      db.from('torneos').select().order('inicio', ascending: false),
      db.from('sedes').select().order('orden', ascending: true),
      db.from('categorias').select().order('orden', ascending: true),
      db.from('equipos').select().order('nombre', ascending: true),
      db.from('ligas').select(),
      db.from('liga_equipos').select(),
      db.from('partidos').select().order('hora', ascending: true),
      db.from('goles').select(),
      db.from('avisos').select().order('creado', ascending: false).limit(100),
      db.from('fotos').select().order('orden', ascending: true),
    ]);
    torneos = r[0].map(Torneo.fromMap).toList();
    torneo = torneos.where((t) => t.activo).firstOrNull ??
        (torneos.isEmpty ? null : torneos.first);
    sedes = r[1].map(Sede.fromMap).toList();
    categorias = r[2].map(Categoria.fromMap).toList();
    equipos = r[3].map(Equipo.fromMap).toList();
    ligas = r[4].map(Liga.fromMap).toList();
    equiposDeLiga = {};
    for (final m in r[5]) {
      equiposDeLiga
          .putIfAbsent(m['liga_id'] as String, () => [])
          .add(m['equipo_id'] as String);
    }
    partidos = r[6].map(Partido.fromMap).toList();
    goles = r[7].map(Gol.fromMap).toList();
    avisos = r[8].map(Aviso.fromMap).toList();
    fotos = r[9].map(Foto.fromMap).toList();
    notifyListeners();
  }

  void _escuchar() {
    _subs.add(db.from('partidos').stream(primaryKey: ['id']).listen((filas) {
      partidos = filas.map(Partido.fromMap).toList()
        ..sort((a, b) => a.hora.compareTo(b.hora));
      notifyListeners();
    }));
    _subs.add(db.from('goles').stream(primaryKey: ['id']).listen((filas) {
      goles = filas.map(Gol.fromMap).toList();
      notifyListeners();
    }));
    _subs.add(db.from('avisos').stream(primaryKey: ['id']).listen((filas) {
      avisos = filas.map(Aviso.fromMap).toList()
        ..sort((a, b) {
          if (a.fijado != b.fijado) return a.fijado ? -1 : 1;
          return b.creado.compareTo(a.creado);
        });
      notifyListeners();
    }));
    _subs.add(db.from('fotos').stream(primaryKey: ['id']).listen((filas) {
      fotos = filas.map(Foto.fromMap).toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));
      notifyListeners();
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _reloj?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Búsquedas
  // -------------------------------------------------------------------------
  Equipo? equipo(String? id) =>
      id == null ? null : equipos.where((e) => e.id == id).firstOrNull;
  String nombreEquipo(String? id, {String siNo = 'Por decidir'}) =>
      equipo(id)?.nombre ?? siNo;
  Sede? sede(String? id) =>
      id == null ? null : sedes.where((s) => s.id == id).firstOrNull;
  Liga? liga(String id) => ligas.where((l) => l.id == id).firstOrNull;
  Categoria? categoria(String? id) =>
      id == null ? null : categorias.where((c) => c.id == id).firstOrNull;

  /// Ligas del torneo actual, ordenadas por categoría y nivel.
  List<Liga> get ligasActuales {
    final t = torneo;
    final l = ligas.where((x) => t == null || x.torneoId == t.id).toList();
    l.sort((a, b) {
      final ca = categoria(a.categoriaId)?.orden ?? 0;
      final cb = categoria(b.categoriaId)?.orden ?? 0;
      if (ca != cb) return ca.compareTo(cb);
      return Nivel.todos.indexWhere((n) => n.id == a.nivelId)
          .compareTo(Nivel.todos.indexWhere((n) => n.id == b.nivelId));
    });
    return l;
  }

  Liga? ligaDe(String categoriaId, String nivelId) => ligasActuales
      .where((l) => l.categoriaId == categoriaId && l.nivelId == nivelId)
      .firstOrNull;

  /// "Benjamín 1º · Medio"
  String nombreLiga(String ligaId, {bool corto = true}) {
    final l = liga(ligaId);
    if (l == null) return '';
    final c = categoria(l.categoriaId);
    final n = Nivel.de(l.nivelId);
    final cat = corto ? (c?.corto ?? '') : (c?.nombre ?? '');
    return n.id == 'femenino' ? cat : '$cat · ${n.nombre}';
  }

  Nivel nivelDeLiga(String ligaId) => Nivel.de(liga(ligaId)?.nivelId);

  /// Ligas en las que juega un equipo.
  List<Liga> ligasDeEquipo(String equipoId) => ligasActuales
      .where((l) => (equiposDeLiga[l.id] ?? const []).contains(equipoId))
      .toList();

  List<Partido> partidosDeLiga(String ligaId) =>
      partidos.where((p) => p.ligaId == ligaId).toList();

  List<Partido> get enDirecto =>
      partidos.where((p) => p.estado == Estado.enJuego).toList();

  List<Partido> partidosDeEquipo(String equipoId) => partidos
      .where((p) => p.localId == equipoId || p.visitanteId == equipoId)
      .toList();

  /// Días con partidos (o los días del torneo si aún no hay calendario).
  List<DateTime> get diasTorneo {
    final d = partidos.map((p) => soloDia(p.hora)).toSet().toList()..sort();
    if (d.isNotEmpty) return d;
    return [
      DateTime(2026, 12, 26), DateTime(2026, 12, 27),
      DateTime(2027, 1, 2), DateTime(2027, 1, 3),
    ];
  }

  // -------------------------------------------------------------------------
  // Clasificación (mismas reglas que la vista SQL)
  // -------------------------------------------------------------------------
  List<FilaClasificacion> clasificacion(String ligaId) {
    final filas = {
      for (final e in equiposDeLiga[ligaId] ?? const <String>[])
        e: FilaClasificacion(e),
    };
    for (final p in partidos) {
      if (p.ligaId != ligaId || p.fase != Fase.liga) continue;
      if (p.estado != Estado.finalizado || !p.tieneMarcador) continue;
      final l = filas[p.localId], v = filas[p.visitanteId];
      if (l == null || v == null) continue;
      final gl = p.golesLocal!, gv = p.golesVisitante!;
      l.pj++; v.pj++;
      l.gf += gl; l.gc += gv; v.gf += gv; v.gc += gl;
      if (gl > gv) { l.g++; v.p++; }
      else if (gl < gv) { v.g++; l.p++; }
      else { l.e++; v.e++; }
    }
    final lista = filas.values.toList()
      ..sort((a, b) {
        if (a.pts != b.pts) return b.pts.compareTo(a.pts);
        if (a.dg != b.dg) return b.dg.compareTo(a.dg);
        if (a.gf != b.gf) return b.gf.compareTo(a.gf);
        return a.equipoId.compareTo(b.equipoId);
      });
    for (var i = 0; i < lista.length; i++) {
      lista[i].pos = i + 1;
    }
    return lista;
  }

  int jornadaActual(String ligaId) {
    final js = partidosDeLiga(ligaId)
        .where((p) => p.fase == Fase.liga && p.estado == Estado.finalizado)
        .map((p) => p.jornada ?? 0);
    return js.isEmpty ? 0 : js.reduce((a, b) => a > b ? a : b);
  }

  int jornadasTotales(String ligaId) {
    final js = partidosDeLiga(ligaId)
        .where((p) => p.fase == Fase.liga)
        .map((p) => p.jornada ?? 0);
    return js.isEmpty ? 5 : js.reduce((a, b) => a > b ? a : b);
  }

  /// La Porra de una liga se cierra 30 min antes de su primer partido.
  DateTime? cierrePorra(String ligaId) {
    final ps = partidosDeLiga(ligaId);
    if (ps.isEmpty) return null;
    final primero = ps.map((p) => p.hora).reduce((a, b) => a.isBefore(b) ? a : b);
    return primero.subtract(const Duration(minutes: 30));
  }

  bool porraAbierta(String ligaId) {
    final c = cierrePorra(ligaId);
    return c == null || DateTime.now().isBefore(c);
  }

  // -------------------------------------------------------------------------
  // Estadísticas
  // -------------------------------------------------------------------------
  List<Partido> finalizados({String? grupoCategoria}) => partidos.where((p) {
        if (p.estado != Estado.finalizado || !p.tieneMarcador) return false;
        if (grupoCategoria == null) return true;
        final l = liga(p.ligaId);
        return categoria(l?.categoriaId)?.grupo == grupoCategoria;
      }).toList();

  /// Racha actual de victorias seguidas de un equipo y sus últimos resultados.
  ({int racha, List<String> ultimos}) rachaDe(String equipoId) {
    final ps = partidosDeEquipo(equipoId)
        .where((p) => p.estado == Estado.finalizado && p.tieneMarcador)
        .toList()
      ..sort((a, b) => a.hora.compareTo(b.hora));
    final res = ps.map((p) {
      final g = p.ganadorId;
      if (g == null) return 'E';
      return g == equipoId ? 'V' : 'D';
    }).toList();
    var racha = 0;
    for (final r in res.reversed) {
      if (r == 'V') {
        racha++;
      } else {
        break;
      }
    }
    final ult = res.length > 5 ? res.sublist(res.length - 5) : res;
    return (racha: racha, ultimos: ult);
  }
}

final datos = Datos();
