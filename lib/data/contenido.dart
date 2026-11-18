
import 'modelos.dart';

/// Datos fijos de Marbel (contacto). Lo de cada torneo va en su proyecto
/// (archivo .json que se sube desde el panel, ver PROYECTOS.md).
class Contenido {
  static const whatsapp1 = '689 355 868';
  static const whatsapp2 = '611 73 53 04';
  static const whatsappUrl1 = 'https://wa.me/34689355868';
  static const whatsappUrl2 = 'https://wa.me/34611735304';
  static const instagram = '@marbel.cup';
  static const instagramUrl = 'https://www.instagram.com/marbel.cup';
  static const email = 'marbel.sport@gmail.com';
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
