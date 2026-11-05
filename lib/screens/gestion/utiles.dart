import 'package:flutter/material.dart';

import '../../data/sesion.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';

/// Ejecuta una operación y avisa del resultado.
Future<bool> ejecutar(BuildContext context, Future<void> Function() f, {String? ok}) async {
  try {
    await f();
    if (ok != null && context.mounted) avisar(context, ok);
    return true;
  } catch (e) {
    if (context.mounted) avisar(context, 'No se ha podido: ${mensajeError(e)}', error: true);
    return false;
  }
}

Future<bool> confirmar(BuildContext context, String titulo, String texto, {String boton = 'Sí'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: MarbelColors.tarjeta,
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(boton.toUpperCase())),
      ],
    ),
  );
  return r == true;
}

/// Elige fecha y hora (en hora local).
Future<DateTime?> elegirFechaHora(BuildContext context, DateTime inicial) async {
  final d = await showDatePicker(
    context: context,
    initialDate: inicial,
    firstDate: DateTime(2025),
    lastDate: DateTime(2030),
  );
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(inicial));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

/// Desplegable sencillo con etiqueta.
class Desplegable<T> extends StatelessWidget {
  const Desplegable({super.key, required this.etiqueta, required this.valor, required this.opciones, required this.onCambio});
  final String etiqueta;
  final T? valor;
  final List<(T, String)> opciones;
  final ValueChanged<T?> onCambio;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFC8D0F5))),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: MarbelColors.fondoAlto,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2B35A6)),
        ),
        child: DropdownButton<T>(
          value: opciones.any((o) => o.$1 == valor) ? valor : null,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: MarbelColors.tarjeta,
          hint: const Text('Elige'),
          items: [for (final o in opciones) DropdownMenuItem<T>(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis))],
          onChanged: onCambio,
        ),
      ),
    ]);
  }
}

/// Título de bloque dentro de una sección.
class SubTitulo extends StatelessWidget {
  const SubTitulo(this.texto, {super.key, this.derecha});
  final String texto;
  final Widget? derecha;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(child: Text(texto.toUpperCase(), style: MarbelText.titular(24).copyWith(fontStyle: FontStyle.normal))),
        if (derecha != null) derecha!,
      ]),
    );
  }
}
