import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'modelos.dart';
import 'proyecto.dart';
import 'sesion.dart';

SupabaseClient get db => Supabase.instance.client;

typedef Filas = List<Map<String, dynamic>>;

/// Todos los datos públicos del torneo, cargados una vez y actualizados en
/// tiempo real (partidos, goles, avisos y fotos). Las pantallas lo escuchan
/// con `ListenableBuilder(listenable: datos, ...)`.
///
/// Sin conexión: se guarda una copia en el móvil cada vez que llegan datos, y
/// si no se puede conectar se enseña esa copia (con [sinConexion] a true).
class Datos extends ChangeNotifier {
  bool cargando = true;
  String? error;

  /// No hay conexión: lo que se ve es la última copia guardada.
  bool sinConexion = false;

  /// Cuándo llegaron los datos que se están enseñando.
  DateTime? actualizado;

  Torneo? torneo;
  List<Torneo> torneos = [];
  List<Sede> sedes = [];
  List<Categoria> categorias = [];
  List<Equipo> equipos = [];
  List<Liga> ligas = [];
  Map<String, List<String>> equiposDeLiga = {}; // liga -> equipos

  /// Orden a mano de la clasificación ("liga|equipo" -> posición), para empates.
  Map<String, int> ordenManual = {};
  /// Partidos, goles y avisos del torneo elegido.
  List<Partido> partidos = [];
  List<Gol> goles = [];
  List<Aviso> avisos = [];

  /// Todos los partidos y goles (de todos los torneos). Para la mesa de sede.
  List<Partido> todosPartidos = [];
  List<Gol> todosGoles = [];

  /// Torneo que ha elegido la persona en «Torneos actuales» (se guarda en el móvil).
  String? _elegido;
  static const _claveElegido = 'torneo_elegido';
  List<Foto> fotos = [];

  /// Filas tal cual llegan del servidor, por tabla (lo que se guarda en la copia).
  final _filas = <String, Filas>{};

  /// Cambios del panel que aún no han llegado al servidor: se pintan encima
  /// (lo pone la cola de cambios pendientes).
  Filas Function(String tabla, Filas filas)? superponer;

  final _subs = <StreamSubscription>[];
  Timer? _reloj;
  Timer? _reconexion;
  Timer? _reintento;
  Timer? _guardado;
  AppLifecycleListener? _ciclo;
  int _fallos = 0; // fallos seguidos del tiempo real

  static const _tablas = [
    'torneos', 'sedes', 'categorias', 'equipos', 'ligas',
    'liga_equipos', 'partidos', 'goles', 'avisos', 'fotos',
  ];
  static const _claveCopia = 'copia_datos_v1';

  Future<void> iniciar() async {
    if (!Env.configurado) {
      cargando = false;
      error = 'Falta conectar Supabase (env.json).';
      notifyListeners();
      return;
    }
    // 1. Lo último guardado en el móvil, al instante (y sirve sin conexión)
    try {
      _elegido = (await SharedPreferences.getInstance()).getString(_claveElegido);
    } catch (_) {}
    final habiaCopia = await _leerCopia();
    if (habiaCopia) {
      cargando = false;
      _construir();
    }
    // 2. Datos frescos del servidor (con cobertura mala, no se espera más de 10 s)
    try {
      await recargar().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('cargar: $e');
      if (!habiaCopia) error = 'No se han podido cargar los datos. Revisa la conexión a internet.';
      _marcarSinConexion();
    }
    _escuchar();
    // Al volver a la app (el móvil corta la conexión en segundo plano): datos frescos y reconectar
    _ciclo = AppLifecycleListener(onResume: () {
      recargar().then((_) => _reconectar(), onError: (Object e) => _marcarSinConexion());
    });
    // Cada 30 s se repinta: minutos de juego, retrasos y cuenta atrás.
    _reloj = Timer.periodic(const Duration(seconds: 30), (_) => notifyListeners());
    cargando = false;
    notifyListeners();
  }

  Future<void> recargar() async {
    final r = await Future.wait<Filas>([
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
    for (var i = 0; i < _tablas.length; i++) {
      _filas[_tablas[i]] = r[i];
    }
    _recibido();
  }

  /// Recarga solo partidos y goles (tras un cambio en el panel, para verlo al instante).
  Future<void> refrescarPartidos() async {
    final r = await Future.wait<Filas>([
      db.from('partidos').select().order('hora', ascending: true),
      db.from('goles').select(),
    ]);
    _filas['partidos'] = r[0];
    _filas['goles'] = r[1];
    _recibido();
  }

  /// Vuelve a pintar con lo que hay (p. ej. al cambiar los cambios pendientes).
  void repintar() => _construir();

  /// Han llegado datos del servidor: hay conexión.
  void _recibido() {
    actualizado = DateTime.now();
    error = null;
    sinConexion = false;
    _reintento?.cancel();
    _reintento = null;
    _guardarCopia();
    _construir();
  }

  void _marcarSinConexion() {
    if (!sinConexion) {
      sinConexion = true;
      notifyListeners();
    }
    if (_reintento != null) return;
    // Cada 20 s se vuelve a intentar
    _reintento = Timer.periodic(const Duration(seconds: 20), (_) async {
      try {
        await recargar();
        _reconectar();
      } catch (_) {}
    });
  }

  Filas _de(String tabla) {
    final f = _filas[tabla] ?? const <Map<String, dynamic>>[];
    final s = superponer;
    return s == null ? f : s(tabla, f);
  }

  void _construir({bool avisar = true}) {
    torneos = _de('torneos').map(Torneo.fromMap).toList();
    sedes = _de('sedes').map(Sede.fromMap).toList();
    categorias = _de('categorias').map(Categoria.fromMap).toList();
    equipos = _de('equipos').map(Equipo.fromMap).toList();
    ligas = _de('ligas').map(Liga.fromMap).toList();
    equiposDeLiga = {};
    ordenManual = {};
    for (final m in _de('liga_equipos')) {
      equiposDeLiga.putIfAbsent(m['liga_id'] as String, () => []).add(m['equipo_id'] as String);
      final o = m['orden_manual'];
      if (o != null) ordenManual['${m['liga_id']}|${m['equipo_id']}'] = (o as num).toInt();
    }
    todosPartidos = _de('partidos').map(Partido.fromMap).toList()..sort((a, b) => a.hora.compareTo(b.hora));
    todosGoles = _de('goles').map(Gol.fromMap).toList();
    torneo = _torneoAEnsenar();
    // Lo que se ve es solo del torneo elegido
    final ligasT = {for (final l in ligas) if (l.torneoId == torneo?.id) l.id};
    partidos = todosPartidos.where((p) => ligasT.contains(p.ligaId)).toList();
    final idsP = {for (final p in partidos) p.id};
    goles = todosGoles.where((g) => idsP.contains(g.partidoId)).toList();
    avisos = _de('avisos')
        .where((m) => m['torneo_id'] == null || m['torneo_id'] == torneo?.id)
        .map(Aviso.fromMap)
        .toList()
      ..sort((a, b) {
        if (a.fijado != b.fijado) return a.fijado ? -1 : 1;
        return b.creado.compareTo(a.creado);
      });
    fotos = _de('fotos').map(Foto.fromMap).toList()..sort((a, b) => a.orden.compareTo(b.orden));
    if (avisar) notifyListeners();
  }

  // ---------- Copia en el móvil ----------
  Future<bool> _leerCopia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final txt = prefs.getString(_claveCopia);
      if (txt == null) return false;
      final m = jsonDecode(txt) as Map<String, dynamic>;
      final filas = m['filas'] as Map<String, dynamic>;
      for (final t in _tablas) {
        _filas[t] = [for (final f in (filas[t] as List? ?? const [])) Map<String, dynamic>.from(f as Map)];
      }
      actualizado = DateTime.tryParse(m['cuando'] as String? ?? '')?.toLocal();
      return true;
    } catch (e) {
      debugPrint('copia: $e');
      return false;
    }
  }

  /// Se guarda unos segundos después (si llegan varios cambios seguidos, una vez).
  void _guardarCopia() {
    _guardado?.cancel();
    _guardado = Timer(const Duration(seconds: 3), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_claveCopia, jsonEncode({
          'cuando': (actualizado ?? DateTime.now()).toUtc().toIso8601String(),
          'filas': _filas,
        }));
      } catch (e) {
        debugPrint('copia: $e');
      }
    });
  }

  // ---------- Tiempo real ----------
  void _reconectar() {
    _reconexion?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _escuchar();
  }

  /// Si se corta la conexión en directo, vuelve a intentarlo: a los 5 s, luego
  /// 10, 20, 40… (como mucho, cada minuto y pico) mientras siga fallando.
  void _alFallar(Object e) {
    debugPrint('tiempo real: $e');
    _reconexion?.cancel();
    final n = _fallos < 4 ? _fallos : 4;
    final espera = 5 * (1 << n); // 5, 10, 20, 40, 80 s

    _fallos++;
    _reconexion = Timer(Duration(seconds: espera), () {
      recargar().then((_) => _reconectar(), onError: (Object e) => _marcarSinConexion());
    });
  }

  void _escuchar() {
    for (final tabla in const ['partidos', 'goles', 'avisos', 'fotos']) {
      _subs.add(db.from(tabla).stream(primaryKey: ['id']).listen((filas) {
        _fallos = 0;
        _filas[tabla] = filas;
        _recibido();
      }, onError: _alFallar));
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _reloj?.cancel();
    _reconexion?.cancel();
    _reintento?.cancel();
    _guardado?.cancel();
    _ciclo?.dispose();
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

  // -------------------------------------------------------------------------
  // Varios torneos
  // -------------------------------------------------------------------------

  /// Torneos en curso y publicados («Torneos actuales»), por fecha.
  List<Torneo> get torneosVisibles => torneos.where((t) => t.visible).toList()
    ..sort((a, b) => a.inicio.compareTo(b.inicio));

  /// Último día con partidos de un torneo (o su primer día si aún no hay calendario).
  DateTime finDe(Torneo t) {
    final ligasT = {for (final l in ligas) if (l.torneoId == t.id) l.id};
    var fin = soloDia(t.inicio);
    final js = t.proyecto?.jornadas ?? const <DateTime>[];
    if (js.isNotEmpty && js.last.isAfter(fin)) fin = js.last;
    for (final p in todosPartidos) {
      if (ligasT.contains(p.ligaId) && soloDia(p.hora).isAfter(fin)) fin = soloDia(p.hora);
    }
    return fin;
  }

  Torneo? _torneoAEnsenar() {
    // 1. El que haya elegido (los ocultos, solo el personal, para prepararlos)
    final elegido = torneos.where((t) => t.id == _elegido).firstOrNull;
    if (elegido != null && (elegido.visible || sesion.esPersonal)) return elegido;
    // 2. El próximo (o el que se está jugando) de los torneos actuales
    final visibles = torneosVisibles;
    final hoy = soloDia(DateTime.now());
    final proximo = visibles.where((t) => !finDe(t).isBefore(hoy)).firstOrNull;
    if (proximo != null) return proximo;
    if (visibles.isNotEmpty) return visibles.last;
    // 3. Si no hay ninguno publicado: el público no ve ninguno; el personal,
    //    el que esté en curso o el más reciente (para prepararlo)
    if (!sesion.esPersonal) return null;
    return torneos.where((t) => t.activo).firstOrNull ?? torneos.firstOrNull;
  }

  /// La página de un torneo (/torneos/<id>) fija ese torneo para toda la web,
  /// sin repintar (se llama mientras se pinta esa página).
  void fijarTorneo(String id) {
    if (torneo?.id == id && _elegido == id) return;
    _elegido = id;
    _construir(avisar: false);
    SharedPreferences.getInstance().then((p) => p.setString(_claveElegido, id)).catchError((_) => false);
  }

  /// Días de juego de un torneo (su proyecto, sus partidos o su primer día).
  List<DateTime> jornadasDe(Torneo t) {
    final js = t.proyecto?.jornadas ?? const <DateTime>[];
    if (js.isNotEmpty) return js;
    final ligasT = {for (final l in ligas) if (l.torneoId == t.id) l.id};
    final d = todosPartidos.where((p) => ligasT.contains(p.ligaId)).map((p) => soloDia(p.hora)).toSet().toList()..sort();
    return d.isNotEmpty ? d : [soloDia(t.inicio)];
  }

  /// Partidos de varios torneos (p. ej. los visibles, para la portada).
  List<Partido> partidosDe(Iterable<Torneo> ts) {
    final ids = {for (final t in ts) t.id};
    final ligasT = {for (final l in ligas) if (ids.contains(l.torneoId)) l.id};
    return todosPartidos.where((p) => ligasT.contains(p.ligaId)).toList();
  }

  /// Cambia el torneo que se enseña en toda la web y la app.
  Future<void> elegirTorneo(String id) async {
    _elegido = id;
    try {
      await (await SharedPreferences.getInstance()).setString(_claveElegido, id);
    } catch (_) {}
    _construir();
  }

  /// Vuelve a calcular qué torneo enseñar (p. ej. al entrar o salir el personal).
  void repasarTorneo() => _construir();

  /// Proyecto (contenido) del torneo elegido.
  Proyecto? get proyecto => torneo?.proyecto;

  /// Días de juego del torneo elegido.
  List<DateTime> get jornadasTorneo {
    final t = torneo;
    if (t == null) return const [];
    final js = t.proyecto?.jornadas ?? const <DateTime>[];
    if (js.isNotEmpty) return js;
    final d = partidos.map((p) => soloDia(p.hora)).toSet().toList()..sort();
    return d.isNotEmpty ? d : [soloDia(t.inicio)];
  }

  /// Sedes del torneo elegido.
  List<Sede> get sedesTorneo => sedesDe(torneo);

  /// Sedes de un torneo: las de su proyecto, en orden. Si no trae, las de sus
  /// partidos; y si aún no tiene partidos, todas.
  List<Sede> sedesDe(Torneo? t) {
    if (t == null) return sedes;
    if (t.sedes.isNotEmpty) {
      return [for (final id in t.sedes) ...sedes.where((s) => s.id == id)];
    }
    final ligasT = {for (final l in ligas) if (l.torneoId == t.id) l.id};
    final usadas = {for (final p in todosPartidos) if (ligasT.contains(p.ligaId)) p.sedeId};
    final enPartidos = sedes.where((s) => usadas.contains(s.id)).toList();
    return enPartidos.isNotEmpty ? enPartidos : sedes;
  }

  /// Sedes de todos los torneos en curso (y del elegido), sin repetir.
  List<Sede> get sedesEnCurso {
    final ts = [for (final t in torneos) if (t.activo || t.id == torneo?.id) t];
    final vistas = <String>{};
    return [
      for (final t in ts)
        for (final s in sedesDe(t))
          if (vistas.add(s.id)) s,
    ];
  }

  /// Sedes del torneo al que pertenece un partido.
  List<Sede> sedesDePartido(Partido p) =>
      sedesDe(torneos.where((t) => t.id == liga(p.ligaId)?.torneoId).firstOrNull);

  /// [id] si es una liga del torneo elegido; si no, la primera de ese torneo.
  String? ligaDelTorneo(String? id) {
    final ls = ligasActuales;
    if (ls.isEmpty) return null;
    return ls.any((l) => l.id == id) ? id : ls.first.id;
  }

  /// Ligas del torneo actual, ordenadas por categoría y nivel.
  List<Liga> get ligasActuales {
    final t = torneo;
    if (t == null) return [];
    final l = ligas.where((x) => x.torneoId == t.id).toList();
    l.sort((a, b) {
      final ca = categoria(a.categoriaId)?.orden ?? 0;
      final cb = categoria(b.categoriaId)?.orden ?? 0;
      if (ca != cb) return ca.compareTo(cb);
      final na = Nivel.todos.indexWhere((n) => n.id == a.nivelId);
      final nb = Nivel.todos.indexWhere((n) => n.id == b.nivelId);
      if (na != nb) return na.compareTo(nb);
      return (a.grupo ?? '').compareTo(b.grupo ?? '');
    });
    return l;
  }

  Liga? ligaDe(String categoriaId, String nivelId) => ligasActuales
      .where((l) => l.categoriaId == categoriaId && l.nivelId == nivelId)
      .firstOrNull;

  /// "Benjamín 1º · Medio", o "Benjamín 1º · Medio · Grupo A" si hay grupos.
  String nombreLiga(String ligaId, {bool corto = true, bool sinGrupo = false}) {
    final l = liga(ligaId);
    if (l == null) return '';
    final c = categoria(l.categoriaId);
    final n = Nivel.de(l.nivelId);
    final cat = corto ? (c?.corto ?? '') : (c?.nombre ?? '');
    final base = n.id == 'femenino' ? cat : '$cat · ${n.nombre}';
    return l.grupo == null || sinGrupo ? base : '$base · Grupo ${l.grupo}';
  }

  /// Liga donde se juega la fase final (la propia, o la del grupo que tiene
  /// la fase final conjunta).
  String ligaFaseFinal(String ligaId) => liga(ligaId)?.finalEn ?? ligaId;

  /// ¿Esta liga tiene la fase final conjunta de varios grupos?
  bool tieneFaseConjunta(String ligaId) => ligas.any((l) => l.finalEn == ligaId);

  /// ¿Esta liga juega una fase final conjunta (en ella o en otro grupo)?
  bool enFaseConjunta(String ligaId) => liga(ligaId)?.finalEn != null || tieneFaseConjunta(ligaId);

  /// Nombre de la liga para un partido. En la fase final conjunta no se pone el grupo.
  String nombreLigaPartido(Partido p, {bool corto = true}) =>
      nombreLiga(p.ligaId, corto: corto, sinGrupo: p.fase != Fase.liga && tieneFaseConjunta(p.ligaId));

  /// Ligas de la misma categoría y nivel (los grupos), en orden.
  List<Liga> gruposDe(Liga l) => ligas
      .where((x) => x.torneoId == l.torneoId && x.categoriaId == l.categoriaId && x.nivelId == l.nivelId)
      .toList()
    ..sort((a, b) => (a.grupo ?? '').compareTo(b.grupo ?? ''));

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
    return jornadasTorneo;
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
    for (final f in filas.values) {
      f.ordenManual = ordenManual['$ligaId|${f.equipoId}'];
    }
    // Puntos y, si empatan, el orden que ponga la organización a mano
    // (reglamento: enfrentamiento directo, goles, penaltis, sorteo...).
    // Mientras no lo ponga, los empatados salen por orden alfabético.
    final lista = filas.values.toList()
      ..sort((a, b) {
        if (a.pts != b.pts) return b.pts.compareTo(a.pts);
        final oa = a.ordenManual ?? 1 << 20, ob = b.ordenManual ?? 1 << 20;
        if (oa != ob) return oa.compareTo(ob);
        return nombreEquipo(a.equipoId).compareTo(nombreEquipo(b.equipoId));
      });
    for (var i = 0; i < lista.length; i++) {
      lista[i].pos = i + 1;
    }
    for (final f in lista) {
      final iguales = lista.where((x) => x.pts == f.pts).toList();
      f.empatePendiente = f.pj > 0 && iguales.length > 1 && iguales.any((x) => x.ordenManual == null);
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
