import 'package:flutter/material.dart';

import '../data/cola.dart';
import '../data/datos.dart';
import '../data/modelos.dart';
import '../theme/app_theme.dart';

/// Franja arriba cuando no hay conexión o hay cambios de la mesa sin enviar.
/// Si todo va bien no ocupa nada.
class FranjaConexion extends StatelessWidget {
  const FranjaConexion({super.key, this.panel = false});

  /// En el panel se enseñan también los cambios pendientes de enviar.
  final bool panel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([datos, cola]),
      builder: (context, _) {
        final pendientes = panel ? cola.pendientes : 0;
        final rechazado = panel ? cola.rechazado : null;
        if (!datos.sinConexion && pendientes == 0 && rechazado == null) return const SizedBox.shrink();

        final filas = <Widget>[];
        if (pendientes > 0) {
          filas.add(_Franja(
            color: const Color(0xFF3A2A00),
            borde: MarbelColors.medio,
            icono: Icons.cloud_upload_rounded,
            texto: pendientes == 1
                ? '1 cambio sin enviar. Se enviará solo en cuanto vuelva la conexión.'
                : '$pendientes cambios sin enviar. Se enviarán solos en cuanto vuelva la conexión.',
            accion: cola.enviando ? null : ('Reintentar', cola.enviar),
          ));
        } else if (datos.sinConexion) {
          final a = datos.actualizado;
          filas.add(_Franja(
            color: const Color(0xFF1E2672),
            borde: const Color(0xFF3A44B8),
            icono: Icons.cloud_off_rounded,
            texto: a == null ? 'Sin conexión' : 'Sin conexión · datos de las ${hhmm(a)}${_dia(a)}',
          ));
        }
        if (rechazado != null) {
          filas.add(_Franja(
            color: const Color(0xFF4A1020),
            borde: const Color(0xFFFF7A85),
            icono: Icons.error_outline_rounded,
            texto: 'Un cambio no se ha podido guardar: $rechazado',
            accion: ('Entendido', () {
              cola.rechazado = null;
              datos.repintar();
            }),
          ));
        }
        return Column(mainAxisSize: MainAxisSize.min, children: filas);
      },
    );
  }

  String _dia(DateTime a) {
    final hoy = DateTime.now();
    return a.year == hoy.year && a.month == hoy.month && a.day == hoy.day ? '' : ' del ${diaCorto(a)}';
  }
}

class _Franja extends StatelessWidget {
  const _Franja({required this.color, required this.borde, required this.icono, required this.texto, this.accion});
  final Color color;
  final Color borde;
  final IconData icono;
  final String texto;
  final (String, VoidCallback)? accion;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borde, width: 2))),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          Icon(icono, size: 20, color: MarbelColors.blanco),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: MarbelColors.blanco))),
          if (accion != null)
            TextButton(
              onPressed: accion!.$2,
              child: Text(accion!.$1, style: const TextStyle(color: MarbelColors.cian, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }
}
