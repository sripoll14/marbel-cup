import 'package:flutter/material.dart';

import 'contenido.dart';
import 'modelos.dart';

/// Proyecto de un torneo: todo su contenido (portada, información, horarios,
/// precios, preguntas...) en un archivo .json que se sube desde el panel.
/// El formato está explicado en PROYECTOS.md.
class Proyecto {
  Proyecto(this.json);

  static const formato = 'marbel-cup-torneo';

  /// El archivo tal cual.
  final Map<String, dynamic> json;

  static Proyecto? desde(dynamic v) => v is Map ? Proyecto(Map<String, dynamic>.from(v)) : null;

  String get nombre => _t(json['nombre']) ?? '';
  String get fechas => _t(json['fechas']) ?? '';
  DateTime? get inicio => DateTime.tryParse(_t(json['inicio']) ?? '')?.toLocal();
  DateTime? get inscripcionHasta => DateTime.tryParse(_t(json['inscripcion_hasta']) ?? '');

  /// Días de juego (para la cuenta atrás y el calendario).
  List<DateTime> get jornadas => [
        for (final d in _lista(json['jornadas']))
          if (DateTime.tryParse('$d') != null) soloDia(DateTime.parse('$d')),
      ]..sort();

  /// Horas de juego de cada jornada (por defecto, de 9 a 21).
  int get horaDesde => _hora(_mapa(json['horas'])['desde'], 9);
  int get horaHasta => _hora(_mapa(json['horas'])['hasta'], 21);

  /// Nombres de las sedes, en orden (las columnas del cuadro de horarios).
  List<String> get sedes => [
        for (final s in _lista(json['sedes']))
          if (s is Map) '${s['nombre'] ?? ''}' else '$s',
      ].where((s) => s.trim().isNotEmpty).toList();

  /// Sedes que vienen con todos sus datos (para crearlas si no existen).
  List<Map<String, dynamic>> get sedesCompletas => [
        for (final s in _lista(json['sedes']))
          if (s is Map) Map<String, dynamic>.from(s),
      ];

  /// 'todos' = en «Equipos» salen todos los clubes; si no, solo los inscritos.
  bool get todosLosEquipos => json['equipos'] == 'todos';

  Map<String, dynamic> get portada => _mapa(json['portada']);
  String? get etiqueta => _t(portada['etiqueta']);
  String? get lema => _t(portada['lema']);
  String? get donde => _t(portada['donde']);
  String? get inscripcionTexto => _t(portada['inscripcion']);

  /// Enlace del botón «Inscribe tu equipo» (si no, el WhatsApp de Marbel).
  String? get inscripcionUrl {
    final u = _t(portada['inscripcion_url']) ?? _t(json['inscripcion_url']);
    return u == null || u.isEmpty ? null : u;
  }

  /// Título de la página de información, en líneas (la última, en cian).
  List<String> get tituloInfo => [for (final l in _lista(portada['titulo_info'])) '$l'];

  /// Tarjetas de datos de la página de información: (título, valor).
  List<(String, String)> get datos => [
        for (final d in _lista(portada['datos']))
          if (d is List && d.length >= 2) ('${d[0]}', '${d[1]}'),
      ];

  List<Map<String, dynamic>> get bloquesInicio => _bloques(json['inicio_bloques']);
  List<Map<String, dynamic>> get bloquesInfo => _bloques(json['info_bloques']);

  /// Cuadro «qué se juega cada día en cada sede» (el primero que haya).
  List<DiaHorario> get horario {
    for (final b in [...bloquesInfo, ...bloquesInicio]) {
      if (b['tipo'] == 'horario') return horarioDe(b);
    }
    return const [];
  }

  /// "Sáb 26: Infantil F11 · Dom 3: Benjamín" para la sede en la posición [i].
  String resumenSede(int i) {
    final partes = <String>[];
    for (final d in horario) {
      if (i >= d.sedes.length) continue;
      final b = d.sedes[i];
      if (b.isEmpty) continue;
      final nombres = b.map((x) => x.categoria.replaceAll(' 1º año', '').replaceAll(' 2º año', '')).toSet().join(' y ');
      partes.add('${diaSemanaCorto(d.dia)} ${d.dia.day}: $nombres');
    }
    return partes.join(' · ');
  }

  /// null si el archivo vale; si no, qué le pasa.
  static String? problema(Map<String, dynamic> j) {
    if (j['formato'] != formato) {
      return 'Este archivo no es un proyecto de torneo de Marbel Cup (falta "formato": "$formato").';
    }
    if ((_t(j['nombre']) ?? '').isEmpty) return 'Falta el nombre del torneo ("nombre").';
    if ((_t(j['fechas']) ?? '').isEmpty) return 'Faltan las fechas en texto ("fechas").';
    if (DateTime.tryParse(_t(j['inicio']) ?? '') == null) {
      return 'Falta o está mal el primer partido ("inicio", por ejemplo "2026-12-26T09:00:00+01:00").';
    }
    for (final b in [..._bloques(j['inicio_bloques']), ..._bloques(j['info_bloques'])]) {
      if (!tiposDeBloque.contains(b['tipo'])) return 'Hay un bloque de un tipo que no existe: "${b['tipo']}".';
    }
    return null;
  }

  static const tiposDeBloque = {
    'niveles', 'mapa_sedes', 'sedes', 'horario', 'lista_iconos', 'equipos_destacados',
    'precios', 'preguntas', 'texto', 'imagen', 'contacto', 'opinion',
  };
}

/// Cuadro de horarios de un bloque `horario`.
List<DiaHorario> horarioDe(Map<String, dynamic> bloque) => [
      for (final d in _lista(bloque['dias']))
        if (d is Map && DateTime.tryParse('${d['dia']}') != null)
          DiaHorario(soloDia(DateTime.parse('${d['dia']}')), [
            for (final sede in _lista(d['sedes']))
              [
                for (final x in _lista(sede))
                  if (x is Map)
                    Bloque(
                      '${x['categoria'] ?? ''}',
                      [for (final n in _lista(x['niveles'])) Nivel.de('$n')],
                      switch (x['franja']) { 'manana' => Franja.manana, 'tarde' => Franja.tarde, _ => Franja.todoElDia },
                    ),
              ],
          ]),
    ];

/// Iconos que se pueden usar en los proyectos (por nombre).
const iconosProyecto = <String, IconData>{
  'calendario': Icons.calendar_month_rounded,
  'silbato': Icons.sports_rounded,
  'balon': Icons.sports_soccer_rounded,
  'agua': Icons.water_drop_rounded,
  'musica': Icons.music_note_rounded,
  'camara': Icons.photo_camera_rounded,
  'micro': Icons.mic_rounded,
  'seguro': Icons.health_and_safety_rounded,
  'pulsera': Icons.badge_rounded,
  'medalla': Icons.military_tech_rounded,
  'trofeo': Icons.emoji_events_rounded,
  'estrella': Icons.star_rounded,
  'fiesta': Icons.celebration_rounded,
  'reloj': Icons.schedule_rounded,
  'ubicacion': Icons.place_rounded,
  'euro': Icons.euro_rounded,
  'comida': Icons.restaurant_rounded,
  'parking': Icons.local_parking_rounded,
  'bus': Icons.directions_bus_rounded,
  'info': Icons.info_rounded,
  'grupo': Icons.groups_rounded,
  'regalo': Icons.card_giftcard_rounded,
  'corazon': Icons.favorite_rounded,
};

IconData iconoDe(dynamic nombre) => iconosProyecto['$nombre'] ?? Icons.check_circle_rounded;

String? _t(dynamic v) => v == null ? null : '$v'.trim();
List<dynamic> _lista(dynamic v) => v is List ? v : const [];
Map<String, dynamic> _mapa(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const {};
List<Map<String, dynamic>> _bloques(dynamic v) => [
      for (final b in _lista(v))
        if (b is Map && b['oculto'] != true) Map<String, dynamic>.from(b),
    ];
int _hora(dynamic v, int siNo) => int.tryParse('${v ?? ''}'.split(':').first) ?? siNo;
