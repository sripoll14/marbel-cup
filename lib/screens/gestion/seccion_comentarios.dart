import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datos.dart';
import '../../data/modelos.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';
import 'utiles.dart';

/// Moderación de comentarios (administración y comunicación).
class SeccionComentarios extends StatefulWidget {
  const SeccionComentarios({super.key});

  @override
  State<SeccionComentarios> createState() => _SeccionComentariosState();
}

class _SeccionComentariosState extends State<SeccionComentarios> {
  int _vista = 0; // 0 pendientes · 1 todos · 2 alias · 3 bloqueados · 4 filtro
  List<Map<String, dynamic>>? _filas;
  List<Map<String, dynamic>> _bloqueados = [];
  List<Map<String, dynamic>> _alias = [];
  String _buscar = '';
  List<String> _palabras = [];
  final _nueva = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nueva.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      var q = db.from('comentarios').select('*, comentarios_autor(alias, nombre, apellidos, email), denuncias(count)');
      if (_vista == 0) q = q.eq('estado', 'pendiente');
      final filas = await q.order('creado', ascending: false).limit(150);
      final bloq = await db.rpc('bloqueados_comentarios');
      final alias = await db.rpc('alias_usuarios');
      final pal = await db.from('palabras_filtradas').select().order('palabra', ascending: true);
      if (!mounted) return;
      setState(() {
        _filas = List<Map<String, dynamic>>.from(filas);
        _bloqueados = List<Map<String, dynamic>>.from(bloq as List);
        _alias = List<Map<String, dynamic>>.from(alias as List);
        _palabras = [for (final p in pal) p['palabra'] as String];
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

  String _donde(Map<String, dynamic> f) {
    final pid = f['partido_id'] as String?;
    if (pid == null) return 'Página del torneo';
    final p = datos.partidos.where((x) => x.id == pid).firstOrNull;
    if (p == null) return 'Partido';
    return 'Partido ${datos.nombreEquipo(p.localId)} – ${datos.nombreEquipo(p.visitanteId)}';
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _vista == 0 ? (_filas?.length ?? 0) : null;
    final vetados = _alias.where((a) => a['vetado_en'] != null).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text(
        'Los comentarios con palabras del filtro, o con 3 denuncias, quedan pendientes hasta que los revises. '
        'Nada se borra de verdad: lo oculto o borrado por su autor queda guardado con su autor como prueba. '
        'En público solo se ve el alias de cada persona; si uno es ofensivo, vétalo en «Alias».',
        style: TextStyle(color: MarbelColors.apagado),
      ),
      const SizedBox(height: 12),
      FilaChips(children: [
        ChipFiltro(texto: pendientes == null ? 'Pendientes' : 'Pendientes ($pendientes)', elegido: _vista == 0, onTap: () {
          setState(() => _vista = 0);
          _cargar();
        }),
        ChipFiltro(texto: 'Todos', elegido: _vista == 1, onTap: () {
          setState(() => _vista = 1);
          _cargar();
        }),
        ChipFiltro(texto: vetados == 0 ? 'Alias' : 'Alias ($vetados vetados)', elegido: _vista == 2, onTap: () => setState(() => _vista = 2)),
        ChipFiltro(texto: 'Bloqueados (${_bloqueados.length})', elegido: _vista == 3, onTap: () => setState(() => _vista = 3)),
        ChipFiltro(texto: 'Filtro de palabras', elegido: _vista == 4, onTap: () => setState(() => _vista = 4)),
      ]),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Actualizar')),
      ),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: Color(0xFFFF7A85)))
      else if (_filas == null)
        const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
      else if (_vista == 2)
        ..._vistaAlias()
      else if (_vista == 3)
        ..._vistaBloqueados()
      else if (_vista == 4)
        ..._vistaFiltro()
      else if (_filas!.isEmpty)
        EstadoVacio(_vista == 0 ? 'No hay nada pendiente de revisar.' : 'Todavía no hay comentarios.')
      else
        for (final f in _filas!) ...[_tarjeta(f), const SizedBox(height: 10)],
    ]);
  }

  Widget _tarjeta(Map<String, dynamic> f) {
    final c = Comentario.fromMap(f);
    final autor = f['comentarios_autor'] as Map<String, dynamic>?;
    final den = (f['denuncias'] as List?)?.firstOrNull;
    final nDen = den is Map ? (den['count'] as int? ?? 0) : 0;
    final (color, texto) = switch (c.estado) {
      'pendiente' => (MarbelColors.medio, 'Pendiente'),
      'oculto' => (const Color(0xFFFF7A85), 'Oculto'),
      'borrado' => (MarbelColors.apagado, 'Borrado por su autor'),
      _ => (MarbelColors.elite, 'Publicado'),
    };
    return Tarjeta(
      padding: const EdgeInsets.all(14),
      borde: c.estado == 'pendiente' ? MarbelColors.medio : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Pastilla(texto, fondo: color.withValues(alpha: .2), color: color, tamano: 11),
          Text(c.autor, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (c.respuestaA != null) const Text('· respuesta', style: TextStyle(color: MarbelColors.apagado, fontSize: 12)),
          Text('· ${diaCorto(c.creado)} ${hhmm(c.creado)} · ${_donde(f)}', style: const TextStyle(color: MarbelColors.apagado, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        Text(c.texto, style: const TextStyle(height: 1.4, fontSize: 15)),
        const SizedBox(height: 6),
        if (autor != null)
          SelectableText('Autor real: ${autor['nombre']} ${autor['apellidos']} · ${autor['email'] ?? 'sin email'}'
              '${autor['alias'] != null && autor['alias'] != c.autor ? ' · escribió como «${autor['alias']}»' : ''}',
              style: const TextStyle(color: MarbelColors.texto2, fontSize: 12.5)),
        if (c.motivo != null || nDen > 0)
          Text([if (c.motivo != null) c.motivo!, if (nDen > 0) '$nDen ${nDen == 1 ? 'denuncia' : 'denuncias'}'].join(' · '),
              style: const TextStyle(color: MarbelColors.medio, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (c.estado != 'publicado' && c.estado != 'borrado')
            TextButton.icon(
              onPressed: () => _rpc('moderar_comentario', {'p_id': c.id, 'p_estado': 'publicado'}, ok: 'Publicado'),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Aprobar'),
            ),
          if (c.estado == 'publicado' || c.estado == 'pendiente')
            TextButton.icon(
              onPressed: () => _rpc('moderar_comentario', {'p_id': c.id, 'p_estado': 'oculto'}, ok: 'Ocultado'),
              icon: const Icon(Icons.visibility_off_rounded, size: 18, color: Color(0xFFFF7A85)),
              label: const Text('Ocultar', style: TextStyle(color: Color(0xFFFF7A85))),
            ),
          if (c.usuarioId != null && c.autor != 'Alias en revisión')
            TextButton.icon(
              onPressed: () => _vetar(c.usuarioId!, c.autor),
              icon: const Icon(Icons.badge_outlined, size: 18),
              label: const Text('Vetar alias'),
            ),
          if (c.usuarioId != null && !_bloqueados.any((b) => b['id'] == c.usuarioId))
            TextButton.icon(
              onPressed: () async {
                if (!await confirmar(context, '¿Bloquear a ${c.autor}?', 'No podrá escribir más comentarios hasta que la desbloquees.',
                    boton: 'Bloquear')) {
                  return;
                }
                if (mounted) await _rpc('bloquear_comentarios', {'p_usuario': c.usuarioId, 'p_bloquear': true}, ok: 'Bloqueado');
              },
              icon: const Icon(Icons.block_rounded, size: 18),
              label: const Text('Bloquear autor'),
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
                Text('${b['nombre']} ${b['apellidos']}${b['alias'] == null ? '' : ' · ${b['alias']}'}', style: const TextStyle(fontWeight: FontWeight.w800)),
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

  Future<void> _vetar(String usuario, String alias) async {
    if (!await confirmar(
        context,
        '¿Vetar el alias «$alias»?',
        'En público se verá «Alias en revisión» y la persona tendrá 24 horas para cambiarlo. '
            'Si no lo cambia, no podrá jugar a La Porra ni comentar hasta que elija otro. '
            'Después, avísale con el botón «Enviar email».',
        boton: 'Vetar')) {
      return;
    }
    if (!mounted) return;
    await _rpc('vetar_alias', {'p_usuario': usuario, 'p_vetar': true}, ok: 'Alias vetado. Ahora avísale desde «Alias».');
  }

  static String _fecha(DateTime d) => '${diaCorto(d).toLowerCase()} a las ${hhmm(d)}';

  /// Mensaje para avisar a quien tiene el alias vetado.
  static String _mensaje(Map<String, dynamic> a) {
    final limite = DateTime.parse(a['limite'] as String).toLocal();
    return 'Hola, ${a['nombre']}:\n\n'
        'La organización de la Marbel Football Cup ha revisado tu alias «${a['alias']}» y no está permitido '
        'porque lo considera ofensivo o fuera de lugar.\n\n'
        'Tienes hasta el ${_fecha(limite)} para cambiarlo desde la app o la web (Más → Alias → Cambiar). '
        'Si no lo cambias, no podrás jugar a La Porra ni escribir comentarios hasta que elijas uno nuevo.\n\n'
        'Gracias por entenderlo.\n'
        'Organización de la Marbel Football Cup';
  }

  List<Widget> _vistaAlias() {
    final q = _buscar.trim().toLowerCase();
    final lista = _alias
        .where((a) =>
            q.isEmpty ||
            '${a['alias']} ${a['nombre']} ${a['apellidos']} ${a['email']}'.toLowerCase().contains(q))
        .toList();
    return [
      const Text(
        'Es lo que se ve en público (ranking de La Porra y comentarios). Si un alias es ofensivo, vétalo: '
        'se verá «Alias en revisión» y la persona tendrá 24 horas para cambiarlo. Pasado el plazo no podrá '
        'jugar a La Porra ni comentar hasta que elija otro (al cambiarlo se quita el veto solo). '
        'Después de vetar, avísale con «Enviar email» o copia el mensaje y mándaselo por WhatsApp.',
        style: TextStyle(color: MarbelColors.texto2, height: 1.4),
      ),
      const SizedBox(height: 12),
      TextField(
        decoration: const InputDecoration(
          hintText: 'Buscar por alias, nombre o email',
          prefixIcon: Icon(Icons.search_rounded),
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) => setState(() => _buscar = v),
      ),
      const SizedBox(height: 12),
      if (lista.isEmpty) const EstadoVacio('No hay ningún alias que coincida.'),
      for (final a in lista.take(200)) ...[_filaAlias(a), const SizedBox(height: 8)],
      if (lista.length > 200)
        const Text('Hay más: usa el buscador.', style: TextStyle(color: MarbelColors.apagado)),
    ];
  }

  Widget _filaAlias(Map<String, dynamic> a) {
    final vetado = a['vetado_en'] != null;
    final vencido = a['vencido'] == true;
    final limite = vetado ? DateTime.parse(a['limite'] as String).toLocal() : null;
    final email = a['email'] as String?;
    return Tarjeta(
      padding: const EdgeInsets.all(14),
      borde: vetado ? (vencido ? const Color(0xFFFF7A85) : MarbelColors.medio) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('${a['alias'] ?? 'Sin alias'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (vetado)
            Pastilla(vencido ? 'Plazo vencido · bloqueado' : 'Vetado · hasta el ${_fecha(limite!)}',
                fondo: (vencido ? const Color(0xFFFF7A85) : MarbelColors.medio).withValues(alpha: .2),
                color: vencido ? const Color(0xFFFF7A85) : MarbelColors.medio,
                tamano: 11),
        ]),
        const SizedBox(height: 2),
        SelectableText('${a['nombre']} ${a['apellidos']} · ${email ?? 'sin email'}',
            style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (!vetado)
            TextButton.icon(
              onPressed: () => _vetar(a['id'] as String, '${a['alias']}'),
              icon: const Icon(Icons.badge_outlined, size: 18, color: Color(0xFFFF7A85)),
              label: const Text('Vetar', style: TextStyle(color: Color(0xFFFF7A85))),
            )
          else ...[
            if (email != null)
              TextButton.icon(
                onPressed: () => abrir('mailto:$email?subject=${Uri.encodeComponent('Tu alias en la Marbel Cup')}'
                    '&body=${Uri.encodeComponent(_mensaje(a))}'),
                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                label: const Text('Enviar email'),
              ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _mensaje(a)));
                if (mounted) avisar(context, 'Mensaje copiado');
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar mensaje'),
            ),
            TextButton.icon(
              onPressed: () => _rpc('vetar_alias', {'p_usuario': a['id'], 'p_vetar': false}, ok: 'Veto quitado'),
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('Quitar veto'),
            ),
          ],
        ]),
      ]),
    );
  }

  List<Widget> _vistaFiltro() {
    return [
      const Text(
        'Si un comentario contiene alguna de estas palabras, no se publica hasta que lo revises; '
        'y nadie puede elegir un alias que las contenga. '
        'Escríbelas en minúscula y sin tildes. Con * al final vale todo lo que empiece así (gilipoll* pilla gilipollas); '
        'sin *, solo esa palabra exacta (así «cono» no pilla «conocer»).',
        style: TextStyle(color: MarbelColors.texto2, height: 1.4),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _nueva,
            decoration: const InputDecoration(hintText: 'Añadir palabra (ej.: tontaco*)', border: OutlineInputBorder()),
            onSubmitted: (_) => _anadirPalabra(),
          ),
        ),
        const SizedBox(width: 8),
        BotonCian('Añadir', onTap: _anadirPalabra),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final p in _palabras)
          InputChip(
            label: Text(p),
            onDeleted: () => ejecutar(context, () async {
              await db.from('palabras_filtradas').delete().eq('palabra', p);
              await _cargar();
            }),
          ),
      ]),
    ];
  }

  Future<void> _anadirPalabra() async {
    final p = _nueva.text.trim().toLowerCase();
    if (p.length < 2) return;
    await ejecutar(context, () async {
      await db.from('palabras_filtradas').upsert({'palabra': p}, ignoreDuplicates: true);
      _nueva.clear();
      await _cargar();
    }, ok: 'Añadida');
  }
}
