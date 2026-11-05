import 'package:flutter_test/flutter_test.dart';
import 'package:marbel_cup/data/modelos.dart';
import 'package:marbel_cup/data/sesion.dart';

// Pruebas que no necesitan conexión con Supabase.
void main() {
  test('Contraseñas: mínimo 8 caracteres, una minúscula y un número', () {
    expect(validarPassword('corta1'), isNotNull);
    expect(validarPassword('SINMINUSCULA1'), isNotNull);
    expect(validarPassword('sinnumeros'), isNotNull);
    expect(validarPassword('marbel2026'), isNull);
  });

  test('Emails', () {
    expect(validarEmail('hola'), isNotNull);
    expect(validarEmail('hola@marbel.es'), isNull);
  });

  test('Horas en formato 24 h', () {
    expect(hhmm(DateTime(2026, 12, 26, 9, 5)), '09:05');
  });
}
