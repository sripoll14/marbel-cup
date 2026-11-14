import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datos.dart';
import '../../data/modelos.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';
import 'utiles.dart';

/// Opiniones de «Déjanos tu opinión». Solo administración.
class SeccionOpiniones extends StatefulWidget {
  const SeccionOpiniones({super.key});

  @override
  State<SeccionOpiniones> createState() => _SeccionOpinionesState();
}

class _SeccionOpinionesState extends State<SeccionOpiniones> {
  int _vista = 0; // 0 nuevas · 1 archivadas · 2 bloqueados
  List<Map<String, dynamic>>? _filas;
  List<Map<String, dynamic>> _bloqueados = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final filas = await db
          .from('comentarios')
          .select('*, comentarios_autor(alias, nombre, apellidos, email, equipo_id)')
          .order('creado', ascending: false)
          .limit(500);
      final bloq = await db.rpc('bloqueados_comentarios');
      if (!mounted) return;
      setState(() {
        _filas = List<Map<String, dynamic>>.from(filas);
        _bloqueados = List<Map<String, dynamic>>.from(bloq as List);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is PostgrestException ? e.message : '$e');
    }
  }

  Future<void> _rpc(String fn, Map<String, dynamic> params, {String? ok}) async {
    await ejecutar(context, () async {
      await db.rpc(fn, params: params);
      await _cargar();
    }, ok: ok);
  }

  @override
  Widget build(BuildContext context) {
    final todas = _filas ?? const <Map<String, dynamic>>[];
    final nuevas = todas.where((f) => f['estado'] == 'publicado' || f['estado'] == 'pendiente').toList();
    final archivadas = todas.where((f) => f['estado'] == 'oculto' || f['estado'] == 'borrado').toList();
    final lista = _vista == 0 ? nuevas : archivadas;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text(
        'Lo que la gente escribe en «Déjanos tu opinión» (página del torneo). No se publica: solo lo ve administración. '
        'Archiva las que ya hayas leído o atendido.',
        style: TextStyle(color: MarbelColors.apagado),
      ),
      const SizedBox(height: 12),
      FilaChips(children: [
        ChipFiltro(texto: 'Nuevas (${nuevas.length})', elegido: _vista == 0, onTap: () => setState(() => _vista = 0)),
        ChipFiltro(texto: 'Archivadas (${archivadas.length})', elegido: _vista == 1, onTap: () => setState(() => _vista = 1)),
        ChipFiltro(texto: 'Bloqueados (${_bloqueados.length})', elegido: _vista == 2, onTap: () => setState(() => _vista = 2)),
      ]),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Actualizar')),
      ),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: Color(0xFFFF7A85)))
      else if (_filas == null)
        const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
      else if (_vista == 2)
        ..._vistaBloqueados()
      else if (lista.isEmpty)
        EstadoVacio(_vista == 0 ? 'No hay opiniones nuevas.' : 'No hay opiniones archivadas.')
      else
        for (final f in lista) ...[_tarjeta(f), const SizedBox(height: 10)],
    ]);
  }

  Widget _tarjeta(Map<String, dynamic> f) {
    final c = Comentario.fromMap(f);
    final a = f['comentarios_autor'] as Map<String, dynamic>?;
    final nombre = a == null ? c.autor : '${a['nombre']} ${a['apellidos']}'.trim();
    final email = a?['email'] as String?;
    final equipo = datos.nombreEquipo(a?['equipo_id'] as String?, siNo: 'Sin equipo');
    final bloqueado = _bloqueados.any((b) => b['id'] == c.usuarioId);
    final nueva = c.estado == 'publicado' || c.estado == 'pendiente';
    return Tarjeta(
      padding: const EdgeInsets.all(14),
      borde: c.motivo != null && nueva ? MarbelColors.medio : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(nombre, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text('· ${diaCorto(c.creado)} ${hhmm(c.creado)}', style: const TextStyle(color: MarbelColors.apagado, fontSize: 12)),
          if (c.estado == 'borrado')
            const Pastilla('Borrada por su autor', fondo: Color(0xFF2A2F55), color: MarbelColors.apagado, tamano: 11),
          if (c.partidoId != null || c.respuestaA != null)
            const Pastilla('Comentario antiguo', fondo: Color(0xFF2A2F55), color: MarbelColors.apagado, tamano: 11),
        ]),
        const SizedBox(height: 2),
        SelectableText(
          [email ?? 'sin email', equipo, if (a?['alias'] != null) 'alias «${a!['alias']}»'].join(' · '),
          style: const TextStyle(color: MarbelColors.apagado, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        SelectableText(c.texto, style: const TextStyle(height: 1.45, fontSize: 15)),
        if (c.motivo != null && nueva) ...[
          const SizedBox(height: 6),
          Text(c.motivo!, style: const TextStyle(color: MarbelColors.medio, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (nueva)
            TextButton.icon(
              onPressed: () => _rpc('moderar_comentario', {'p_id': c.id, 'p_estado': 'oculto'}, ok: 'Archivada'),
              icon: const Icon(Icons.archive_outlined, size: 18),
              label: const Text('Archivar'),
            )
          else if (c.estado == 'oculto')
            TextButton.icon(
              onPressed: () => _rpc('moderar_comentario', {'p_id': c.id, 'p_estado': 'publicado'}, ok: 'Vuelve a «Nuevas»'),
              icon: const Icon(Icons.unarchive_outlined, size: 18),
              label: const Text('Pasar a nuevas'),
            ),
          if (email != null)
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: email));
                if (mounted) avisar(context, 'Email copiado');
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar email'),
            ),
          if (c.usuarioId != null && !bloqueado)
            TextButton.icon(
              onPressed: () async {
                if (!await confirmar(context, '¿Bloquear a $nombre?', 'No podrá enviar más opiniones hasta que la desbloquees.',
                    boton: 'Bloquear')) {
                  return;
                }
                if (mounted) await _rpc('bloquear_comentarios', {'p_usuario': c.usuarioId, 'p_bloquear': true}, ok: 'Bloqueado');
              },
              icon: const Icon(Icons.block_rounded, size: 18, color: Color(0xFFFF7A85)),
              label: const Text('Bloquear', style: TextStyle(color: Color(0xFFFF7A85))),
            ),
        ]),
      ]),
    );
  }

  List<Widget> _vistaBloqueados() {
    if (_bloqueados.isEmpty) return [const EstadoVacio('Nadie está bloqueado.')];
    return [
      for (final b in _bloqueados) ...[
        Tarjeta(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${b['nombre']} ${b['apellidos']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${b['email'] ?? ''}', style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
              ]),
            ),
            TextButton(
              onPressed: () => _rpc('bloquear_comentarios', {'p_usuario': b['id'], 'p_bloquear': false}, ok: 'Desbloqueado'),
              child: const Text('Desbloquear'),
            ),
          ]),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }
}
