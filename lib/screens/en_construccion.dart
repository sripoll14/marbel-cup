import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pantalla provisional mientras construimos cada sección.
/// Desaparece cuando la sección real esté hecha.
class EnConstruccion extends StatelessWidget {
  const EnConstruccion({
    super.key,
    required this.titulo,
    required this.icono,
    required this.texto,
  });

  final String titulo;
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 64, color: MarbelColors.cian),
            const SizedBox(height: 16),
            Text(titulo.toUpperCase(),
                style: MarbelText.titular(44), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                texto,
                textAlign: TextAlign.center,
                style: const TextStyle(color: MarbelColors.apagado, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
