import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Utilidades de lectura
// ---------------------------------------------------------------------------
String? _s(dynamic v) => v?.toString();
int? _i(dynamic v) => v == null ? null : (v as num).toInt();
double? _d(dynamic v) => v == null ? null : (v as num).toDouble();
DateTime? _t(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();

// ---------------------------------------------------------------------------
// Niveles
// ---------------------------------------------------------------------------
class Nivel {
  const Nivel(this.id, this.nombre, this.color, this.texto);
  final String id;
  final String nombre;
  final Color color;
  final Color texto; // color del texto encima

  static const iniciacion =
      Nivel('iniciacion', 'Iniciación', MarbelColors.iniciacion, Color(0xFF1A0A00));
  static const medio = Nivel('medio', 'Medio', MarbelColors.medio, Color(0xFF1A1400));
  static const elite = Nivel('elite', 'Élite', MarbelColors.elite, Color(0xFF03220F));
  static const femenino =
      Nivel('femenino', 'Femenino', MarbelColors.femenino, Color(0xFF2A0019));

  static const todos = [iniciacion, medio, elite, femenino];

  static Nivel de(String? id) =>
      todos.firstWhere((n) => n.id == id, orElse: () => medio);
}

// ---------------------------------------------------------------------------
// Tablas
// ---------------------------------------------------------------------------
class Torneo {
  Torneo.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        nombre = m['nombre'] as String,
        fechasTexto = m['fechas_texto'] as String,
        inicio = _t(m['inicio'])!,
        inscripcionHasta = m['inscripcion_hasta'] == null
            ? null
            : DateTime.parse(m['inscripcion_hasta'] as String),
        activo = m['activo'] as bool? ?? false,
        publicado = m['publicado'] as bool? ?? true;

  final String id;
  final String nombre;
  final String fechasTexto;
  final DateTime inicio;
  final DateTime? inscripcionHasta;
  final bool activo;
  final bool publicado;
}

class Sede {
  Sede.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        nombre = m['nombre'] as String,
        nombreOficial = m['nombre_oficial'] as String? ?? '',
        mapsUrl = _s(m['maps_url']),
        fotoUrl = _s(m['foto_url']),
        servicios = (m['servicios'] as List?)?.cast<String>() ?? const [],
        lat = _d(m['lat']),
        lon = _d(m['lon']),
        raw = m;

  final String id;
  final String nombre;
  final String nombreOficial;
  final String? mapsUrl;
  final String? fotoUrl;
  final List<String> servicios;
  final double? lat;
  final double? lon;
  final Map<String, dynamic> raw;

  /// Nombre corto para chips ("Granja" en vez de "Granja de Rocamora").
  String get corto => nombre.startsWith('Granja') ? 'Granja' : nombre;
}

class Categoria {
  Categoria.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        nombre = m['nombre'] as String,
        femenina = m['femenina'] as bool? ?? false,
        orden = _i(m['orden']) ?? 0;

  final String id;
  final String nombre;
  final bool femenina;
  final int orden;

  /// "Benjamín 1º año" -> "Benjamín 1º"
  String get corto => nombre.replaceAll(' año', '').replaceAll(' femenino', '');

  /// Grupo para los filtros: Prebenjamín, Benjamín, Alevín, Infantil F11, Sub 12, Infantil F8
  String get grupo {
    if (nombre.startsWith('Prebenjamín')) return 'Prebenjamín';
    if (nombre.startsWith('Benjamín')) return 'Benjamín';
    if (nombre.startsWith('Alevín')) return 'Alevín';
    if (nombre.startsWith('Sub 12')) return 'Sub 12';
    if (nombre.contains('F8')) return 'Infantil F8';
    return 'Infantil F11';
  }
}

class Equipo {
  Equipo.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        nombre = m['nombre'] as String,
        localidad = _s(m['localidad']),
        escudoUrl = _s(m['escudo_url']);

  final String id;
  final String nombre;
  final String? localidad;
  final String? escudoUrl;

  String get iniciales {
    final p = nombre
        .replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÑáéíóúñ ]'), ' ')
        .split(' ')
        .where((w) => w.length > 2)
        .toList();
    if (p.isEmpty) return nombre.substring(0, 1);
    return p.take(2).map((w) => w[0].toUpperCase()).join();
  }
}

class Liga {
  Liga.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        torneoId = m['torneo_id'] as String,
        categoriaId = m['categoria_id'] as String,
        nivelId = m['nivel_id'] as String;

  final String id;
  final String torneoId;
  final String categoriaId;
  final String nivelId;
}

enum Fase { liga, semifinal, tercerPuesto, final_ }

Fase _fase(String s) => switch (s) {
      'semifinal' => Fase.semifinal,
      'tercer_puesto' => Fase.tercerPuesto,
      'final' => Fase.final_,
      _ => Fase.liga,
    };

String faseSql(Fase f) => switch (f) {
      Fase.liga => 'liga',
      Fase.semifinal => 'semifinal',
      Fase.tercerPuesto => 'tercer_puesto',
      Fase.final_ => 'final',
    };

enum Estado { programado, enJuego, finalizado, aplazado }

Estado _estado(String s) => switch (s) {
      'en_juego' => Estado.enJuego,
      'finalizado' => Estado.finalizado,
      'aplazado' => Estado.aplazado,
      _ => Estado.programado,
    };

String estadoSql(Estado e) => switch (e) {
      Estado.programado => 'programado',
      Estado.enJuego => 'en_juego',
      Estado.finalizado => 'finalizado',
      Estado.aplazado => 'aplazado',
    };

class Partido {
  Partido.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        ligaId = m['liga_id'] as String,
        fase = _fase(m['fase'] as String),
        jornada = _i(m['jornada']),
        localId = _s(m['local_id']),
        visitanteId = _s(m['visitante_id']),
        sedeId = _s(m['sede_id']),
        campo = _s(m['campo']),
        hora = _t(m['hora'])!,
        retrasoMin = _i(m['retraso_min']) ?? 0,
        estado = _estado(m['estado'] as String),
        golesLocal = _i(m['goles_local']),
        golesVisitante = _i(m['goles_visitante']),
        penaltisLocal = _i(m['penaltis_local']),
        penaltisVisitante = _i(m['penaltis_visitante']),
        actualizado = _t(m['actualizado']);

  final String id;
  final String ligaId;
  final Fase fase;
  final int? jornada;
  final String? localId;
  final String? visitanteId;
  final String? sedeId;
  final String? campo;
  final DateTime hora;
  final int retrasoMin;
  final Estado estado;
  final int? golesLocal;
  final int? golesVisitante;
  final int? penaltisLocal;
  final int? penaltisVisitante;
  final DateTime? actualizado;

  DateTime get horaReal => hora.add(Duration(minutes: retrasoMin));

  bool get tieneMarcador => golesLocal != null && golesVisitante != null;

  /// Debería haber empezado hace más de 10 minutos y sigue sin empezar.
  bool get retrasado =>
      estado == Estado.programado &&
      DateTime.now().isAfter(horaReal.add(const Duration(minutes: 10)));

  int get minutosDeRetraso =>
      DateTime.now().difference(hora).inMinutes.clamp(0, 999);

  String? get ganadorId {
    if (estado != Estado.finalizado || !tieneMarcador) return null;
    if (golesLocal! > golesVisitante!) return localId;
    if (golesLocal! < golesVisitante!) return visitanteId;
    if ((penaltisLocal ?? -1) > (penaltisVisitante ?? -1)) return localId;
    if ((penaltisLocal ?? -1) < (penaltisVisitante ?? -1)) return visitanteId;
    return null;
  }

  /// Minuto aproximado de juego (para "En directo").
  String get minutoTexto {
    final m = DateTime.now().difference(horaReal).inMinutes;
    if (m < 0) return '';
    return "$m'";
  }
}

class FilaClasificacion {
  FilaClasificacion(this.equipoId);
  final String equipoId;
  int pj = 0, g = 0, e = 0, p = 0, gf = 0, gc = 0;
  int pos = 0;
  int get dg => gf - gc;
  int get pts => g * 3 + e;
  String get dgTexto => dg > 0 ? '+$dg' : '$dg';
}

class Aviso {
  Aviso.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        texto = m['texto'] as String,
        fijado = m['fijado'] as bool? ?? false,
        creado = _t(m['creado'])!,
        ambito = m['ambito'] as String? ?? 'todos',
        ambitoRef = _s(m['ambito_ref']),
        automatico = m['automatico'] as bool? ?? false,
        imagenes = [for (final u in (m['imagenes'] as List?) ?? const []) u as String];

  final String id;
  final String texto;

  /// Fotos del aviso (escudos, carteles...). Como mucho 4.
  final List<String> imagenes;
  final bool fijado;
  final DateTime creado;
  final String ambito;
  final String? ambitoRef;
  final bool automatico;
}

class Gol {
  Gol.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        partidoId = m['partido_id'] as String,
        equipoId = m['equipo_id'] as String,
        jugador = m['jugador'] as String,
        minuto = _i(m['minuto']);

  final String id;
  final String partidoId;
  final String equipoId;
  final String jugador;
  final int? minuto;
}

class Foto {
  Foto.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        url = m['url'] as String,
        pie = m['pie'] as String? ?? '',
        vertical = m['vertical'] as bool? ?? false,
        orden = _i(m['orden']) ?? 0;

  final String id;
  final String url;
  final String pie;
  final bool vertical;
  final int orden;
}

enum Rol { usuario, comunicacion, mesa, admin }

Rol rolDe(String? s) => switch (s) {
      'admin' => Rol.admin,
      'mesa' => Rol.mesa,
      'comunicacion' => Rol.comunicacion,
      _ => Rol.usuario,
    };

String rolSql(Rol r) => switch (r) {
      Rol.admin => 'admin',
      Rol.mesa => 'mesa',
      Rol.comunicacion => 'comunicacion',
      Rol.usuario => 'usuario',
    };

String rolTexto(Rol r) => switch (r) {
      Rol.admin => 'Administración',
      Rol.mesa => 'Mesa de sede',
      Rol.comunicacion => 'Comunicación',
      Rol.usuario => 'Usuario',
    };

class Perfil {
  Perfil.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        nombre = m['nombre'] as String? ?? '',
        apellidos = m['apellidos'] as String? ?? '',
        equipoId = _s(m['equipo_id']),
        rol = rolDe(m['rol'] as String?),
        roles = {
          for (final r in (m['roles'] as List?) ?? const []) rolDe(r as String?),
          if (m['roles'] == null) rolDe(m['rol'] as String?),
        }..remove(Rol.usuario),
        sedeId = _s(m['sede_id']),
        email = _s(m['email']),
        comentariosBloqueado = m['comentarios_bloqueado'] == true,
        alias = _s(m['alias']),
        aliasVetadoEn = m['alias_vetado_en'] == null ? null : DateTime.parse(m['alias_vetado_en'] as String).toLocal();

  final String id;

  /// Lo único que se ve en público (ranking de La Porra y comentarios).
  final String? alias;

  /// Si el personal ha vetado el alias: cuándo. Hay 24 h para cambiarlo.
  final DateTime? aliasVetadoEn;

  DateTime? get aliasLimite => aliasVetadoEn?.add(const Duration(hours: 24));
  bool get aliasVetado => aliasVetadoEn != null;
  bool get aliasVencido => aliasLimite != null && DateTime.now().isAfter(aliasLimite!);

  /// Puede jugar a La Porra y comentar.
  bool get puedeParticipar => alias != null && !aliasVencido;

  /// Como lo ven los demás.
  String get aliasVisible => aliasVetado ? 'Alias en revisión' : (alias ?? 'Sin alias');

  /// No puede escribir comentarios (lo decide el personal).
  final bool comentariosBloqueado;
  final String nombre;
  final String apellidos;
  final String? equipoId;
  /// Rol principal (admin > mesa > comunicación > usuario).
  final Rol rol;

  /// Todos sus roles (una persona puede ser Mesa de sede y Comunicación a la vez).
  final Set<Rol> roles;
  final String? sedeId;
  final String? email;

  bool get esPersonal => roles.isNotEmpty;

  bool tiene(Rol r) => roles.contains(r);

  /// Administración lo puede todo; si no, la mesa solo actúa en su sede.
  bool get soloSuSede => tiene(Rol.mesa) && !tiene(Rol.admin);

  /// "Mesa de sede + Comunicación"
  String get rolesTexto => roles.isEmpty
      ? rolTexto(Rol.usuario)
      : ([...roles]..sort((a, b) => b.index.compareTo(a.index))).map(rolTexto).join(' + ');

  /// "Lucía M."
  String get nombreCorto =>
      apellidos.isEmpty ? nombre : '$nombre ${apellidos.characters.first}.';

  String get iniciales =>
      '${nombre.isEmpty ? '' : nombre.characters.first}${apellidos.isEmpty ? '' : apellidos.characters.first}'
          .toUpperCase();
}

class FilaRanking {
  FilaRanking.fromMap(Map<String, dynamic> m)
      : pos = _i(m['pos']) ?? 0,
        nombre = m['nombre'] as String? ?? '',
        equipo = _s(m['equipo']),
        puntos = _i(m['puntos']) ?? 0,
        soyYo = m['soy_yo'] as bool? ?? false;

  final int pos;
  final String nombre;
  final String? equipo;
  final int puntos;
  final bool soyYo;
}

// ---------------------------------------------------------------------------
// Fechas en español
// ---------------------------------------------------------------------------
const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const _meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

String hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "Sáb 26 dic"
String diaCorto(DateTime d) =>
    '${_dias[d.weekday - 1].substring(0, 3)} ${d.day} ${_meses[d.month - 1].substring(0, 3)}';

/// "Sábado 26 de diciembre"
String diaLargo(DateTime d) => '${_dias[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}';

String diaSemanaCorto(DateTime d) => _dias[d.weekday - 1].substring(0, 3);
String mesCorto(DateTime d) => _meses[d.month - 1].substring(0, 3);

DateTime soloDia(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Hace 5 min", "10:02", "Ayer"
String cuando(DateTime d) {
  final ahora = DateTime.now();
  final dif = ahora.difference(d);
  if (dif.inMinutes < 1) return 'Ahora';
  if (dif.inMinutes < 60) return 'Hace ${dif.inMinutes} min';
  if (soloDia(d) == soloDia(ahora)) return hhmm(d);
  if (soloDia(d) == soloDia(ahora.subtract(const Duration(days: 1)))) return 'Ayer';
  return diaCorto(d);
}

/// Comentario de la página del torneo o de un partido.
class Comentario {
  Comentario.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        partidoId = _s(m['partido_id']),
        usuarioId = _s(m['usuario_id']),
        respuestaA = _s(m['respuesta_a']),
        autor = m['autor'] as String? ?? '',
        reacciones = {
          for (final e in ((m['reacciones'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt(),
        },
        texto = m['texto'] as String? ?? '',
        estado = m['estado'] as String? ?? 'publicado',
        motivo = _s(m['motivo']),
        creado = DateTime.parse(m['creado'] as String).toLocal();
  final String id;
  final String? partidoId;
  final String? usuarioId;
  /// Comentario principal al que responde (null si no es una respuesta).
  final String? respuestaA;
  final String autor;

  /// {"👏": 3, "⚽": 1}
  final Map<String, int> reacciones;
  final String texto;

  /// publicado · pendiente (filtro o denuncias) · oculto (personal) · borrado (autor)
  final String estado;
  final String? motivo;
  final DateTime creado;

  String get iniciales {
    final p = autor.replaceAll(RegExp(r'[._-]'), ' ').split(' ').where((x) => x.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p.first.characters.take(2).toString().toUpperCase();
    return p.take(2).map((x) => x.characters.first.toUpperCase()).join();
  }
}
