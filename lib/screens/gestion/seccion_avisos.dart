import 'package:flutter/material.dart';

import '../../data/datos.dart';
import '../../data/modelos.dart';
import '../../data/sesion.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';
import 'seccion_equipos.dart' show subirImagen;
import 'utiles.dart';

/// Publicar avisos. Comunicación y administración: cualquier ámbito.
/// Mesa de sede: solo avisos de su sede o de un equipo.
class SeccionAvisos extends StatefulWidget {
  const SeccionAvisos({super.key});

  @override
  State<SeccionAvisos> createState() => _SeccionAvisosState();
}

class _SeccionAvisosState extends State<SeccionAvisos> {
  final _texto = TextEditingController();
  late String _ambito = _mesa ? 'sede' : 'todos';
  String? _ref;
  bool _fijar = false;
  bool _enviando = false;
  final List<String> _imagenes = [];
  bool _subiendo = false;

  /// Mesa de sede sin Comunicación: solo avisos de su sede o de un equipo.
  bool get _mesa => sesion.tiene(Rol.mesa) && !sesion.tiene(Rol.comunicacion) && !sesion.tiene(Rol.admin);

  @override
  void initState() {
    super.initState();
    _texto.addListener(() => setState(() {}));
    if (_mesa) _ref = datos.sede(sesion.perfil?.sedeId)?.nombre;
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  List<(String, String)> get _opcionesRef => switch (_ambito) {
        'sede' => _mesa
            ? [if (_ref != null) (_ref!, _ref!)]
            : [for (final s in datos.sedes) (s.nombre, s.nombre)],
        'categoria' => [for (final c in datos.categorias) (c.nombre, c.nombre)],
        'equipo' => [for (final e in datos.equipos) (e.nombre, e.nombre)],
        _ => const [],
      };

  Future<void> _anadirImagen() async {
    if (_imagenes.length >= 4) return;
    setState(() => _subiendo = true);
    try {
      final url = await subirImagen(context, 'avisos', 'aviso');
      if (url != null && mounted) setState(() => _imagenes.add(url));
    } catch (e) {
      if (mounted) avisar(context, 'No se ha podido subir: ${mensajeError(e)}', error: true);
    }
    if (mounted) setState(() => _subiendo = false);
  }

  /// Borra del almacenamiento las imágenes que ya no se usan (si falla, no pasa nada).
  Future<void> _borrarArchivos(List<String> urls) async {
    final rutas = [
      for (final u in urls)
        if (u.contains('/avisos/')) Uri.decodeComponent(u.split('/avisos/').last.split('?').first),
    ];
    if (rutas.isEmpty) return;
    try {
      await db.storage.from('avisos').remove(rutas);
    } catch (_) {}
  }

  Future<void> _publicar() async {
    final t = _texto.text.trim();
    if (t.isEmpty) {
      avisar(context, 'Escribe el aviso', error: true);
      return;
    }
    if (_ambito != 'todos' && _ref == null) {
      avisar(context, 'Elige a quién va dirigido', error: true);
      return;
    }
    setState(() => _enviando = true);
    final ok = await ejecutar(context, () async {
      await db.from('avisos').insert({
        'texto': t,
        'fijado': _mesa ? false : _fijar,
        'ambito': _ambito,
        'ambito_ref': _ambito == 'todos' ? null : _ref,
        'torneo_id': datos.torneo?.id,
        'imagenes': _imagenes,
      });
      await datos.recargar(); // se ve en la lista al momento
    }, ok: 'Aviso publicado');
    if (!mounted) return;
    setState(() {
      _enviando = false;
      if (ok) {
        _texto.clear();
        _fijar = false;
        _imagenes.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ambitos = <(String, String)>[
      if (!_mesa) ('todos', 'Todo el mundo'),
      ('sede', _mesa ? 'Mi sede' : 'Una sede'),
      if (!_mesa) ('categoria', 'Una categoría'),
      ('equipo', 'Seguidores de un equipo'),
    ];
    final avisos = [...datos.avisos]..sort((a, b) => b.creado.compareTo(a.creado));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Tarjeta(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SubTitulo('Nuevo aviso'),
          TextField(
            controller: _texto,
            maxLength: 500,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Ej.: El partido de las 11:00 en Rafal empieza 10 minutos tarde.',
              border: OutlineInputBorder(),
            ),
          ),
          Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final u in _imagenes)
              Stack(clipBehavior: Clip.none, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    color: MarbelColors.fondoAlto,
                    width: 88,
                    height: 88,
                    child: Image.network(u, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: -10,
                  right: -10,
                  child: IconButton.filled(
                    tooltip: 'Quitar imagen',
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFFFF7A85)),
                    onPressed: () {
                      setState(() => _imagenes.remove(u));
                      _borrarArchivos([u]);
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ]),
            if (_imagenes.length < 4)
              OutlinedButton.icon(
                onPressed: _subiendo ? null : _anadirImagen,
                icon: _subiendo
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_photo_alternate_rounded),
                label: Text(_imagenes.isEmpty ? 'Añadir imagen (opcional)' : 'Añadir otra (${_imagenes.length}/4)'),
              ),
          ]),
          const SizedBox(height: 4),
          const Text('Hasta 4 imágenes (escudos, carteles…), de menos de 5 MB. Se ven debajo del texto y se pueden ampliar.',
              style: TextStyle(color: MarbelColors.apagado, fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
              width: 260,
              child: Desplegable<String>(
                etiqueta: 'Para',
                valor: _ambito,
                opciones: ambitos,
                onCambio: (v) => setState(() {
                  _ambito = v ?? 'todos';
                  _ref = _mesa && _ambito == 'sede' ? datos.sede(sesion.perfil?.sedeId)?.nombre : null;
                }),
              ),
            ),
            if (_ambito != 'todos')
              SizedBox(
                width: 300,
                child: Desplegable<String>(
                  etiqueta: switch (_ambito) { 'sede' => 'Sede', 'categoria' => 'Categoría', _ => 'Equipo' },
                  valor: _ref,
                  opciones: _opcionesRef,
                  onCambio: (v) => setState(() => _ref = v),
                ),
              ),
          ]),
          if (!_mesa)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _fijar,
              onChanged: (v) => setState(() => _fijar = v),
              title: const Text('Fijar arriba en Inicio'),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: BotonCian('Publicar aviso', icono: Icons.campaign_rounded, onTap: _publicar, cargando: _enviando),
          ),
          const SizedBox(height: 10),
          const Text(
            'El aviso aparece al momento en Inicio y en «Avisos» de la web y la app. '
            'Los dirigidos a una sede, categoría o equipo salen en «Para ti» a quien sigue ese equipo.',
            style: TextStyle(color: MarbelColors.apagado, fontSize: 13),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Tarjeta(
        color: MarbelColors.fondoAlto,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('AVISOS AUTOMÁTICOS', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
          SizedBox(height: 6),
          Text(
            '• Partido de tu equipo a punto de empezar, gol, resultado final y cambios de campo u hora se muestran solos en «Para ti» a quien sigue al equipo.\n'
            '• Si un partido va con retraso, en «Partidos y resultados» aparece «Retraso detectado» con el botón «Avisar a seguidores».\n'
            '• Las notificaciones al móvil (con la app cerrada) llevan solo el texto; las imágenes se ven al abrir el aviso.',
            style: TextStyle(color: MarbelColors.texto2, height: 1.45),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      SubTitulo('Publicados (${avisos.length})'),
      if (avisos.isEmpty) const EstadoVacio('Todavía no hay avisos.'),
      for (final a in avisos) ...[
        Tarjeta(
          padding: const EdgeInsets.all(14),
          borde: a.fijado ? MarbelColors.cian : null,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (a.fijado) const Pastilla('Fijado', fondo: MarbelColors.cian, color: MarbelColors.fondo, tamano: 11),
                  if (a.automatico) const Pastilla('Automático', fondo: Color(0xFF3A2A00), color: MarbelColors.medio, tamano: 11),
                  Pastilla(a.ambito == 'todos' ? 'Todos' : (a.ambitoRef ?? a.ambito),
                      fondo: const Color(0xFF1E2672), color: MarbelColors.texto2, tamano: 11),
                  Text(cuando(a.creado), style: const TextStyle(color: MarbelColors.apagado, fontSize: 12)),
                ]),
                const SizedBox(height: 6),
                Text(a.texto, style: const TextStyle(height: 1.4)),
                if (a.imagenes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ImagenesAviso(a.imagenes, alto: 70),
                ],
              ]),
            ),
            if (!_mesa) ...[
              IconButton(
                tooltip: a.fijado ? 'Desfijar' : 'Fijar',
                onPressed: () => ejecutar(context, () async {
                  await db.from('avisos').update({'fijado': !a.fijado}).eq('id', a.id);
                  await datos.recargar();
                }),
                icon: Icon(a.fijado ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: MarbelColors.cian),
              ),
              IconButton(
                tooltip: 'Borrar',
                onPressed: () async {
                  if (await confirmar(context, '¿Borrar aviso?', 'Desaparecerá de la web y la app.', boton: 'Borrar') && context.mounted) {
                    await ejecutar(context, () async {
                      await db.from('avisos').delete().eq('id', a.id);
                      await _borrarArchivos(a.imagenes);
                      await datos.recargar();
                    }, ok: 'Aviso borrado');
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF7A85)),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 8),
      ],
    ]);
  }
}
