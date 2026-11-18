import 'package:flutter/material.dart';

import '../../data/cola.dart';
import '../../data/datos.dart';
import '../../data/modelos.dart';
import '../../data/sesion.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';
import '../../widgets/partidos.dart';
import 'utiles.dart';

/// Resultados en directo. La mesa de sede solo ve (y puede cambiar) su sede.
class SeccionPartidos extends StatefulWidget {
  const SeccionPartidos({super.key});

  @override
  State<SeccionPartidos> createState() => _SeccionPartidosState();
}

class _SeccionPartidosState extends State<SeccionPartidos> {
  String? _sede; // null = todas (solo admin)
  int _dia = -1;

  @override
  Widget build(BuildContext context) {
    final mesa = sesion.perfil?.soloSuSede ?? false;
    final sedeFija = mesa ? sesion.perfil?.sedeId : null;
    if (mesa && sedeFija == null) {
      return const EstadoVacio('Tu cuenta de mesa no tiene sede asignada. Pide a administración que te la asigne.');
    }
    final sedeId = sedeFija ?? _sede;
    // Partidos de todos los torneos en curso (y del que se está preparando),
    // para que la mesa vea los suyos sin tener que elegir torneo.
    final enCurso = {for (final t in datos.torneos) if (t.activo || t.id == datos.torneo?.id) t.id};
    final ligasEnCurso = {for (final l in datos.ligas) if (enCurso.contains(l.torneoId)) l.id};
    final base = datos.todosPartidos.where((p) => ligasEnCurso.contains(p.ligaId)).toList();
    final variosTorneos = {for (final p in base) datos.liga(p.ligaId)?.torneoId}.length > 1;
    final diasBase = base.map((p) => soloDia(p.hora)).toSet().toList()..sort();
    final dias = diasBase.isNotEmpty ? diasBase : datos.diasTorneo;
    if (_dia == -1) {
      final hoy = dias.indexOf(soloDia(DateTime.now()));
      _dia = hoy >= 0 ? hoy : 0;
    }
    final dia = dias.isEmpty ? null : dias[_dia.clamp(0, dias.length - 1)];
    final lista = base
        .where((p) => (sedeId == null || p.sedeId == sedeId) && (dia == null || soloDia(p.hora) == dia))
        .toList();
    final retrasados = lista.where((p) => p.retrasado).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Text('Cada cambio se publica al momento en la web y en la app.', style: TextStyle(color: MarbelColors.apagado)),
        if (!mesa)
          OutlinedButton.icon(
            onPressed: () => nuevoPartido(context, dia: dia, sedeId: sedeId),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nuevo partido'),
          ),
      ]),
      const SizedBox(height: 12),
      if (!mesa)
        FilaChips(children: [
          ChipFiltro(texto: 'Todas las sedes', elegido: _sede == null, onTap: () => setState(() => _sede = null)),
          for (final s in datos.sedesEnCurso) ChipFiltro(texto: s.corto, elegido: _sede == s.id, onTap: () => setState(() => _sede = s.id)),
        ]),
      const SizedBox(height: 10),
      FilaChips(children: [
        for (var i = 0; i < dias.length; i++)
          ChipFiltro(texto: diaCorto(dias[i]), elegido: _dia == i, onTap: () => setState(() => _dia = i)),
      ]),
      const SizedBox(height: 16),
      for (final p in retrasados) ...[_AvisoRetraso(p), const SizedBox(height: 12)],
      if (lista.isEmpty)
        const EstadoVacio('No hay partidos este día en esta sede. El calendario se genera en «Calendario y sedes».')
      else
        for (final p in lista) ...[_EditorPartido(p, admin: !mesa, conTorneo: variosTorneos), const SizedBox(height: 12)],
    ]);
  }
}

/// "Retraso detectado": el partido debía empezar y sigue como Próximo.
class _AvisoRetraso extends StatelessWidget {
  const _AvisoRetraso(this.p);
  final Partido p;

  @override
  Widget build(BuildContext context) {
    final l = datos.nombreEquipo(p.localId), v = datos.nombreEquipo(p.visitanteId);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2A00),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MarbelColors.medio, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('⏰ RETRASO DETECTADO · +${p.minutosDeRetraso} MIN', style: MarbelText.titular(22, color: MarbelColors.medio).copyWith(fontStyle: FontStyle.normal)),
        const SizedBox(height: 4),
        Text('$l – $v (${p.campo ?? ''}) tenía que empezar a las ${hhmm(p.hora)} y sigue como «Próximo».',
            style: const TextStyle(color: Color(0xFFFFE08A))),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 8, children: [
          BotonCian('Ya ha empezado', onTap: () {
            cola.partido(p.id, {'estado': 'en_juego', 'retraso_min': p.minutosDeRetraso});
            avisar(context, 'Marcado en juego');
          }),
          BotonContorno('Avisar a seguidores', onTap: () => ejecutar(context, () async {
                final sede = datos.sede(p.sedeId)?.nombre ?? '';
                await db.from('avisos').insert({
                  'texto': 'El partido $l – $v de las ${hhmm(p.hora)} en $sede${p.campo == null ? '' : ' (${p.campo})'} empieza con retraso.',
                  'ambito': 'sede',
                  'ambito_ref': sede,
                  'automatico': true,
                  'torneo_id': datos.liga(p.ligaId)?.torneoId ?? datos.torneo?.id,
                });
                await cola.partido(p.id, {'retraso_min': p.minutosDeRetraso, 'aviso_retraso': true});
              }, ok: 'Aviso publicado')),
        ]),
      ]),
    );
  }
}

class _EditorPartido extends StatelessWidget {
  const _EditorPartido(this.p, {required this.admin, this.conTorneo = false});
  final Partido p;
  final bool admin;

  /// Enseñar de qué torneo es (cuando hay varios en curso).
  final bool conTorneo;

  /// Se ve al momento y se envía en cuanto haya conexión (sin cobertura, queda pendiente).
  Future<void> _cambiar(BuildContext context, Map<String, dynamic> cambios) => cola.partido(p.id, cambios);

  @override
  Widget build(BuildContext context) {
    final (est, fondo, color) = estadoPartido(p);
    final empate = p.tieneMarcador && p.golesLocal == p.golesVisitante;
    final penaltis = p.fase != Fase.liga && empate;
    final golesPartido = datos.todosGoles.where((g) => g.partidoId == p.id).toList();

    Widget marcador(String? equipoId, int? goles, String campo) {
      final e = datos.equipo(equipoId);
      return Row(children: [
        Escudo(e, tamano: 34),
        const SizedBox(width: 10),
        Expanded(child: Text(e?.nombre ?? 'Por decidir', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
        _BotonRedondo(Icons.remove_rounded, () {
          final g = (goles ?? 0) - 1;
          if (g >= 0) _cambiar(context, {campo: g});
        }),
        SizedBox(
          width: 52,
          child: Text('${goles ?? 0}', textAlign: TextAlign.center, style: MarbelText.titular(36).copyWith(fontStyle: FontStyle.normal)),
        ),
        _BotonRedondo(Icons.add_rounded, () {
          final cambios = <String, dynamic>{campo: (goles ?? 0) + 1};
          // Si nadie lo ha marcado aún, el primer gol pone el partido "en juego".
          if (p.estado == Estado.programado) cambios['estado'] = 'en_juego';
          if (!p.tieneMarcador) cambios[campo == 'goles_local' ? 'goles_visitante' : 'goles_local'] = 0;
          _cambiar(context, cambios);
        }, color: MarbelColors.cian),
      ]);
    }

    return Tarjeta(
      padding: const EdgeInsets.all(16),
      borde: p.estado == Estado.enJuego ? MarbelColors.enJuego : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(hhmm(p.horaReal), style: MarbelText.titular(24).copyWith(fontStyle: FontStyle.normal)),
          if (conTorneo)
            Text(datos.torneos.where((t) => t.id == datos.liga(p.ligaId)?.torneoId).firstOrNull?.nombre ?? '',
                style: const TextStyle(color: MarbelColors.cian, fontWeight: FontWeight.w700)),
          Pastilla.nivel(datos.nivelDeLiga(p.ligaId), texto: datos.nombreLigaPartido(p)),
          Text(switch (p.fase) {
            Fase.liga => 'Liga · J${p.jornada ?? ''}',
            Fase.semifinal => 'Semifinal ${p.jornada ?? ''}',
            Fase.tercerPuesto => '3er y 4º puesto',
            Fase.final_ => 'Final',
          }, style: const TextStyle(color: MarbelColors.apagado, fontWeight: FontWeight.w700)),
          if (datos.sede(p.sedeId) != null)
            Text('· ${datos.sede(p.sedeId)!.nombre}', style: const TextStyle(color: MarbelColors.apagado)),
        ]),
        const SizedBox(height: 12),
        marcador(p.localId, p.golesLocal, 'goles_local'),
        const SizedBox(height: 8),
        marcador(p.visitanteId, p.golesVisitante, 'goles_visitante'),
        if (penaltis) ...[
          const SizedBox(height: 10),
          Text('EMPATE EN ELIMINATORIA · PENALTIS', style: MarbelText.etiqueta(color: MarbelColors.medio, size: 13)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _Penaltis(valor: p.penaltisLocal, onCambio: (v) => _cambiar(context, {'penaltis_local': v}))),
            const Text('  –  '),
            Expanded(child: _Penaltis(valor: p.penaltisVisitante, onCambio: (v) => _cambiar(context, {'penaltis_visitante': v}))),
          ]),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
          // Estado
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Estado', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFC8D0F5))),
            const SizedBox(height: 4),
            SegmentedButton<Estado>(
              segments: const [
                ButtonSegment(value: Estado.programado, label: Text('Próximo')),
                ButtonSegment(value: Estado.enJuego, label: Text('En juego')),
                ButtonSegment(value: Estado.finalizado, label: Text('Final')),
              ],
              selected: {p.estado == Estado.aplazado ? Estado.programado : p.estado},
              onSelectionChanged: (s) {
                final e = s.first;
                final cambios = <String, dynamic>{'estado': estadoSql(e)};
                if (e != Estado.programado && !p.tieneMarcador) {
                  cambios['goles_local'] = 0;
                  cambios['goles_visitante'] = 0;
                }
                _cambiar(context, cambios);
              },
            ),
          ]),
          // Campo
          SizedBox(
            width: 150,
            child: Desplegable<String>(
              etiqueta: 'Campo',
              valor: p.campo,
              opciones: const [('Campo 1', 'Campo 1'), ('Campo 2', 'Campo 2'), ('Campo 3', 'Campo 3')],
              onCambio: (v) => _cambiar(context, {'campo': v}),
            ),
          ),
          // Retraso
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Retraso: ${p.retrasoMin} min', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFC8D0F5))),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              OutlinedButton(onPressed: () => _cambiar(context, {'retraso_min': p.retrasoMin + 5}), child: const Text('+5 min')),
              const SizedBox(width: 6),
              if (p.retrasoMin > 0)
                TextButton(onPressed: () => _cambiar(context, {'retraso_min': 0}), child: const Text('Quitar')),
            ]),
          ]),
          Pastilla(est, fondo: fondo, color: color, tamano: 12),
          if (admin)
            TextButton.icon(
              onPressed: () => _editarHora(context),
              icon: const Icon(Icons.edit_calendar_rounded, size: 18),
              label: const Text('Hora y sede'),
            ),
          if (admin)
            TextButton.icon(
              onPressed: () => _cambiarEquipos(context),
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Cambiar equipos'),
            ),
          if (admin)
            TextButton.icon(
              onPressed: () => _borrar(context),
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFFF7A85)),
              label: const Text('Borrar partido', style: TextStyle(color: Color(0xFFFF7A85))),
            ),
        ]),
        const SizedBox(height: 14),
        // Goles apuntados uno a uno (equipo y minuto; nunca el nombre del jugador)
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final g in golesPartido)
            InputChip(
              label: Text('⚽ ${datos.equipo(g.equipoId)?.iniciales ?? ''}${g.minuto == null ? '' : " ${g.minuto}'"}'),
              onDeleted: () async {
                final campo = g.equipoId == p.localId ? 'goles_local' : 'goles_visitante';
                final actual = g.equipoId == p.localId ? (p.golesLocal ?? 0) : (p.golesVisitante ?? 0);
                await cola.borrarGol(g.id);
                if (actual > 0) await cola.partido(p.id, {campo: actual - 1});
              },
            ),
          if (p.localId != null && p.visitanteId != null)
            TextButton.icon(
              onPressed: () => _anadirGol(context),
              icon: const Icon(Icons.sports_soccer_rounded, size: 18),
              label: const Text('Gol con minuto'),
            ),
        ]),
      ]),
    );
  }

  Future<void> _anadirGol(BuildContext context) async {
    String? equipo = p.localId;
    final minuto = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          backgroundColor: MarbelColors.tarjeta,
          title: const Text('Gol con minuto'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Desplegable<String>(
              etiqueta: 'Equipo',
              valor: equipo,
              opciones: [(p.localId!, datos.nombreEquipo(p.localId)), (p.visitanteId!, datos.nombreEquipo(p.visitanteId))],
              onCambio: (v) => set(() => equipo = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: minuto, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minuto (opcional)')),
            const SizedBox(height: 10),
            const Text('Sin nombres de jugadores: solo el equipo. Suma 1 al marcador de ese equipo.',
                style: TextStyle(color: MarbelColors.apagado, fontSize: 12)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('AÑADIR')),
          ],
        ),
      ),
    );
    if (ok != true || equipo == null || !context.mounted) return;
    await cola.nuevoGol({
      'id': nuevoId(),
      'partido_id': p.id,
      'equipo_id': equipo,
      'minuto': int.tryParse(minuto.text.trim()),
    });
    final campo = equipo == p.localId ? 'goles_local' : 'goles_visitante';
    final actual = equipo == p.localId ? (p.golesLocal ?? 0) : (p.golesVisitante ?? 0);
    final cambios = <String, dynamic>{campo: actual + 1};
    if (!p.tieneMarcador) cambios[campo == 'goles_local' ? 'goles_visitante' : 'goles_local'] = 0;
    if (p.estado == Estado.programado) cambios['estado'] = 'en_juego';
    await cola.partido(p.id, cambios);
    if (context.mounted) avisar(context, 'Gol añadido');
  }

  Future<void> _borrar(BuildContext context) async {
    final texto = '${datos.nombreEquipo(p.localId)} – ${datos.nombreEquipo(p.visitanteId)} · ${diaCorto(p.hora)} ${hhmm(p.hora)}';
    if (!await confirmar(context, '¿Borrar este partido?', '$texto\n\nSe borran también sus goles. No se puede deshacer.',
        boton: 'Borrar')) {
      return;
    }
    if (!context.mounted) return;
    await ejecutar(context, () async {
      await db.from('partidos').delete().eq('id', p.id);
      await datos.recargar();
    }, ok: 'Partido borrado');
  }

  /// Elegir (o cambiar) a mano los dos equipos del partido.
  Future<void> _cambiarEquipos(BuildContext context) async {
    final ids = <String>{
      ...equiposPara(p.ligaId, p.fase),
      if (p.localId != null) p.localId!,
      if (p.visitanteId != null) p.visitanteId!,
    }.toList();
    String local = p.localId ?? '';
    String visitante = p.visitanteId ?? '';
    final opciones = [('', 'Por decidir'), for (final id in ids) (id, datos.nombreEquipo(id))];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          backgroundColor: MarbelColors.tarjeta,
          title: Text(switch (p.fase) {
            Fase.semifinal => 'Semifinal ${p.jornada ?? ''}',
            Fase.tercerPuesto => '3er y 4º puesto',
            Fase.final_ => 'Final',
            Fase.liga => 'Liguilla · Jornada ${p.jornada ?? ''}',
          }),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Desplegable<String>(etiqueta: 'Local', valor: local, opciones: opciones, onCambio: (v) => set(() => local = v ?? '')),
              const SizedBox(height: 12),
              Desplegable<String>(etiqueta: 'Visitante', valor: visitante, opciones: opciones, onCambio: (v) => set(() => visitante = v ?? '')),
              const SizedBox(height: 10),
              if (local.isNotEmpty && local == visitante)
                const Text('Elige dos equipos distintos.', style: TextStyle(color: Color(0xFFFF7A85), fontSize: 13)),
              if (p.tieneMarcador)
                const Text('Este partido ya tiene marcador: se mantiene. Corrígelo si hace falta.',
                    style: TextStyle(color: MarbelColors.medio, fontSize: 12.5)),
              if (p.fase == Fase.semifinal)
                const Text('El ganador pasa solo a la final y el perdedor al 3er puesto cuando la semifinal acabe.',
                    style: TextStyle(color: MarbelColors.apagado, fontSize: 12.5)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: local.isNotEmpty && local == visitante ? null : () => Navigator.pop(c, true),
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      await _cambiar(context, {
        'local_id': local.isEmpty ? null : local,
        'visitante_id': visitante.isEmpty ? null : visitante,
      });
    }
  }

  Future<void> _editarHora(BuildContext context) async {
    final h = await elegirFechaHora(context, p.hora);
    if (h == null || !context.mounted) return;
    String? sede = p.sedeId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          backgroundColor: MarbelColors.tarjeta,
          title: Text('${diaCorto(h)} · ${hhmm(h)}'),
          content: Desplegable<String>(
            etiqueta: 'Sede',
            valor: sede,
            opciones: [for (final s in datos.sedesDePartido(p)) (s.id, s.nombre)],
            onCambio: (v) => set(() => sede = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('GUARDAR')),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      await _cambiar(context, {'hora': h.toUtc().toIso8601String(), 'sede_id': sede});
    }
  }
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo(this.icono, this.onTap, {this.color = const Color(0xFF131B6B)});
  final IconData icono;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icono, color: color == MarbelColors.cian ? MarbelColors.fondo : MarbelColors.blanco),
        ),
      ),
    );
  }
}

class _Penaltis extends StatelessWidget {
  const _Penaltis({required this.valor, required this.onCambio});
  final int? valor;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(onPressed: () => onCambio(((valor ?? 0) - 1).clamp(0, 99)), icon: const Icon(Icons.remove_rounded)),
      Text('${valor ?? 0}', style: MarbelText.titular(26).copyWith(fontStyle: FontStyle.normal)),
      IconButton(onPressed: () => onCambio((valor ?? 0) + 1), icon: const Icon(Icons.add_rounded)),
    ]);
  }
}


/// Equipos que pueden jugar un partido de esa liga: los de la liga (en la
/// liguilla) o los de todos sus grupos (en la fase final).
List<String> equiposPara(String ligaId, Fase fase) {
  final l = datos.liga(ligaId);
  if (l == null) return const [];
  final ligas = fase == Fase.liga ? [l] : datos.gruposDe(l);
  final ids = <String>{for (final x in ligas) ...?datos.equiposDeLiga[x.id]}.toList()
    ..sort((a, b) => datos.nombreEquipo(a).compareTo(datos.nombreEquipo(b)));
  return ids;
}

/// Crear un partido a mano (liguilla o fase final). Solo administración.
Future<void> nuevoPartido(BuildContext context, {DateTime? dia, String? sedeId}) async {
  final ligas = datos.ligasActuales;
  if (ligas.isEmpty) {
    avisar(context, 'Primero inscribe equipos en una liga («Equipos e inscripciones»).', error: true);
    return;
  }
  String? liga = ligas.first.id;
  var fase = Fase.liga;
  final jornada = TextEditingController(text: '1');
  String local = '';
  String visitante = '';
  final base = dia ?? soloDia(DateTime.now());
  DateTime? hora = DateTime(base.year, base.month, base.day, 10);
  final sedesT = datos.sedesTorneo;
  String? sede = sedesT.any((s) => s.id == sedeId) ? sedeId : sedesT.firstOrNull?.id;
  String? campo = 'Campo 1';
  String? error;

  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) {
        final equipos = liga == null ? const <String>[] : equiposPara(liga!, fase);
        final opciones = [('', 'Por decidir'), for (final id in equipos) (id, datos.nombreEquipo(id))];
        if (local.isNotEmpty && !equipos.contains(local)) local = '';
        if (visitante.isNotEmpty && !equipos.contains(visitante)) visitante = '';
        return AlertDialog(
          backgroundColor: MarbelColors.tarjeta,
          title: const Text('Nuevo partido'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Desplegable<String>(
                  etiqueta: 'Liga',
                  valor: liga,
                  opciones: [for (final l in ligas) (l.id, datos.nombreLiga(l.id))],
                  onCambio: (v) => set(() => liga = v),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Desplegable<Fase>(
                      etiqueta: 'Fase',
                      valor: fase,
                      opciones: const [
                        (Fase.liga, 'Liguilla'),
                        (Fase.semifinal, 'Semifinal'),
                        (Fase.tercerPuesto, '3er y 4º puesto'),
                        (Fase.final_, 'Final'),
                      ],
                      onCambio: (v) => set(() {
                        fase = v ?? Fase.liga;
                        jornada.text = '1';
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (fase == Fase.liga || fase == Fase.semifinal)
                    SizedBox(
                      width: 120,
                      child: fase == Fase.semifinal
                          ? Desplegable<String>(
                              etiqueta: 'Semifinal',
                              valor: jornada.text,
                              opciones: const [('1', 'Semi 1'), ('2', 'Semi 2')],
                              onCambio: (v) => set(() => jornada.text = v ?? '1'),
                            )
                          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Jornada', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFC8D0F5))),
                              const SizedBox(height: 4),
                              TextField(
                                controller: jornada,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                              ),
                            ]),
                    ),
                ]),
                const SizedBox(height: 12),
                Desplegable<String>(etiqueta: 'Local', valor: local, opciones: opciones, onCambio: (v) => set(() => local = v ?? '')),
                const SizedBox(height: 12),
                Desplegable<String>(
                    etiqueta: 'Visitante', valor: visitante, opciones: opciones, onCambio: (v) => set(() => visitante = v ?? '')),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final h = await elegirFechaHora(c, hora ?? DateTime.now());
                    if (h != null) set(() => hora = h);
                  },
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(hora == null ? 'Elegir día y hora' : '${diaCorto(hora!)} · ${hhmm(hora!)}'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Desplegable<String>(
                      etiqueta: 'Sede',
                      valor: sede,
                      opciones: [for (final s in sedesT) (s.id, s.nombre)],
                      onCambio: (v) => set(() => sede = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    child: Desplegable<String>(
                      etiqueta: 'Campo',
                      valor: campo,
                      opciones: const [('Campo 1', 'Campo 1'), ('Campo 2', 'Campo 2'), ('Campo 3', 'Campo 3')],
                      onCambio: (v) => set(() => campo = v),
                    ),
                  ),
                ]),
                if (fase != Fase.liga && liga != null && datos.liga(liga!)?.finalEn != null) ...[
                  const SizedBox(height: 10),
                  const Text('Esta categoría tiene fase final conjunta: el partido se añade a ella.',
                      style: TextStyle(color: MarbelColors.cian, fontSize: 12.5)),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Color(0xFFFF7A85), fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final j = int.tryParse(jornada.text.trim());
                final String? problema = switch (true) {
                  _ when liga == null => 'Elige la liga',
                  _ when hora == null => 'Elige el día y la hora',
                  _ when sede == null => 'Elige la sede',
                  _ when fase == Fase.liga && (local.isEmpty || visitante.isEmpty) => 'En la liguilla hay que elegir los dos equipos',
                  _ when local.isNotEmpty && local == visitante => 'Elige dos equipos distintos',
                  _ when fase == Fase.liga && (j == null || j < 1) => 'La jornada tiene que ser un número (1, 2, 3...)',
                  _ => null,
                };
                if (problema != null) {
                  set(() => error = problema);
                  return;
                }
                Navigator.pop(c, true);
              },
              child: const Text('CREAR'),
            ),
          ],
        );
      },
    ),
  );
  final j = int.tryParse(jornada.text.trim()) ?? 1;
  jornada.dispose();
  if (ok != true || !context.mounted) return;
  final destino = fase == Fase.liga ? liga! : datos.ligaFaseFinal(liga!);
  await ejecutar(context, () async {
    await db.from('partidos').insert({
      'liga_id': destino,
      'fase': faseSql(fase),
      'jornada': fase == Fase.tercerPuesto || fase == Fase.final_ ? 1 : j,
      'local_id': local.isEmpty ? null : local,
      'visitante_id': visitante.isEmpty ? null : visitante,
      'hora': hora!.toUtc().toIso8601String(),
      'sede_id': sede,
      'campo': campo,
    });
    await datos.recargar();
  }, ok: 'Partido creado');
}
