import 'package:flutter/material.dart';

import '../../data/datos.dart';
import '../../data/modelos.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';
import 'dialogo_liguilla.dart';
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
              const Text('Hora de las semifinales', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFC8D0F5))),
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
                    decoration: const InputDecoration(labelText: 'Minutos por partido'),
                  ),
                ),
                if (conCampos) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: campos,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Campos de la sede'),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 10),
              const Text('Usa los campos que estén libres a esa hora (sin pisar otras ligas). Luego puedes mover cualquier partido en «Partidos y resultados».',
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
    final grupos = datos.gruposDe(liga);
    final ligaBase = liga.finalEn == null ? null : datos.liga(liga.finalEn!);
    // Botón de fase final conjunta: solo en el primer grupo, si hay varios grupos,
    // todos tienen liguilla y ninguno tiene aún fase final.
    final puedeConjunta = grupos.length > 1 &&
        grupos.first.id == liga.id &&
        grupos.every((g) =>
            g.finalEn == null &&
            datos.partidosDeLiga(g.id).any((p) => p.fase == Fase.liga) &&
            !datos.partidosDeLiga(g.id).any((p) => p.fase != Fase.liga));

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
                      final d = await pedirLiguilla(context, liga);
                      if (d == null || !context.mounted) return;
                      await ejecutar(context, () async {
                        await db.rpc('generar_liga', params: {
                          'p_liga': liga.id,
                          'p_franjas': d.franjas,
                          'p_minutos': d.minutos,
                          'p_repartir': d.repartir,
                        });
                        await datos.recargar();
                      }, ok: 'Liguilla generada. Revísala en «Partidos y resultados».');
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
                  // Si había fase final conjunta, se deshace para todos los grupos
                  if (datos.enFaseConjunta(liga.id)) await db.rpc('borrar_fase_final', params: {'p_liga': liga.id});
                  await db.from('partidos').delete().eq('liga_id', liga.id);
                  await datos.recargar();
                }, ok: 'Partidos borrados');
              },
              child: const Text('Borrar partidos', style: TextStyle(color: Color(0xFFFF7A85))),
            ),
          if (ligaBase != null)
            Text('Fase final conjunta: se juega en el grupo ${ligaBase.grupo ?? ''}',
                style: const TextStyle(color: MarbelColors.cian, fontWeight: FontWeight.w700, fontSize: 13)),
          if (deLiga.isNotEmpty && finales.isEmpty && liga.finalEn == null)
            OutlinedButton.icon(
              onPressed: () async {
                if (!ligaTerminada &&
                    !await confirmar(context, 'La liguilla no ha terminado',
                        'Los cruces se harán con la clasificación de ahora mismo. ¿Seguir?', boton: 'Seguir')) {
                  return;
                }
                if (!context.mounted) return;
                final d = await pedirDatos(context, 'Fase final · ${datos.nombreLiga(liga.id)}');
                if (d == null || !context.mounted) return;
                await ejecutar(context, () async {
                  await db.rpc('generar_fase_final', params: {
                    'p_liga': liga.id,
                    'p_inicio': d.inicio.toUtc().toIso8601String(),
                    'p_sede': d.sede,
                    'p_minutos': d.minutos,
                    'p_campos': d.campos,
                  });
                  await datos.recargar();
                }, ok: 'Semifinales, 3er puesto y final creados');
              },
              icon: const Icon(Icons.emoji_events_rounded, size: 18),
              label: const Text('Generar fase final'),
            ),
          if (finales.isEmpty && liga.finalEn == null && equipos.length >= 2)
            TextButton.icon(
              onPressed: () async {
                if (!await confirmar(
                    context,
                    'Fase final a mano',
                    'Se crean las semifinales, el 3er puesto y la final sin equipos. Después eliges los equipos de cada '
                        'partido en «Partidos y resultados» → «Cambiar equipos». La final y el 3er puesto se siguen '
                        'rellenando solos con los resultados de las semifinales (y también se pueden cambiar a mano).',
                    boton: 'Seguir')) {
                  return;
                }
                if (!context.mounted) return;
                final d = await pedirDatos(context, 'Fase final a mano · ${datos.nombreLiga(liga.id)}');
                if (d == null || !context.mounted) return;
                await ejecutar(context, () async {
                  await db.rpc('crear_fase_final_vacia', params: {
                    'p_liga': liga.id,
                    'p_inicio': d.inicio.toUtc().toIso8601String(),
                    'p_sede': d.sede,
                    'p_minutos': d.minutos,
                    'p_campos': d.campos,
                  });
                  await datos.recargar();
                }, ok: 'Creada. Elige los equipos en «Partidos y resultados».');
              },
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Fase final a mano'),
            ),
          if (puedeConjunta)
            OutlinedButton.icon(
              onPressed: () async {
                final letras = grupos.map((g) => g.grupo ?? '').join(', ');
                final cruces = switch (grupos.length) {
                  2 => 'Semifinales: 1º A – 2º B y 1º B – 2º A.',
                  3 => 'Se clasifican los tres primeros y el mejor segundo (sin repetir grupo en semifinales).',
                  4 => 'Semifinales: 1º A – 1º D y 1º B – 1º C.',
                  _ => 'Admite como mucho 4 grupos.',
                };
                final sinAcabar = grupos.any((g) => datos.partidosDeLiga(g.id).any((p) => p.fase == Fase.liga && p.estado != Estado.finalizado));
                if (!await confirmar(
                    context,
                    'Fase final conjunta (grupos $letras)',
                    'En vez de una fase final por grupo, se juega una sola entre todos los grupos. $cruces '
                        'Después, 3er puesto y final como siempre.'
                        '${sinAcabar ? '\n\nOjo: algún grupo no ha terminado; los cruces se harán con la clasificación de ahora.' : ''}',
                    boton: 'Seguir')) {
                  return;
                }
                if (!context.mounted) return;
                final d = await pedirDatos(context, 'Fase final conjunta · ${datos.nombreLiga(liga.id, sinGrupo: true)}');
                if (d == null || !context.mounted) return;
                await ejecutar(context, () async {
                  await db.rpc('generar_fase_conjunta', params: {
                    'p_liga': liga.id,
                    'p_inicio': d.inicio.toUtc().toIso8601String(),
                    'p_sede': d.sede,
                    'p_minutos': d.minutos,
                    'p_campos': d.campos,
                  });
                  await datos.recargar();
                }, ok: 'Fase final conjunta creada');
              },
              icon: const Icon(Icons.merge_type_rounded, size: 18),
              label: const Text('Fase final conjunta'),
            ),
          if (finales.isNotEmpty)
            TextButton(
              onPressed: () async {
                final conjunta = datos.tieneFaseConjunta(liga.id);
                if (!await confirmar(
                    context,
                    conjunta ? '¿Borrar la fase final conjunta?' : '¿Borrar la fase final?',
                    conjunta
                        ? 'Se borrarán semifinales, 3er puesto y final, y cada grupo podrá volver a tener la suya.'
                        : 'Se borrarán semifinales, 3er puesto y final.',
                    boton: 'Borrar')) {
                  return;
                }
                if (!context.mounted) return;
                await ejecutar(context, () async {
                  await db.rpc('borrar_fase_final', params: {'p_liga': liga.id});
                  await datos.recargar();
                });
              },
              child: Text(datos.tieneFaseConjunta(liga.id) ? 'Borrar fase final conjunta' : 'Borrar fase final',
                  style: const TextStyle(color: Color(0xFFFF7A85))),
            ),
          PopupMenuButton<String>(
            tooltip: 'Grupos',
            color: MarbelColors.tarjeta,
            icon: const Icon(Icons.more_vert_rounded, color: MarbelColors.apagado),
            onSelected: (v) async {
              if (v == 'nuevo') {
                final ok = await confirmar(
                    context,
                    liga.grupo == null ? '¿Dividir en grupos?' : '¿Añadir otro grupo?',
                    liga.grupo == null
                        ? 'Esta liga pasará a ser el grupo A y se creará un grupo B vacío. Después, en «Equipos e inscripciones», '
                            'quita los equipos que van al grupo B de esta liga e inscríbelos en el B. '
                            'Cada grupo tiene su calendario, su clasificación, su fase final y su porra.'
                        : 'Se creará un grupo nuevo vacío. Inscribe sus equipos en «Equipos e inscripciones».',
                    boton: 'Crear grupo');
                if (!ok || !context.mounted) return;
                await ejecutar(context, () async {
                  await db.rpc('nuevo_grupo',
                      params: {'p_torneo': liga.torneoId, 'p_categoria': liga.categoriaId, 'p_nivel': liga.nivelId});
                  await datos.recargar();
                }, ok: 'Grupo creado');
              } else if (v == 'quitar') {
                await ejecutar(context, () async {
                  await db.rpc('borrar_grupo', params: {'p_liga': liga.id});
                  await datos.recargar();
                }, ok: 'Grupo quitado');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'nuevo', child: Text(liga.grupo == null ? 'Dividir en grupos (A y B)' : 'Añadir otro grupo')),
              if (liga.grupo != null)
                PopupMenuItem(
                  value: 'quitar',
                  enabled: equipos.isEmpty && partidos.isEmpty,
                  child: Text(equipos.isEmpty && partidos.isEmpty
                      ? 'Quitar el grupo ${liga.grupo}'
                      : 'Quitar el grupo ${liga.grupo} (antes, sin equipos ni partidos)'),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}
