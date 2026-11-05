import 'package:flutter/material.dart';

import '../../data/datos.dart';
import '../../data/modelos.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';
import 'utiles.dart';

/// Ediciones del torneo. La marcada como "actual" es la que enseña la web.
class SeccionTorneos extends StatelessWidget {
  const SeccionTorneos({super.key});

  Future<void> _editar(BuildContext context, [Torneo? t]) async {
    final nombre = TextEditingController(text: t?.nombre ?? 'Marbel Football Cup ${DateTime.now().year}');
    final fechas = TextEditingController(text: t?.fechasTexto ?? '');
    var inicio = t?.inicio.toLocal() ?? DateTime(DateTime.now().year, 12, 26, 9);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          backgroundColor: MarbelColors.tarjeta,
          title: Text(t == null ? 'Nuevo torneo' : 'Editar torneo'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 10),
              TextField(controller: fechas, decoration: const InputDecoration(labelText: 'Fechas (texto)', hintText: '26-27 dic · 2-3 ene')),
              const SizedBox(height: 14),
              const Text('Primer partido (cuenta atrás)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFC8D0F5))),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await elegirFechaHora(c, inicio);
                  if (d != null) set(() => inicio = d);
                },
                icon: const Icon(Icons.event_rounded),
                label: Text('${diaCorto(inicio)} · ${hhmm(inicio)}'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('GUARDAR')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final fila = {
      'nombre': nombre.text.trim(),
      'fechas_texto': fechas.text.trim(),
      'inicio': inicio.toUtc().toIso8601String(),
    };
    await ejecutar(context, () async {
      if (t == null) {
        await db.from('torneos').insert({...fila, 'activo': false, 'publicado': false});
      } else {
        await db.from('torneos').update(fila).eq('id', t.id);
      }
      await datos.recargar();
    }, ok: 'Guardado');
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text(
        'El torneo «actual» es el que se ve en la web. Puedes preparar el del año que viene sin publicarlo y '
        'cambiarlo cuando quieras; las ediciones anteriores se conservan.',
        style: TextStyle(color: MarbelColors.apagado),
      ),
      const SizedBox(height: 12),
      Align(alignment: Alignment.centerLeft, child: BotonCian('Nuevo torneo', icono: Icons.add_rounded, onTap: () => _editar(context))),
      const SizedBox(height: 16),
      for (final t in datos.torneos) ...[
        Tarjeta(
          borde: t.activo ? MarbelColors.cian : null,
          child: Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 240),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(t.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                Text('${t.fechasTexto} · empieza ${diaCorto(t.inicio.toLocal())}', style: const TextStyle(color: MarbelColors.apagado)),
                Text(
                  '${datos.ligas.where((l) => l.torneoId == t.id).length} ligas',
                  style: const TextStyle(color: MarbelColors.apagado, fontSize: 13),
                ),
              ]),
            ),
            if (t.activo) const Pastilla('Actual', fondo: MarbelColors.cian, color: MarbelColors.fondo),
            Pastilla(t.publicado ? 'Publicado' : 'Oculto',
                fondo: t.publicado ? MarbelColors.elite : const Color(0xFF1E2672),
                color: t.publicado ? MarbelColors.fondo : MarbelColors.texto2),
            TextButton(onPressed: () => _editar(context, t), child: const Text('Editar')),
            TextButton(
              onPressed: () => ejecutar(context, () async {
                await db.from('torneos').update({'publicado': !t.publicado}).eq('id', t.id);
                await datos.recargar();
              }),
              child: Text(t.publicado ? 'Ocultar' : 'Publicar'),
            ),
            if (!t.activo)
              TextButton(
                onPressed: () async {
                  if (!await confirmar(context, '¿Marcar como actual?', 'La web pasará a enseñar «${t.nombre}».')) return;
                  if (!context.mounted) return;
                  await ejecutar(context, () async {
                    await db.from('torneos').update({'activo': false}).neq('id', t.id);
                    await db.from('torneos').update({'activo': true, 'publicado': true}).eq('id', t.id);
                    await datos.recargar();
                  }, ok: 'Torneo actual cambiado');
                },
                child: const Text('Marcar como actual'),
              ),
          ]),
        ),
        const SizedBox(height: 10),
      ],
    ]);
  }
}
