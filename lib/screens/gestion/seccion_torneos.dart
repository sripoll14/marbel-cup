import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/datos.dart';
import '../../data/modelos.dart';
import '../../data/proyecto.dart';
import '../../data/push_js_stub.dart' if (dart.library.js_interop) '../../data/push_js_web.dart' as js;
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';
import 'utiles.dart';

/// Torneos. Cada torneo es un proyecto (archivo .json, ver PROYECTOS.md) que
/// se sube aquí. Puede haber varios a la vez: en la web salen, en «Torneos
/// actuales», los que estén en curso y publicados.
class SeccionTorneos extends StatelessWidget {
  const SeccionTorneos({super.key});

  // ---------------------------------------------------------------------------
  // Subir un proyecto
  // ---------------------------------------------------------------------------

  /// Elige el archivo y lo comprueba. null si se cancela o no vale (ya avisa).
  Future<Proyecto?> _leerArchivo(BuildContext context) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
    final f = r?.files.firstOrNull;
    if (f == null || f.bytes == null) return null;
    String? problema;
    Map<String, dynamic>? j;
    try {
      final v = jsonDecode(utf8.decode(f.bytes!));
      if (v is Map) {
        j = Map<String, dynamic>.from(v);
        problema = Proyecto.problema(j);
      } else {
        problema = 'El archivo no tiene el formato de un proyecto.';
      }
    } catch (e) {
      problema = 'No se puede leer el archivo: no es un .json válido.\n\n$e';
    }
    if (problema != null) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: MarbelColors.tarjeta,
            title: const Text('Este archivo no vale'),
            content: SelectableText(problema!),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vale'))],
          ),
        );
      }
      return null;
    }
    return Proyecto(j!);
  }

  /// Ids de las sedes del proyecto (las que no existen, se crean).
  Future<List<String>> _sedes(Proyecto p) async {
    final ids = <String>[];
    final completas = p.sedesCompletas;
    for (final (i, nombre) in p.sedes.indexed) {
      final n = nombre.trim().toLowerCase();
      final ya = datos.sedes
          .where((s) => s.nombre.toLowerCase() == n || s.nombreOficial.toLowerCase() == n)
          .firstOrNull;
      if (ya != null) {
        ids.add(ya.id);
        continue;
      }
      final d = completas.where((s) => '${s['nombre']}'.trim().toLowerCase() == n).firstOrNull ?? const {};
      final nueva = await db
          .from('sedes')
          .insert({
            'nombre': nombre.trim(),
            'nombre_oficial': d['nombre_oficial'] ?? nombre.trim(),
            'maps_url': d['maps_url'],
            'foto_url': d['foto_url'],
            'servicios': d['servicios'] ?? const [],
            'lat': d['lat'],
            'lon': d['lon'],
            'orden': 100 + i,
          })
          .select('id')
          .single();
      ids.add(nueva['id'] as String);
    }
    return ids;
  }

  Future<Map<String, dynamic>> _fila(Proyecto p) async => {
        'nombre': p.nombre,
        'fechas_texto': p.fechas,
        'inicio': p.inicio!.toUtc().toIso8601String(),
        'inscripcion_hasta': p.inscripcionHasta?.toIso8601String().substring(0, 10),
        'sedes': await _sedes(p),
        'proyecto': p.json,
      };

  Future<void> _nuevo(BuildContext context) async {
    final p = await _leerArchivo(context);
    if (p == null || !context.mounted) return;
    await ejecutar(context, () async {
      final fila = await _fila(p);
      // Se crea en curso pero oculto: se prepara con calma y se publica cuando esté listo
      final r = await db.from('torneos').insert({...fila, 'activo': true, 'publicado': false}).select('id').single();
      await datos.recargar();
      await datos.elegirTorneo(r['id'] as String);
    }, ok: '«${p.nombre}» subido (oculto). Revísalo con «Ver cómo queda» y publícalo cuando esté listo.');
  }

  Future<void> _actualizar(BuildContext context, Torneo t) async {
    final p = await _leerArchivo(context);
    if (p == null || !context.mounted) return;
    if (!await confirmar(
        context,
        '¿Cambiar el proyecto de «${t.nombre}»?',
        'Se cambia todo su contenido (portada, información, horarios, precios, preguntas...) por el del archivo '
            '«${p.nombre}». Los equipos, ligas, partidos, resultados y La Porra no se tocan.',
        boton: 'Cambiar')) {
      return;
    }
    if (!context.mounted) return;
    await ejecutar(context, () async {
      await db.from('torneos').update(await _fila(p)).eq('id', t.id);
      await datos.recargar();
    }, ok: 'Proyecto actualizado');
  }

  // ---------------------------------------------------------------------------
  // Descargar el proyecto (copia, o para preparar otro a partir de este)
  // ---------------------------------------------------------------------------
  void _descargar(BuildContext context, Torneo t) {
    final j = <String, dynamic>{
      'formato': Proyecto.formato,
      'version': 1,
      ...?t.proyecto?.json,
      // Lo que se haya cambiado con «Editar»
      'nombre': t.nombre,
      'fechas': t.fechasTexto,
      'inicio': t.inicio.toUtc().toIso8601String(),
      if (t.inscripcionHasta != null) 'inscripcion_hasta': t.inscripcionHasta!.toIso8601String().substring(0, 10),
      if (t.proyecto == null)
        'sedes': [for (final id in t.sedes) ...datos.sedes.where((s) => s.id == id).map((s) => s.nombre)],
    };
    final nombre = '${_slug(t.nombre)}.json';
    try {
      js.descargar(nombre, const JsonEncoder.withIndent('  ').convert(j));
      avisar(context, 'Descargado: $nombre');
    } catch (_) {
      avisar(context, 'No se ha podido descargar.', error: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Retoques rápidos sin subir otro archivo
  // ---------------------------------------------------------------------------
  Future<void> _editar(BuildContext context, Torneo t) async {
    final nombre = TextEditingController(text: t.nombre);
    final fechas = TextEditingController(text: t.fechasTexto);
    var inicio = t.inicio.toLocal();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          backgroundColor: MarbelColors.tarjeta,
          title: const Text('Editar torneo'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 10),
              TextField(controller: fechas, decoration: const InputDecoration(labelText: 'Fechas (texto)')),
              const SizedBox(height: 14),
              const Text('Primer partido (cuenta atrás)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFC8D0F5))),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await elegirFechaHora(c, inicio);
                  if (d != null) set(() => inicio = d);
                },
                icon: const Icon(Icons.event_rounded),
                label: Text('${diaCorto(inicio)} · ${hhmm(inicio)}'),
              ),
              const SizedBox(height: 10),
              const Text('El resto del contenido se cambia subiendo el proyecto otra vez («Actualizar proyecto»).',
                  style: TextStyle(color: MarbelColors.apagado, fontSize: 12)),
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
    final cambios = {
      'nombre': nombre.text.trim(),
      'fechas_texto': fechas.text.trim(),
      'inicio': inicio.toUtc().toIso8601String(),
    };
    await ejecutar(context, () async {
      await db.from('torneos').update({
        ...cambios,
        // Que el proyecto diga lo mismo
        if (t.proyecto != null)
          'proyecto': {
            ...t.proyecto!.json,
            'nombre': cambios['nombre'],
            'fechas': cambios['fechas_texto'],
            'inicio': cambios['inicio'],
          },
      }).eq('id', t.id);
      await datos.recargar();
    }, ok: 'Guardado');
  }

  Future<void> _cambiar(BuildContext context, Torneo t, Map<String, dynamic> cambios, String ok) =>
      ejecutar(context, () async {
        await db.from('torneos').update(cambios).eq('id', t.id);
        await datos.recargar();
      }, ok: ok);

  @override
  Widget build(BuildContext context) {
    final torneos = [...datos.torneos]..sort((a, b) => b.inicio.compareTo(a.inicio));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text(
        'Cada torneo es un proyecto: un archivo .json con todo su contenido (portada, información, horarios, precios, '
        'preguntas...). «Nuevo torneo» sube un proyecto; «Descargar proyecto» te da el archivo de uno que ya existe, '
        'para guardarlo o para preparar otro a partir de él. El formato está explicado en PROYECTOS.md.',
        style: TextStyle(color: MarbelColors.apagado, height: 1.4),
      ),
      const SizedBox(height: 8),
      const Text(
        'Puede haber varios torneos a la vez: en la web, en «Torneos actuales», salen los que estén EN CURSO y PUBLICADOS. '
        'Un torneo oculto no lo ve el público, pero sí el personal, para prepararlo. '
        'Cuando acabe, apaga EN CURSO y deja PUBLICADO: pasa a «Torneos anteriores», con su resumen (campeones, clasificaciones y estadísticas).',
        style: TextStyle(color: MarbelColors.apagado, height: 1.4),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: BotonCian('Nuevo torneo (subir proyecto)', icono: Icons.upload_file_rounded, onTap: () => _nuevo(context)),
      ),
      const SizedBox(height: 16),
      for (final t in torneos) ...[
        Tarjeta(
          borde: t.id == datos.torneo?.id ? MarbelColors.cian : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(t.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              if (t.visible)
                const Pastilla('En la web', fondo: MarbelColors.elite, color: MarbelColors.fondo, tamano: 11)
              else if (t.anterior)
                const Pastilla('En «Torneos anteriores»', fondo: MarbelColors.medio, color: MarbelColors.fondo, tamano: 11)
              else
                const Pastilla('No se ve en la web', fondo: Color(0xFF1E2672), color: MarbelColors.texto2, tamano: 11),
              if (t.proyecto == null)
                const Pastilla('Sin proyecto', fondo: Color(0xFF3A2A00), color: MarbelColors.medio, tamano: 11),
              if (t.id == datos.torneo?.id)
                const Pastilla('Trabajando en este', fondo: MarbelColors.cian, color: MarbelColors.fondo, tamano: 11),
            ]),
            const SizedBox(height: 4),
            Text(
              [
                t.fechasTexto,
                if (t.lugar != null) t.lugar!,
                'empieza ${diaCorto(t.inicio.toLocal())}',
                '${datos.ligas.where((l) => l.torneoId == t.id).length} ligas',
              ].join(' · '),
              style: const TextStyle(color: MarbelColors.apagado),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 0, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _Interruptor(
                texto: 'En curso',
                valor: t.activo,
                onCambio: (v) => _cambiar(context, t, {'activo': v}, v ? 'En curso' : 'Ya no está en curso'),
              ),
              _Interruptor(
                texto: 'Publicado',
                valor: t.publicado,
                onCambio: (v) => _cambiar(context, t, {'publicado': v}, v ? 'Publicado' : 'Oculto'),
              ),
            ]),
            Wrap(spacing: 4, runSpacing: 0, children: [
              TextButton.icon(
                onPressed: () => _actualizar(context, t),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Actualizar proyecto'),
              ),
              TextButton.icon(
                onPressed: () => _descargar(context, t),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Descargar proyecto'),
              ),
              TextButton(onPressed: () => _editar(context, t), child: const Text('Editar')),
              if (t.id != datos.torneo?.id)
                TextButton(onPressed: () => datos.elegirTorneo(t.id), child: const Text('Trabajar en este')),
              TextButton(
                onPressed: () async {
                  await datos.elegirTorneo(t.id);
                  if (context.mounted) context.go('/torneos/${t.id}');
                },
                child: Text(t.visible ? 'Ver en la web ↗' : 'Ver cómo queda ↗'),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
      ],
    ]);
  }
}

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u')
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

class _Interruptor extends StatelessWidget {
  const _Interruptor({required this.texto, required this.valor, required this.onCambio});
  final String texto;
  final bool valor;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Switch(value: valor, onChanged: onCambio),
      Text(texto, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(width: 12),
    ]);
  }
}
