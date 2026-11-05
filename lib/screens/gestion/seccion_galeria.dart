import 'package:flutter/material.dart';

import '../../data/datos.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';
import 'seccion_equipos.dart' show subirImagen;
import 'utiles.dart';

/// Fotos de ediciones anteriores (Inicio y Galería).
class SeccionGaleria extends StatefulWidget {
  const SeccionGaleria({super.key});

  @override
  State<SeccionGaleria> createState() => _SeccionGaleriaState();
}

class _SeccionGaleriaState extends State<SeccionGaleria> {
  bool _subiendo = false;

  Future<void> _subir() async {
    final pie = TextEditingController();
    var vertical = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          backgroundColor: MarbelColors.tarjeta,
          title: const Text('Subir foto'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: pie, maxLength: 80, decoration: const InputDecoration(labelText: 'Pie de foto (opcional)')),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: vertical,
                onChanged: (v) => set(() => vertical = v ?? false),
                title: const Text('Es vertical'),
              ),
              const Text('Solo fotos con permiso de las familias. Máximo 5 MB.',
                  style: TextStyle(color: MarbelColors.apagado, fontSize: 12)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ELEGIR FOTO')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _subiendo = true);
    await ejecutar(context, () async {
      final url = await subirImagen(context, 'galeria', 'foto');
      if (url == null) return;
      final orden = datos.fotos.isEmpty ? 0 : datos.fotos.map((f) => f.orden).reduce((a, b) => a > b ? a : b) + 1;
      await db.from('fotos').insert({'url': url, 'pie': pie.text.trim(), 'vertical': vertical, 'orden': orden});
      await datos.recargar();
    });
    if (mounted) setState(() => _subiendo = false);
  }

  @override
  Widget build(BuildContext context) {
    final fotos = datos.fotos;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${fotos.length} fotos. Salen en el carrusel de Inicio y en Galería.', style: const TextStyle(color: MarbelColors.apagado)),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: BotonCian('Subir foto', icono: Icons.add_photo_alternate_rounded, onTap: _subir, cargando: _subiendo),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, c) {
        final columnas = (c.maxWidth / 220).floor().clamp(2, 6);
        return GridView.count(
          crossAxisCount: columnas,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (final f in fotos)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(fit: StackFit.expand, children: [
                  Imagen(f.url),
                  if (f.pie.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.all(6),
                        child: Text(f.pie, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      tooltip: 'Quitar',
                      onPressed: () async {
                        if (await confirmar(context, '¿Quitar foto?', 'Dejará de verse en la web y la app.', boton: 'Quitar') &&
                            context.mounted) {
                          await ejecutar(context, () async {
                            await db.from('fotos').delete().eq('id', f.id);
                            await datos.recargar();
                          }, ok: 'Foto quitada');
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    ),
                  ),
                ]),
              ),
          ],
        );
      }),
    ]);
  }
}
