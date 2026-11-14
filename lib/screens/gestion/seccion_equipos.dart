import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datos.dart';
import '../../data/modelos.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';
import 'utiles.dart';

/// Elige una imagen y la sube a un bucket público. Devuelve su URL.
Future<String?> subirImagen(BuildContext context, String bucket, String prefijo) async {
  final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
  final f = r?.files.firstOrNull;
  if (f == null || f.bytes == null) return null;
  if (f.size > 5 * 1024 * 1024) {
    if (context.mounted) avisar(context, 'La imagen pesa más de 5 MB. Redúcela antes de subirla.', error: true);
    return null;
  }
  final ext = (f.extension ?? 'jpg').toLowerCase();
  final ruta = '$prefijo-${DateTime.now().millisecondsSinceEpoch}.$ext';
  await db.storage.from(bucket).uploadBinary(
        ruta,
        f.bytes!,
        fileOptions: FileOptions(contentType: ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg')),
      );
  return db.storage.from(bucket).getPublicUrl(ruta);
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

/// Equipos inscritos y en qué liga (categoría + nivel) juega cada uno.
class SeccionEquipos extends StatefulWidget {
  const SeccionEquipos({super.key});

  @override
  State<SeccionEquipos> createState() => _SeccionEquiposState();
}

class _SeccionEquiposState extends State<SeccionEquipos> {
  String _buscar = '';

  Future<void> _editar([Equipo? e]) async {
    final nombre = TextEditingController(text: e?.nombre ?? '');
    final localidad = TextEditingController(text: e?.localidad ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: MarbelColors.tarjeta,
        title: Text(e == null ? 'Nuevo equipo' : 'Editar equipo'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre del club')),
            const SizedBox(height: 10),
            TextField(controller: localidad, decoration: const InputDecoration(labelText: 'Localidad (ej.: Elche, Alicante)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('GUARDAR')),
        ],
      ),
    );
    if (ok != true || nombre.text.trim().isEmpty || !mounted) return;
    final fila = {'nombre': nombre.text.trim(), 'localidad': localidad.text.trim().isEmpty ? null : localidad.text.trim()};
    await ejecutar(context, () async {
      if (e == null) {
        await db.from('equipos').insert(fila);
      } else {
        await db.from('equipos').update(fila).eq('id', e.id);
      }
      await datos.recargar();
    }, ok: 'Equipo guardado');
  }

  Future<void> _escudo(Equipo e) async {
    await ejecutar(context, () async {
      final url = await subirImagen(context, 'escudos', _slug(e.nombre));
      if (url == null) return;
      await db.from('equipos').update({'escudo_url': url}).eq('id', e.id);
      await datos.recargar();
    }, ok: 'Escudo actualizado');
  }

  Future<void> _anadirALiga(Equipo e) async {
    final t = datos.torneo;
    if (t == null) {
      avisar(context, 'Primero crea un torneo en «Torneos».', error: true);
      return;
    }
    String? cat;
    String? nivel;
    String? grupo; // id de la liga elegida, o 'nuevo'
    List<Liga> grupos() => datos.ligas
        .where((l) => l.torneoId == t.id && l.categoriaId == cat && l.nivelId == nivel)
        .toList()
      ..sort((a, b) => (a.grupo ?? '').compareTo(b.grupo ?? ''));
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          backgroundColor: MarbelColors.tarjeta,
          title: Text('Inscribir a ${e.nombre}'),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Desplegable<String>(
                etiqueta: 'Categoría',
                valor: cat,
                opciones: [for (final x in datos.categorias) (x.id, x.nombre)],
                onCambio: (v) => set(() {
                  cat = v;
                  grupo = null;
                  if (datos.categoria(v)?.femenina ?? false) nivel = 'femenino';
                }),
              ),
              const SizedBox(height: 12),
              Desplegable<String>(
                etiqueta: 'Nivel',
                valor: nivel,
                opciones: [for (final n in Nivel.todos) (n.id, n.nombre)],
                onCambio: (v) => set(() {
                  nivel = v;
                  grupo = null;
                }),
              ),
              if (cat != null && nivel != null && grupos().isNotEmpty) ...[
                const SizedBox(height: 12),
                Desplegable<String>(
                  etiqueta: 'Grupo',
                  valor: grupo ?? grupos().first.id,
                  opciones: [
                    for (final g in grupos()) (g.id, g.grupo == null ? 'Grupo único (${datos.equiposDeLiga[g.id]?.length ?? 0} equipos)' : 'Grupo ${g.grupo} (${datos.equiposDeLiga[g.id]?.length ?? 0} equipos)'),
                    ('nuevo', grupos().length == 1 && grupos().first.grupo == null ? 'Dividir: crear grupo B' : 'Crear un grupo nuevo'),
                  ],
                  onCambio: (v) => set(() => grupo = v),
                ),
                if (grupo == 'nuevo' && grupos().length == 1 && grupos().first.grupo == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('La liga que ya existe pasará a ser el grupo A, y este equipo irá al grupo B.',
                        style: TextStyle(color: MarbelColors.medio, fontSize: 12)),
                  ),
              ],
              const SizedBox(height: 10),
              Text('En ${t.nombre}. Si la liga no existe, se crea.', style: const TextStyle(color: MarbelColors.apagado, fontSize: 12)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('INSCRIBIR')),
          ],
        ),
      ),
    );
    if (ok != true || cat == null || nivel == null || !mounted) return;
    final existentes = grupos();
    await ejecutar(context, () async {
      String? liga;
      if (grupo == 'nuevo') {
        liga = await db.rpc('nuevo_grupo', params: {'p_torneo': t.id, 'p_categoria': cat, 'p_nivel': nivel}) as String;
      } else {
        liga = grupo ?? existentes.firstOrNull?.id;
      }
      liga ??= (await db
          .from('ligas')
          .insert({'torneo_id': t.id, 'categoria_id': cat, 'nivel_id': nivel})
          .select('id')
          .single())['id'] as String;
      await db.from('liga_equipos').upsert({'liga_id': liga, 'equipo_id': e.id});
      await datos.recargar();
    }, ok: 'Inscrito');
  }

  @override
  Widget build(BuildContext context) {
    final t = datos.torneo;
    final lista = datos.equipos
        .where((e) => _buscar.isEmpty || e.nombre.toLowerCase().contains(_buscar) || (e.localidad ?? '').toLowerCase().contains(_buscar))
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        '${datos.equipos.length} equipos · Torneo actual: ${t?.nombre ?? '—'}. '
        'Un mismo club puede jugar en varias categorías: inscríbelo en cada liga.',
        style: const TextStyle(color: MarbelColors.apagado),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 300,
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar equipo o localidad'),
            onChanged: (v) => setState(() => _buscar = v.trim().toLowerCase()),
          ),
        ),
        BotonCian('Nuevo equipo', icono: Icons.add_rounded, onTap: () => _editar()),
      ]),
      const SizedBox(height: 16),
      for (final e in lista) ...[
        Tarjeta(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Escudo(e, tamano: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  if (e.localidad != null) Text(e.localidad!, style: const TextStyle(color: MarbelColors.apagado)),
                ]),
              ),
              PopupMenuButton<String>(
                color: MarbelColors.tarjeta,
                onSelected: (v) async {
                  switch (v) {
                    case 'editar':
                      await _editar(e);
                    case 'escudo':
                      await _escudo(e);
                    case 'borrar':
                      if (datos.partidos.any((p) => p.localId == e.id || p.visitanteId == e.id)) {
                        avisar(context, 'Tiene partidos en el calendario. Bórralos antes en «Calendario y sedes».', error: true);
                        return;
                      }
                      if (await confirmar(context, '¿Borrar ${e.nombre}?',
                              'Se quitará de todas las ligas. No se puede deshacer.',
                              boton: 'Borrar') &&
                          context.mounted) {
                        await ejecutar(context, () async {
                          await db.from('equipos').delete().eq('id', e.id);
                          await datos.recargar();
                        }, ok: 'Equipo borrado');
                      }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'editar', child: Text('Editar nombre y localidad')),
                  PopupMenuItem(value: 'escudo', child: Text('Subir escudo')),
                  PopupMenuItem(value: 'borrar', child: Text('Borrar equipo')),
                ],
              ),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              for (final l in datos.ligasDeEquipo(e.id))
                InputChip(
                  label: Text(datos.nombreLiga(l.id)),
                  backgroundColor: Nivel.de(l.nivelId).color.withValues(alpha: .18),
                  onDeleted: () async {
                    if (await confirmar(context, '¿Quitar de la liga?', '${e.nombre} dejará de estar en ${datos.nombreLiga(l.id)}.',
                            boton: 'Quitar') &&
                        context.mounted) {
                      await ejecutar(context, () async {
                        await db.from('liga_equipos').delete().eq('liga_id', l.id).eq('equipo_id', e.id);
                        await datos.recargar();
                      });
                    }
                  },
                ),
              TextButton.icon(
                onPressed: () => _anadirALiga(e),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Inscribir en una liga'),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
      ],
    ]);
  }
}
