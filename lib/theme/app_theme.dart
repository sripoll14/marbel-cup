import 'package:flutter/material.dart';

/// Colores de Marbel Football Cup (los mismos del diseño).
class MarbelColors {
  static const fondo = Color(0xFF060A2B);
  static const fondoAlto = Color(0xFF070C36);
  static const tarjeta = Color(0xFF0C1250);
  static const borde = Color(0xFF232C8A);
  static const azul = Color(0xFF2D2BFF);
  static const cian = Color(0xFF2EE6F2);
  static const blanco = Color(0xFFFFFFFF);
  static const texto2 = Color(0xFFDCE2FF);
  static const apagado = Color(0xFFA9B3E6);

  // Niveles
  static const iniciacion = Color(0xFFFF7A1A);
  static const medio = Color(0xFFFFD400);
  static const elite = Color(0xFF22C55E);
  static const femenino = Color(0xFFFF4FB8);
  static const enJuego = Color(0xFFFF4F5A);
}

/// Estilos de texto propios.
class MarbelText {
  /// Titulares grandes: condensada, extra negrita, cursiva, en mayúsculas.
  static TextStyle titular(double size, {Color color = MarbelColors.blanco}) =>
      TextStyle(
        fontFamily: 'BarlowCondensed',
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        fontSize: size,
        height: .9,
        color: color,
      );

  /// Etiquetas pequeñas en mayúsculas (tipo "IV TORNEO NAVIDEÑO").
  static TextStyle etiqueta({Color color = MarbelColors.cian, double size = 14}) =>
      TextStyle(
        fontFamily: 'BarlowCondensed',
        fontWeight: FontWeight.w700,
        fontSize: size,
        letterSpacing: 1.8,
        color: color,
      );
}

class AppTheme {
  static ThemeData get oscuro {
    final esquema = ColorScheme.fromSeed(
      seedColor: MarbelColors.azul,
      brightness: Brightness.dark,
    ).copyWith(
      primary: MarbelColors.cian,
      onPrimary: MarbelColors.fondo,
      secondary: MarbelColors.azul,
      onSecondary: MarbelColors.blanco,
      surface: MarbelColors.tarjeta,
      onSurface: MarbelColors.blanco,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: esquema,
      fontFamily: 'Barlow',
      scaffoldBackgroundColor: MarbelColors.fondo,
      appBarTheme: const AppBarTheme(
        backgroundColor: MarbelColors.fondo,
        foregroundColor: MarbelColors.blanco,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: MarbelColors.tarjeta,
        indicatorColor: MarbelColors.azul,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MarbelColors.cian,
          foregroundColor: MarbelColors.fondo,
          minimumSize: const Size(44, 48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'BarlowCondensed',
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: .6,
          ),
        ),
      ),
    );
  }
}
