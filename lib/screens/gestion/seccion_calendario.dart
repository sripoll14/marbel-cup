import 'package:flutter/material.dart';

import '../../data/datos.dart';
import '../../data/modelos.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';
import 'utiles.dart';

/// Genera la liguilla y la fase final de cada liga, y muestra las sedes.
class SeccionCalendario extends StatelessWidget {
  const SeccionCalendario({super.key});

  Future<({String sede, DateTime inicio, int minutos, int campos})?> _pedirDatos(
      BuildContext context, String titulo, {bool conCampos = true}) async {
    String? sede = datos.sedes.firstOrNull?.id;
    var inicio = datos.torneo?.inicio.toLocal() ?? DateTime.now();
    final minutos = TextEditingController(text: '30');
    final campos = TextEditingController(text: '2');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          backgroundColor: MarbelColors.tarjeta,
          title: Text(titulo),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Desplegable<String>(
                etiqueta: 'Sede',
                valor: sede,
                opciones: [for (final s in datos.sedes) (s.id, s.nombre)],
                onCambio: (v) => set(() => sede = v),
              ),
              const SizedBox(height: 12),
              const Text('Primer partido', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFC8D0F5))),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await elegirFechaHora(c, inicio);
                  if (d != null) set(() => inicio = d);
                },
                icon: const Icon(Icons.event_rounded),
                label: Text('${diaCorto(inicio)} · ${hhmm(inicio)}'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: minutos,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minutos entre partidos'),
                  ),
                ),
                if (conCampos) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: campos,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Campos a la vez'),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 10),
              const Text('Luego puedes mover cualquier partido de hora, sede o campo en «Partidos y resultados».',
                  style: TextStyle(color: MarbelColors.apagado, fontSize: 12)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('GENERAR')),
          ],
        ),
      ),
    );
    if (ok != true || sede == null) return null;
    return (
      sede: sede!,
      inicio: inicio,
      minutos: int.tryParse(minutos.text) ?? 30,
      campos: int.tryParse(campos.text) ?? 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ligas = datos.ligasActuales;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text(
        'Cada liga juega una liguilla todos contra todos y después semifinales (1º–4º y 2º–3º), '
        'partido por el 3er y 4º puesto y final. Desempate: diferencia de goles y, después, goles a favor.',
        style: TextStyle(color: MarbelColors.apagado),
      ),
      const SizedBox(height: 16),
      const SubTitulo('Ligas'),
      if (ligas.isEmpty) const EstadoVacio('Aún no hay ligas. Se crean al inscribir equipos en «Equipos e inscripciones».'),
      for (final l in ligas) _FilaLiga(l, pedirDatos: _pedirDatos),
      const SizedBox(height: 20),
      const SubTitulo('Sedes'),
      for (final s in datos.sedes) ...[
        Tarjeta(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.place_rounded, color: MarbelColors.cian),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(s.nombreOficial, style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
              ]),
            ),
            Text('${datos.partidos.where((p) => p.sedeId == s.id).length} partidos',
                style: const TextStyle(color: MarbelColors.texto2)),
          ]),
        ),
        const SizedBox(height: 8),
      ],
      const Text('Los datos de las sedes (servicios, ubicación, fotos) se cambian en Supabase → Table Editor → sedes.',
          style: TextStyle(color: MarbelColors.apagado, fontSize: 12)),
    ]);
  }
}

class _FilaLiga extends StatelessWidget {
  const _FilaLiga(this.liga, {required this.pedirDatos});
  final Liga liga;
  final Future<({String sede, DateTime inicio, int minutos, int campos})?> Function(BuildContext, String, {bool conCampos})
      pedirDatos;

  @override
  Widget build(BuildContext context) {
    final equipos = datos.equiposDeLiga[liga.id] ?? const <String>[];
    final partidos = datos.partidosDeLiga(liga.id);
    final deLiga = partidos.where((p) => p.fase == Fase.liga).toList();
    final finales = partidos.where((p) => p.fase != Fase.liga).toList();
    final ligaTerminada = deLiga.isNotEmpty && deLiga.every((p) => p.estado == Estado.finalizado);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tarjeta(
        padding: const EdgeInsets.all(14),
        child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 230),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Pastilla.nivel(Nivel.de(liga.nivelId), texto: datos.nombreLiga(liga.id)),
              const SizedBox(height: 6),
              Text('${equipos.length} equipos · ${deLiga.length} partidos de liga · ${finales.length} de fase final',
                  style: const TextStyle(color: MarbelColors.texto2, fontSize: 13)),
            ]),
          ),
          if (deLiga.isEmpty)
            OutlinedButton.icon(
              onPressed: equipos.length < 2
                  ? null
                  : () async {
                      final d = await pedirDatos(context, 'Liguilla · ${datos.nombreLiga(liga.id)}');
                      if (d == null || !context.mounted) return;
                      await ejecutar(context, () async {
                        await db.rpc('generar_liga', params: {
                          'p_liga': liga.id,
                          'p_inicio': d.inicio.toUtc().toIso8601String(),
                          'p_sede': d.sede,
                          'p_minutos': d.minutos,
                          'p_campos': d.campos,
                        });
                        await datos.recargar();
                      }, ok: 'Liguilla generada');
                    },
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Generar liguilla'),
            )
          else
            TextButton(
              onPressed: () async {
                if (!await confirmar(context, '¿Borrar la liguilla?',
                    'Se borrarán los ${deLiga.length} partidos de liga (y sus goles) y los de fase final.', boton: 'Borrar')) {
                  return;
                }
                if (!context.mounted) return;
                await ejecutar(context, () async {
                  await db.from('partidos').delete().eq('liga_id', liga.id);
                  await datos.recargar();
                }, ok: 'Partidos borrados');
              },
              child: const Text('Borrar partidos', style: TextStyle(color: Color(0xFFFF7A85))),
            ),
          if (deLiga.isNotEmpty && finales.isEmpty)
            OutlinedButton.icon(
              onPressed: () async {
                if (!ligaTerminada &&
                    !await confirmar(context, 'La liguilla no ha terminado',
                        'Los cruces se harán con la clasificación de ahora mismo. ¿Seguir?', boton: 'Seguir')) {
                  return;
                }
                if (!context.mounted) return;
                final d = await pedirDatos(context, 'Fase final · ${datos.nombreLiga(liga.id)}', conCampos: false);
                if (d == null || !context.mounted) return;
                await ejecutar(context, () async {
                  await db.rpc('generar_fase_final', params: {
                    'p_liga': liga.id,
                    'p_inicio': d.inicio.toUtc().toIso8601String(),
                    'p_sede': d.sede,
                    'p_minutos': d.minutos,
                  });
                  await datos.recargar();
                }, ok: 'Semifinales, 3er puesto y final creados');
              },
              icon: const Icon(Icons.emoji_events_rounded, size: 18),
              label: const Text('Generar fase final'),
            ),
          if (finales.isNotEmpty)
            TextButton(
              onPressed: () async {
                if (!await confirmar(context, '¿Borrar la fase final?', 'Se borrarán semifinales, 3er puesto y final.', boton: 'Borrar')) {
                  return;
                }
                if (!context.mounted) return;
                await ejecutar(context, () async {
                  await db.from('partidos').delete().eq('liga_id', liga.id).neq('fase', 'liga');
                  await datos.recargar();
                });
              },
              child: const Text('Borrar fase final', style: TextStyle(color: Color(0xFFFF7A85))),
            ),
        ]),
      ),
    );
  }
}
