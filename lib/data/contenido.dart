import 'package:flutter/material.dart';

import 'modelos.dart';

/// Textos y datos fijos del torneo (salen del dossier). Si algo cambia,
/// se edita aquí.
class Contenido {
  static const whatsapp1 = '689 355 868';
  static const whatsapp2 = '611 73 53 04';
  static const whatsappUrl1 = 'https://wa.me/34689355868';
  static const whatsappUrl2 = 'https://wa.me/34611735304';
  static const instagram = '@marbel.cup';
  static const instagramUrl = 'https://www.instagram.com/marbel.cup';
  static const email = 'marbel.sport@gmail.com';

  static const lema = 'Fútbol, diversión y competición en un torneo único. Tú eliges el nivel '
      'y la categoría: cuatro sedes en la Vega Baja, a 10–15 minutos entre ellas.';

  /// Fechas de las 4 jornadas (9:00 a 21:00, hora de España).
  static final jornadas = [
    DateTime(2026, 12, 26), DateTime(2026, 12, 27),
    DateTime(2027, 1, 2), DateTime(2027, 1, 3),
  ];

  static const niveles = [
    (Nivel.iniciacion, 'Para equipos que empiezan'),
    (Nivel.medio, 'Competición equilibrada'),
    (Nivel.elite, 'Máximo nivel competitivo'),
    (Nivel.femenino, 'Sub 12 e Infantil F8'),
  ];

  static const categoriasMasculino = [
    'Prebenjamín 1º y 2º año',
    'Benjamín 1º y 2º año',
    'Alevín 1º y 2º año',
    'Infantil 1º y 2º año (mixto) · F11',
  ];
  static const categoriasFemenino = ['Sub 12', 'Infantil · F8'];
  static const quienParticipa = [
    'Equipos federados y no federados',
    'Escuelas',
    'Ligas asociadas (Brave, Faler…)',
    'Academias',
  ];

  // -------------------------------------------------------------------------
  // Qué se juega, cuándo y dónde (calendario por sede)
  // Columnas en el orden de las sedes: Albatera, Granja, Rafal, Bigastro.
  // -------------------------------------------------------------------------
  static final horario = <DiaHorario>[
    DiaHorario(DateTime(2026, 12, 26), [
      [Bloque('Infantil F11', [Nivel.iniciacion, Nivel.medio], Franja.todoElDia)],
      [Bloque('Infantil F11', [Nivel.iniciacion, Nivel.medio], Franja.todoElDia)],
      [Bloque('Benjamín 1º año', [Nivel.medio], Franja.manana),
       Bloque('Benjamín 2º año', [Nivel.medio], Franja.tarde)],
      [Bloque('Sub 12', [Nivel.femenino], Franja.manana),
       Bloque('F8 Infantil', [Nivel.femenino], Franja.tarde)],
    ]),
    DiaHorario(DateTime(2026, 12, 27), [
      [],
      [Bloque('Prebenjamín 1º año', [Nivel.medio], Franja.manana),
       Bloque('Prebenjamín 2º año', [Nivel.medio], Franja.tarde)],
      [Bloque('Prebenjamín 1º año', [Nivel.iniciacion], Franja.manana),
       Bloque('Prebenjamín 2º año', [Nivel.iniciacion], Franja.tarde)],
      [Bloque('Prebenjamín 1º año', [Nivel.elite], Franja.manana),
       Bloque('Prebenjamín 2º año', [Nivel.elite], Franja.tarde)],
    ]),
    DiaHorario(DateTime(2027, 1, 2), [
      [Bloque('Alevín 1º año', [Nivel.medio], Franja.manana),
       Bloque('Alevín 2º año', [Nivel.medio], Franja.tarde)],
      [Bloque('Alevín 1º año', [Nivel.elite], Franja.manana),
       Bloque('Alevín 2º año', [Nivel.elite], Franja.tarde)],
      [],
      [Bloque('Alevín 1º año', [Nivel.iniciacion], Franja.manana),
       Bloque('Alevín 2º año', [Nivel.iniciacion], Franja.tarde)],
    ]),
    DiaHorario(DateTime(2027, 1, 3), [
      [Bloque('Benjamín 1º año', [Nivel.iniciacion], Franja.manana),
       Bloque('Benjamín 2º año', [Nivel.iniciacion], Franja.tarde)],
      [Bloque('Infantil F11', [Nivel.medio, Nivel.elite], Franja.todoElDia)],
      [Bloque('Infantil F11', [Nivel.medio, Nivel.elite], Franja.todoElDia)],
      [Bloque('Benjamín 1º año', [Nivel.elite], Franja.manana),
       Bloque('Benjamín 2º año', [Nivel.elite], Franja.tarde)],
    ]),
  ];

  /// "Sáb 26: Infantil F11 · Sáb 2: Alevín · Dom 3: Benjamín" para una sede.
  static String resumenSede(int indiceSede) {
    final partes = <String>[];
    for (final d in horario) {
      if (indiceSede >= d.sedes.length) continue;
      final b = d.sedes[indiceSede];
      if (b.isEmpty) continue;
      final nombres = b
          .map((x) => x.categoria.replaceAll(' 1º año', '').replaceAll(' 2º año', ''))
          .toSet()
          .join(' y ');
      partes.add('${diaSemanaCorto(d.dia)} ${d.dia.day}: $nombres');
    }
    return partes.join(' · ');
  }

  // -------------------------------------------------------------------------
  // Ficha del torneo
  // -------------------------------------------------------------------------
  static const incluye = [
    (Icons.calendar_month_rounded, 'Mínimo 4 partidos asegurados'),
    (Icons.sports_rounded, 'Árbitros federados'),
    (Icons.sports_soccer_rounded, 'Balones federados'),
    (Icons.water_drop_rounded, 'Fruta y agua durante todo el torneo'),
    (Icons.music_note_rounded, 'Speaker y animación musical'),
    (Icons.photo_camera_rounded, 'Servicio de fotografía'),
    (Icons.mic_rounded, 'Entrevistas a jugadores y entrenadores'),
    (Icons.health_and_safety_rounded, 'Seguro de R.C. y de lesiones'),
    (Icons.badge_rounded, 'Pulsera acreditativa del torneo'),
    (Icons.military_tech_rounded, 'Medallas a los 1º, 2º y 3º'),
    (Icons.emoji_events_rounded, 'Trofeo a todos los equipos'),
    (Icons.star_rounded, 'Gala final para todos los equipos'),
  ];

  static const premiosTexto =
      'Los 3 primeros: trofeo por equipo y medalla individual. El resto: trofeo por equipo y obsequio individual.';
  static const ceremoniaTexto = 'Todos los equipos pasan por la ceremonia final de entrega de trofeos.';

  /// Cabezas de serie de la categoría Élite (null = por anunciar).
  static const elite = ['F.C. Cartagena SAD', 'Albacete Balompié', null, null, null, null];

  static const precios = [('Fútbol 8', '200€'), ('Fútbol 11', '250€')];

  static const pasos = [
    ('Reserva del equipo', 'Con una cuota de 100€.'),
    ('Resto del pago', 'Antes del 10 de diciembre.'),
    ('Inscripción rellenada', 'Entregarla antes del 20 de diciembre.'),
  ];
  static const avisoReserva =
      'El importe de la reserva no se devuelve. Las plazas no se guardan sin el pago.';

  static const faqs = [
    ('¿Puedo elegir el nivel de mi equipo?',
        'Sí. Al inscribiros elegís categoría y nivel (iniciación, medio o élite). La organización puede reubicar a un equipo si el nivel no encaja.'),
    ('¿Qué pasa si dos equipos empatan a puntos en la liga?',
        'Como en la liga profesional: desempata la diferencia de goles (goles a favor menos goles en contra). Si sigue el empate, el que haya marcado más goles.'),
    ('¿Cuántos partidos jugamos como mínimo?',
        'Cada equipo juega 4 partidos en su liga. Los 4 primeros pasan a semifinales (1º vs 4º y 2º vs 3º). Los ganadores juegan la final y los perdedores, el partido por el 3er y 4º puesto.'),
    ('¿Cómo me entero de horarios y cambios de campo?',
        'En el calendario de la web y en la app. Si sigues a tu equipo (★), en Avisos verás al momento cualquier cambio.'),
    ('¿Qué pasa si reservo y luego no podemos ir?',
        'El importe de la reserva (100€) no se devuelve. Para cualquier otro caso, consultad con la organización.'),
    ('¿Hay sitio para aparcar y algo para comer?',
        'Sí. Las cuatro sedes tienen cantina, zona de aparcamiento y espacios alternos.'),
    ('¿Se publican datos de los jugadores?',
        'No publicamos plantillas, edades ni fotos de perfil. En las estadísticas puede aparecer el nombre de un jugador o jugadora (nombre e inicial del apellido), siempre junto a su equipo. Las fotos de la galería están autorizadas por los clubes.'),
  ];
}

enum Franja { manana, tarde, todoElDia }

class Bloque {
  const Bloque(this.categoria, this.niveles, this.franja);
  final String categoria;
  final List<Nivel> niveles;
  final Franja franja;

  String get nivelesTexto => niveles.map((n) => n.nombre).join(' – ');
}

class DiaHorario {
  const DiaHorario(this.dia, this.sedes);
  final DateTime dia;

  /// Una lista de bloques por sede (Albatera, Granja, Rafal, Bigastro).
  final List<List<Bloque>> sedes;
}
