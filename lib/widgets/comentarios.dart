import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/datos.dart';
import '../data/modelos.dart';
import '../data/sesion.dart';
import '../theme/app_theme.dart';
import 'comunes.dart';
import 'cuenta.dart';

String _error(Object e) => e is PostgrestException ? e.message : mensajeError(e);

/// Reacciones que se pueden poner a un comentario.
const reaccionesPosibles = ['👏', '⚽', '❤️', '😂'];

/// Comentarios de la página del torneo ([partidoId] null) o de un partido.
///
/// Leer: todo el mundo. Escribir, responder y reaccionar: solo con cuenta y
/// alias (cada comentario queda registrado con su autor real). En público
/// solo se ve el alias. Se actualizan en directo.
class Comentarios extends StatefulWidget {
  const Comentarios({super.key, this.torneoId, this.partidoId});
  final String? torneoId;
  final String? partidoId;

  @override
  State<Comentarios> createState() => _ComentariosState();
}

class _ComentariosState extends State<Comentarios> {
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  List<Comentario> _lista = [];
  bool _cargando = true;
  String? _error2;
  String? _usuario; // para volver a escuchar al entrar o salir (cambia lo que se ve)
  final _texto = TextEditingController();
  final _respuesta = TextEditingController();
  String? _respondiendo; // id del comentario principal al que se responde
  bool _enviando = false;
  Timer? _refresco;

  /// Mis reacciones: "idComentario|emoji"
  Set<String> _mias = {};

  /// Cambios hechos aquí que aún no han llegado en directo: id -> recuento
  final Map<String, Map<String, int>> _recuentoLocal = {};

  @override
  void initState() {
    super.initState();
    _usuario = sesion.usuario?.id;
    sesion.addListener(_alCambiarSesion);
    _texto.addListener(() => setState(() {}));
    _respuesta.addListener(() => setState(() {}));
    _escuchar();
    // Un comentario que se oculta o se borra deja de llegar en directo a los demás
    // (ya no pueden verlo), así que cada minuto se vuelve a pedir la lista.
    _refresco = Timer.periodic(const Duration(seconds: 60), (_) => _escuchar());
  }

  void _alCambiarSesion() {
    if (sesion.usuario?.id != _usuario) {
      _usuario = sesion.usuario?.id;
      _mias = {};
      _escuchar();
    }
    if (mounted) setState(() {});
  }

  void _escuchar() {
    _sub?.cancel();
    final base = db.from('comentarios').stream(primaryKey: ['id']);
    final consulta = widget.partidoId != null
        ? base.eq('partido_id', widget.partidoId!)
        : base.eq('torneo_id', widget.torneoId ?? '00000000-0000-0000-0000-000000000000');
    _sub = consulta.order('creado', ascending: false).limit(300).listen((filas) {
      if (!mounted) return;
      setState(() {
        _lista = filas
            .map(Comentario.fromMap)
            .where((c) => widget.partidoId != null || c.partidoId == null)
            .toList();
        _recuentoLocal.clear();
        _cargando = false;
        _error2 = null;
      });
    }, onError: (Object e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error2 = 'No se han podido cargar los comentarios.';
      });
    });
    _cargarMias();
  }

  Future<void> _cargarMias() async {
    final yo = sesion.usuario?.id;
    if (yo == null) return;
    try {
      final filas = await db.from('reacciones').select('comentario_id, emoji').eq('usuario_id', yo).limit(2000);
      if (!mounted) return;
      setState(() => _mias = {for (final f in filas) '${f['comentario_id']}|${f['emoji']}'});
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    _refresco?.cancel();
    sesion.removeListener(_alCambiarSesion);
    _texto.dispose();
    _respuesta.dispose();
    super.dispose();
  }

  bool get _modera => sesion.tiene(Rol.admin) || sesion.tiene(Rol.comunicacion);

  /// Antes de escribir o reaccionar: hace falta cuenta y un alias válido.
  Future<bool> _puedoParticipar() async {
    if (!sesion.conectado) {
      await _pedirCuenta();
      return false;
    }
    if (sesion.perfil?.puedeParticipar ?? false) return true;
    await sesion.recargarPerfil();
    if (sesion.perfil?.puedeParticipar ?? false) return true;
    if (!mounted) return false;
    return dialogoAlias(context);
  }

  Future<void> _enviar({String? respuestaA}) async {
    final ctrl = respuestaA == null ? _texto : _respuesta;
    final t = ctrl.text.trim();
    if (t.length < 2 || _enviando) return;
    if (!await _puedoParticipar()) return;
    setState(() => _enviando = true);
    try {
      final r = await db.rpc('comentar', params: {
        'p_texto': t,
        'p_partido': widget.partidoId,
        'p_respuesta_a': respuestaA,
      });
      ctrl.clear();
      if (respuestaA != null) _respondiendo = null;
      if (mounted && r is Map && r['estado'] == 'pendiente') {
        avisar(context, 'Tu comentario lo revisará la organización antes de publicarse.');
      }
    } catch (e) {
      if (mounted) avisar(context, _error(e), error: true);
    }
    if (mounted) setState(() => _enviando = false);
  }

  Future<void> _reaccionar(Comentario c, String emoji) async {
    if (!await _puedoParticipar()) return;
    final clave = '${c.id}|$emoji';
    final quitar = _mias.contains(clave);
    // Se ve al momento; el recuento real llega en directo.
    setState(() {
      quitar ? _mias.remove(clave) : _mias.add(clave);
      final r = Map<String, int>.from(_recuentoLocal[c.id] ?? c.reacciones);
      final n = (r[emoji] ?? 0) + (quitar ? -1 : 1);
      r[emoji] = n < 0 ? 0 : n;
      _recuentoLocal[c.id] = r;
    });
    try {
      await db.rpc('reaccionar', params: {'p_id': c.id, 'p_emoji': emoji});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        quitar ? _mias.add(clave) : _mias.remove(clave);
        _recuentoLocal.remove(c.id);
      });
      avisar(context, _error(e), error: true);
    }
  }

  Future<void> _accion(Comentario c, String accion) async {
    try {
      switch (accion) {
        case 'responder':
          if (!await _puedoParticipar()) return;
          setState(() {
            _respondiendo = c.respuestaA ?? c.id;
            if (c.respuestaA != null && _respuesta.text.isEmpty) _respuesta.text = '@${c.autor} ';
          });
          return;
        case 'denunciar':
          await db.rpc('denunciar', params: {'p_id': c.id});
          if (mounted) avisar(context, 'Gracias. La organización lo revisará.');
        case 'borrar':
          await db.rpc('borrar_comentario', params: {'p_id': c.id});
        case 'ocultar':
          await db.rpc('moderar_comentario', params: {'p_id': c.id, 'p_estado': 'oculto'});
        case 'publicar':
          await db.rpc('moderar_comentario', params: {'p_id': c.id, 'p_estado': 'publicado'});
        case 'autor':
          if (mounted) await verAutor(context, c);
          return;
        case 'vetar':
          if (c.usuarioId == null) return;
          if (!mounted ||
              !await confirmarAccion(context, '¿Vetar el alias «${c.autor}»?',
                  'Se verá como «Alias en revisión» y la persona tendrá 24 horas para cambiarlo. Si no lo cambia, '
                      'no podrá jugar a La Porra ni comentar. Avísale desde Panel → Comentarios → Alias.',
                  boton: 'Vetar alias')) {
            return;
          }
          await db.rpc('vetar_alias', params: {'p_usuario': c.usuarioId, 'p_vetar': true});
          if (mounted) avisar(context, 'Alias vetado. Avísale desde Panel → Comentarios → Alias.');
        case 'bloquear':
          if (c.usuarioId == null) return;
          await db.rpc('bloquear_comentarios', params: {'p_usuario': c.usuarioId, 'p_bloquear': true});
          if (mounted) avisar(context, '${c.autor} ya no puede comentar. Puedes desbloquearlo en el panel.');
      }
      _escuchar();
    } catch (e) {
      if (mounted) avisar(context, _error(e), error: true);
    }
  }

  Future<void> _pedirCuenta() async {
    var registro = false;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          backgroundColor: MarbelColors.tarjeta,
          title: Text(registro ? 'Crear cuenta' : 'Entrar para comentar'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: registro
                  ? FormularioRegistro(alEntrar: () => Navigator.pop(c), alTenerCuenta: () => set(() => registro = false))
                  : FormularioEntrar(alEntrar: () => Navigator.pop(c), alCrearCuenta: () => set(() => registro = true)),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cerrar'))],
        ),
      ),
    );
  }

  bool _visible(Comentario c, String? yo) =>
      c.estado == 'publicado' ||
      (c.estado == 'pendiente' && ((yo != null && c.usuarioId == yo) || _modera));

  Widget _campo(TextEditingController ctrl, {required String pista, String? respuestaA, bool autofoco = false}) {
    final listo = ctrl.text.trim().length >= 2 && !_enviando;
    return TextField(
      controller: ctrl,
      autofocus: autofoco,
      maxLength: 300,
      minLines: 1,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: pista,
        isDense: respuestaA != null,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: 'Enviar',
          onPressed: listo ? () => _enviar(respuestaA: respuestaA) : null,
          icon: _enviando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_rounded, color: MarbelColors.cian),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final yo = sesion.usuario?.id;
    final p = sesion.perfil;
    final visibles = _lista.where((c) => _visible(c, yo)).toList();
    final principales = visibles.where((c) => c.respuestaA == null).toList();
    final respuestas = <String, List<Comentario>>{};
    for (final c in visibles.reversed) {
      if (c.respuestaA != null) (respuestas[c.respuestaA!] ??= []).add(c);
    }

    const aviso = Text(avisoModeracion, style: TextStyle(color: MarbelColors.apagado, fontSize: 12, height: 1.4));

    Widget escribir;
    if (!sesion.conectado) {
      escribir = Tarjeta(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.lock_outline_rounded, color: MarbelColors.cian),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Para comentar necesitas una cuenta (es la misma de La Porra). En público solo se ve tu alias.',
                  style: TextStyle(color: MarbelColors.texto2)),
            ),
            const SizedBox(width: 8),
            BotonCian('Entrar', onTap: _pedirCuenta),
          ]),
          const SizedBox(height: 10),
          aviso,
        ]),
      );
    } else if (p?.comentariosBloqueado ?? false) {
      escribir = const Tarjeta(
        padding: EdgeInsets.all(16),
        child: Text('Tu cuenta no puede comentar. Si crees que es un error, habla con la organización.',
            style: TextStyle(color: MarbelColors.texto2)),
      );
    } else if (!(p?.puedeParticipar ?? false)) {
      escribir = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
        AvisoAlias(margen: EdgeInsets.zero),
        SizedBox(height: 8),
        aviso,
      ]);
    } else {
      final perfil = p!;
      escribir = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (perfil.aliasVetado) const AvisoAlias(),
        _campo(_texto, pista: widget.partidoId != null ? 'Comenta el partido…' : 'Escribe un comentario…'),
        Text('Comentas como «${perfil.aliasVisible}». Sé respetuoso: aquí también hay niños y niñas. '
            'Cada comentario queda registrado con su autor.',
            style: const TextStyle(color: MarbelColors.apagado, fontSize: 12)),
        const SizedBox(height: 4),
        aviso,
      ]);
    }

    Widget fila(Comentario c, {bool respuesta = false}) => _FilaComentario(
          c: c,
          reacciones: _recuentoLocal[c.id] ?? c.reacciones,
          mias: {for (final e in reaccionesPosibles) if (_mias.contains('${c.id}|$e')) e},
          respuesta: respuesta,
          mio: c.usuarioId != null && c.usuarioId == yo,
          conectado: sesion.conectado,
          modera: _modera,
          onAccion: (a) => _accion(c, a),
          onReaccion: (e) => _reaccionar(c, e),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      escribir,
      const SizedBox(height: 16),
      if (_cargando)
        const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
      else if (_error2 != null)
        Text(_error2!, style: const TextStyle(color: MarbelColors.apagado))
      else if (principales.isEmpty)
        Text(widget.partidoId != null ? 'Nadie ha comentado este partido todavía. ¡Sé el primero!' : 'Todavía no hay comentarios. ¡Estrena tú el muro!',
            style: const TextStyle(color: MarbelColors.apagado))
      else
        for (final c in principales) ...[
          fila(c),
          if ((respuestas[c.id] ?? const []).isNotEmpty || _respondiendo == c.id)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 8),
              child: Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: const BoxDecoration(border: Border(left: BorderSide(color: MarbelColors.borde, width: 2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final r in respuestas[c.id] ?? const <Comentario>[]) ...[fila(r, respuesta: true), const SizedBox(height: 8)],
                  if (_respondiendo == c.id)
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: _campo(_respuesta, pista: 'Responde a ${c.autor}…', respuestaA: c.id, autofoco: true)),
                      IconButton(
                        tooltip: 'Cancelar',
                        onPressed: () => setState(() {
                          _respondiendo = null;
                          _respuesta.clear();
                        }),
                        icon: const Icon(Icons.close_rounded, color: MarbelColors.apagado),
                      ),
                    ]),
                ]),
              ),
            ),
          const SizedBox(height: 12),
        ],
    ]);
  }
}

class _FilaComentario extends StatelessWidget {
  const _FilaComentario({
    required this.c,
    required this.reacciones,
    required this.mias,
    required this.respuesta,
    required this.mio,
    required this.conectado,
    required this.modera,
    required this.onAccion,
    required this.onReaccion,
  });
  final Comentario c;
  final Map<String, int> reacciones;
  final Set<String> mias;
  final bool respuesta;
  final bool mio;
  final bool conectado;
  final bool modera;
  final ValueChanged<String> onAccion;
  final ValueChanged<String> onReaccion;

  @override
  Widget build(BuildContext context) {
    final pendiente = c.estado == 'pendiente';
    final publicado = c.estado == 'publicado';
    return Tarjeta(
      padding: EdgeInsets.fromLTRB(respuesta ? 12 : 14, respuesta ? 10 : 12, 4, 8),
      color: respuesta ? MarbelColors.fondoAlto : MarbelColors.tarjeta,
      radio: respuesta ? 14 : 20,
      borde: pendiente ? MarbelColors.medio : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: respuesta ? 14 : 18,
          backgroundColor: mio ? MarbelColors.cian : MarbelColors.azul,
          child: Text(c.iniciales,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: respuesta ? 11 : 13, color: mio ? MarbelColors.fondo : MarbelColors.blanco)),
        ),
        SizedBox(width: respuesta ? 10 : 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(c.autor,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: c.autor == 'Alias en revisión' ? MarbelColors.apagado : null,
                      fontStyle: c.autor == 'Alias en revisión' ? FontStyle.italic : null)),
              Text('· ${cuando(c.creado)}', style: const TextStyle(color: MarbelColors.apagado, fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            Text(c.texto, style: const TextStyle(height: 1.4)),
            if (pendiente) ...[
              const SizedBox(height: 6),
              Text(
                modera ? 'Pendiente de revisar · ${c.motivo ?? ''}' : 'Pendiente de revisión: solo lo ves tú hasta que la organización lo apruebe.',
                style: const TextStyle(color: MarbelColors.medio, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
            if (publicado) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final e in reaccionesPosibles) _Reaccion(emoji: e, n: reacciones[e] ?? 0, mia: mias.contains(e), onTap: () => onReaccion(e)),
                TextButton.icon(
                  onPressed: () => onAccion('responder'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: MarbelColors.cian,
                  ),
                  icon: const Icon(Icons.reply_rounded, size: 18),
                  label: const Text('Responder', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ]),
            ],
          ]),
        ),
        if (conectado)
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            color: MarbelColors.tarjeta,
            icon: const Icon(Icons.more_vert_rounded, color: MarbelColors.apagado),
            onSelected: onAccion,
            itemBuilder: (_) => [
              if (!mio) const PopupMenuItem(value: 'denunciar', child: Text('Denunciar')),
              if (mio) const PopupMenuItem(value: 'borrar', child: Text('Borrar mi comentario')),
              if (modera) ...[
                if (pendiente) const PopupMenuItem(value: 'publicar', child: Text('Aprobar y publicar')),
                const PopupMenuItem(value: 'ocultar', child: Text('Ocultar')),
                const PopupMenuItem(value: 'autor', child: Text('Ver quién lo ha escrito')),
                if (!mio && c.autor != 'Alias en revisión') const PopupMenuItem(value: 'vetar', child: Text('Vetar su alias')),
                if (!mio) const PopupMenuItem(value: 'bloquear', child: Text('Bloquear a esta persona')),
              ],
            ],
          ),
      ]),
    );
  }
}

class _Reaccion extends StatelessWidget {
  const _Reaccion({required this.emoji, required this.n, required this.mia, required this.onTap});
  final String emoji;
  final int n;
  final bool mia;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$emoji, $n',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: mia ? MarbelColors.cian.withValues(alpha: .18) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: mia ? MarbelColors.cian : MarbelColors.borde),
          ),
          child: Opacity(
            opacity: n == 0 && !mia ? .55 : 1,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              if (n > 0) ...[
                const SizedBox(width: 4),
                Text('$n', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: mia ? MarbelColors.cian : MarbelColors.texto2)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Confirmación sencilla (sí / no).
Future<bool> confirmarAccion(BuildContext context, String titulo, String texto, {required String boton}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: MarbelColors.tarjeta,
      title: Text(titulo),
      content: Text(texto, style: const TextStyle(height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(boton)),
      ],
    ),
  );
  return r ?? false;
}

/// Personal: nombre completo y email de quien escribió un comentario.
Future<void> verAutor(BuildContext context, Comentario c) async {
  Map<String, dynamic>? a;
  try {
    a = await db.from('comentarios_autor').select().eq('comentario_id', c.id).maybeSingle();
  } catch (e) {
    if (context.mounted) avisar(context, _error(e), error: true);
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: MarbelColors.tarjeta,
      title: const Text('Quién lo ha escrito'),
      content: a == null
          ? const Text('No hay datos del autor.')
          : SelectableText(
              'Alias: ${a['alias'] ?? '—'}\n'
              '${a['nombre']} ${a['apellidos']}\n${a['email'] ?? 'sin email'}\n'
              '${datos.nombreEquipo(a['equipo_id'] as String?, siNo: 'Sin equipo')}\n\n'
              'Escrito el ${diaCorto(c.creado)} a las ${hhmm(c.creado)}.\n'
              'Estos datos solo los ve la organización.',
              style: const TextStyle(height: 1.5),
            ),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cerrar'))],
    ),
  );
}
