import 'package:flutter/material.dart';

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
    final dias = datos.diasTorneo;
    if (_dia == -1) {
      final hoy = dias.indexOf(soloDia(DateTime.now()));
      _dia = hoy >= 0 ? hoy : 0;
    }
    final dia = dias.isEmpty ? null : dias[_dia.clamp(0, dias.length - 1)];
    final lista = datos.partidos
        .where((p) => (sedeId == null || p.sedeId == sedeId) && (dia == null || soloDia(p.hora) == dia))
        .toList();
    final retrasados = lista.where((p) => p.retrasado).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Cada cambio se publica al momento en la web y en la app.', style: TextStyle(color: MarbelColors.apagado)),
      const SizedBox(height: 12),
      if (!mesa)
        FilaChips(children: [
          ChipFiltro(texto: 'Todas las sedes', elegido: _sede == null, onTap: () => setState(() => _sede = null)),
          for (final s in datos.sedes) ChipFiltro(texto: s.corto, elegido: _sede == s.id, onTap: () => setState(() => _sede = s.id)),
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
        for (final p in lista) ...[_EditorPartido(p, admin: !mesa), const SizedBox(height: 12)],
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
          BotonCian('Ya ha empezado', onTap: () => ejecutar(context, () async {
                await db.from('partidos').update({'estado': 'en_juego', 'retraso_min': p.minutosDeRetraso}).eq('id', p.id);
              }, ok: 'Marcado en juego')),
          BotonContorno('Avisar a seguidores', onTap: () => ejecutar(context, () async {
                final sede = datos.sede(p.sedeId)?.nombre ?? '';
                await db.from('avisos').insert({
                  'texto': 'El partido $l – $v de las ${hhmm(p.hora)} en $sede${p.campo == null ? '' : ' (${p.campo})'} empieza con retraso.',
                  'ambito': 'sede',
                  'ambito_ref': sede,
                  'automatico': true,
                  'torneo_id': datos.torneo?.id,
                });
                await db.from('partidos').update({'retraso_min': p.minutosDeRetraso, 'aviso_retraso': true}).eq('id', p.id);
              }, ok: 'Aviso publicado')),
        ]),
      ]),
    );
  }
}

class _EditorPartido extends StatelessWidget {
  const _EditorPartido(this.p, {required this.admin});
  final Partido p;
  final bool admin;

  Future<void> _cambiar(BuildContext context, Map<String, dynamic> cambios) =>
      ejecutar(context, () async {
        await db.from('partidos').update(cambios).eq('id', p.id);
      });

  @override
  Widget build(BuildContext context) {
    final (est, fondo, color) = estadoPartido(p);
    final empate = p.tieneMarcador && p.golesLocal == p.golesVisitante;
    final penaltis = p.fase != Fase.liga && empate;
    final golesPartido = datos.goles.where((g) => g.partidoId == p.id).toList();

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
          Pastilla.nivel(datos.nivelDeLiga(p.ligaId), texto: datos.nombreLiga(p.ligaId)),
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
        ]),
        const SizedBox(height: 14),
        // Goles con autor
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final g in golesPartido)
            InputChip(
              label: Text('⚽ ${g.jugador}${g.minuto == null ? '' : " ${g.minuto}'"} · ${datos.equipo(g.equipoId)?.iniciales ?? ''}'),
              onDeleted: () => ejecutar(context, () async {
                await db.from('goles').delete().eq('id', g.id);
                final campo = g.equipoId == p.localId ? 'goles_local' : 'goles_visitante';
                final actual = g.equipoId == p.localId ? (p.golesLocal ?? 0) : (p.golesVisitante ?? 0);
                if (actual > 0) await db.from('partidos').update({campo: actual - 1}).eq('id', p.id);
              }),
            ),
          if (p.localId != null && p.visitanteId != null)
            TextButton.icon(
              onPressed: () => _anadirGol(context),
              icon: const Icon(Icons.sports_soccer_rounded, size: 18),
              label: const Text('Gol con nombre'),
            ),
        ]),
      ]),
    );
  }

  Future<void> _anadirGol(BuildContext context) async {
    String? equipo = p.localId;
    final nombre = TextEditingController();
    final minuto = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          backgroundColor: MarbelColors.tarjeta,
          title: const Text('Gol con nombre'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Desplegable<String>(
              etiqueta: 'Equipo',
              valor: equipo,
              opciones: [(p.localId!, datos.nombreEquipo(p.localId)), (p.visitanteId!, datos.nombreEquipo(p.visitanteId))],
              onCambio: (v) => set(() => equipo = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nombre,
              decoration: const InputDecoration(labelText: 'Nombre e inicial (ej.: Hugo S.)'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(controller: minuto, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minuto (opcional)')),
            const SizedBox(height: 10),
            const Text('Solo nombre e inicial del apellido. Suma 1 al marcador de ese equipo.',
                style: TextStyle(color: MarbelColors.apagado, fontSize: 12)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('AÑADIR')),
          ],
        ),
      ),
    );
    final n = _formatoNombre(nombre.text);
    if (ok != true || equipo == null || n.length < 2 || !context.mounted) return;
    await ejecutar(context, () async {
      await db.from('goles').insert({
        'partido_id': p.id,
        'equipo_id': equipo,
        'jugador': n,
        'minuto': int.tryParse(minuto.text.trim()),
      });
      final campo = equipo == p.localId ? 'goles_local' : 'goles_visitante';
      final actual = equipo == p.localId ? (p.golesLocal ?? 0) : (p.golesVisitante ?? 0);
      final cambios = <String, dynamic>{campo: actual + 1};
      if (!p.tieneMarcador) cambios[campo == 'goles_local' ? 'goles_visitante' : 'goles_local'] = 0;
      if (p.estado == Estado.programado) cambios['estado'] = 'en_juego';
      await db.from('partidos').update(cambios).eq('id', p.id);
    }, ok: 'Gol añadido');
  }

  /// "hugo sánchez" -> "Hugo S."
  String _formatoNombre(String s) {
    final partes = s.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (partes.isEmpty) return '';
    String cap(String w) => w[0].toUpperCase() + w.substring(1).toLowerCase();
    final nombre = cap(partes.first);
    if (partes.length == 1) return nombre;
    final ini = partes[1].replaceAll('.', '');
    return ini.isEmpty ? nombre : '$nombre ${ini[0].toUpperCase()}.';
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
            opciones: [for (final s in datos.sedes) (s.id, s.nombre)],
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
