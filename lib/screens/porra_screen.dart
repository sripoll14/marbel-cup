import 'dart:async';

import 'package:flutter/material.dart';

import '../data/datos.dart';
import '../data/modelos.dart';
import '../data/sesion.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/competicion.dart';
import '../widgets/cuenta.dart';
import '../widgets/marco_app.dart';

/// La Porra: predicciones por liga + ranking.
/// Puntos: ganador liga 3 · 5º 2 · cada finalista 4 · campeón 8 · 3er puesto 2.
class PorraScreen extends StatefulWidget {
  const PorraScreen({super.key});

  @override
  State<PorraScreen> createState() => _PorraScreenState();
}

class _PorraScreenState extends State<PorraScreen> {
  bool _registro = true; // sin sesión: registro o entrar
  bool _verRanking = false; // móvil
  String? _liga;

  @override
  Widget build(BuildContext context) {
    return ConDatos(
      builder: (context) => ListenableBuilder(
        listenable: sesion,
        builder: (context, _) {
          final ancho = esAncho(context);
          final ligas = datos.ligasActuales;
          _liga ??= ligaInicial();
          final ligaId = ligas.isEmpty ? null : (datos.liga(_liga ?? '') == null ? ligas.first.id : _liga!);

          final juego = !sesion.conectado
              ? _sinCuenta()
              : ligaId == null
                  ? const EstadoVacio('La Porra se abre cuando la organización publique las ligas. ¡Vuelve pronto!',
                      icono: Icons.emoji_events_outlined)
                  : _Prediccion(key: ValueKey(ligaId), ligaId: ligaId);

          final selector = ligaId == null
              ? const SizedBox.shrink()
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SelectorLiga(ligaId: ligaId, onCambio: (l) => setState(() => _liga = l)),
                  const SizedBox(height: 6),
                  const Text('Puedes hacer una porra por cada categoría.', style: TextStyle(color: MarbelColors.apagado, fontSize: 13)),
                ]);

          final ranking = _Ranking(ligaId: ligaId);

          if (!ancho) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                CabeceraMovil('La Porra',
                    derecha: sesion.perfil == null
                        ? null
                        : Text(sesion.perfil!.nombreCorto, style: const TextStyle(color: MarbelColors.cian, fontWeight: FontWeight.w700))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(child: ChipFiltro(texto: 'Mi predicción', elegido: !_verRanking, colorElegido: MarbelColors.cian, onTap: () => setState(() => _verRanking = false))),
                    const SizedBox(width: 8),
                    Expanded(child: ChipFiltro(texto: 'Ranking', elegido: _verRanking, colorElegido: MarbelColors.cian, onTap: () => setState(() => _verRanking = true))),
                  ]),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (sesion.conectado || _verRanking) ...[selector, const SizedBox(height: 14)],
                    _verRanking ? ranking : juego,
                  ]),
                ),
              ],
            );
          }

          return PaginaPublica(children: [
            const SizedBox(height: 48),
            AnchoMax(
              child: TituloSeccion(
                etiqueta: 'Predicciones',
                titulo: 'La Porra Marbel',
                tamano: 80,
                derecha: ligaId == null ? null : _Cierre(ligaId: ligaId),
              ),
            ),
            const SizedBox(height: 20),
            if (ligaId != null) AnchoMax(child: selector),
            const SizedBox(height: 20),
            AnchoMax(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 64, child: juego),
                const SizedBox(width: 20),
                Expanded(flex: 32, child: ranking),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  Widget _sinCuenta() {
    return Tarjeta(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('🏆', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 6),
        Text(_registro ? 'CREA TU CUENTA PARA JUGAR' : 'ENTRA EN TU CUENTA', style: MarbelText.titular(32)),
        const SizedBox(height: 6),
        const Text('Para ver partidos, clasificaciones y avisos no hace falta registrarse. Solo para La Porra.',
            style: TextStyle(color: MarbelColors.texto2)),
        const SizedBox(height: 16),
        if (_registro)
          FormularioRegistro(alTenerCuenta: () => setState(() => _registro = false))
        else
          FormularioEntrar(alCrearCuenta: () => setState(() => _registro = true)),
        if (!esAncho(context)) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: () => setState(() => _verRanking = true), child: const Text('Ver el ranking sin registrarme')),
        ],
      ]),
    );
  }
}

/// "Se cierra en ..." / "Predicciones cerradas".
class _Cierre extends StatefulWidget {
  const _Cierre({required this.ligaId});
  final String ligaId;

  @override
  State<_Cierre> createState() => _CierreState();
}

class _CierreState extends State<_Cierre> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = datos.cierrePorra(widget.ligaId);
    final abierta = datos.porraAbierta(widget.ligaId);
    String texto;
    if (c == null) {
      texto = 'Se cierra 30 min antes del primer partido';
    } else if (abierta) {
      final r = c.difference(DateTime.now());
      final cuanto = r.inDays > 0 ? '${r.inDays} d ${r.inHours % 24} h' : '${r.inHours} h ${r.inMinutes % 60} min';
      texto = 'Cierra en $cuanto · ${diaCorto(c)} · ${hhmm(c)}';
    } else {
      texto = 'Predicciones cerradas · ¡Suerte!';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: abierta ? MarbelColors.azul : const Color(0xFF1E2672),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(abierta ? Icons.timer_rounded : Icons.lock_rounded, color: MarbelColors.blanco),
        const SizedBox(width: 10),
        Flexible(child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Predicción de una liga
// ---------------------------------------------------------------------------
class _Prediccion extends StatefulWidget {
  const _Prediccion({super.key, required this.ligaId});
  final String ligaId;

  @override
  State<_Prediccion> createState() => _PrediccionState();
}

class _PrediccionState extends State<_Prediccion> {
  String? _lw; // ganador liga
  String? _out; // 5º
  List<String> _fz = []; // finalistas
  String? _ch; // campeón
  String? _t3; // 3er puesto
  bool _cargando = true;
  bool _guardando = false;
  bool _guardado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final filas = await db.from('predicciones').select().eq('liga_id', widget.ligaId);
      for (final f in filas) {
        final e = f['equipo_id'] as String;
        switch (f['tipo']) {
          case 'campeon_liga':
            _lw = e;
          case 'fuera_semis':
            _out = e;
          case 'finalista':
            _fz.add(e);
          case 'campeon':
            _ch = e;
          case 'tercer_puesto':
            _t3 = e;
        }
      }
      _guardado = filas.isNotEmpty;
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await db.from('predicciones').delete().eq('liga_id', widget.ligaId).eq('usuario_id', sesion.usuario!.id);
      final filas = [
        if (_lw != null) {'liga_id': widget.ligaId, 'tipo': 'campeon_liga', 'equipo_id': _lw},
        if (_out != null) {'liga_id': widget.ligaId, 'tipo': 'fuera_semis', 'equipo_id': _out},
        for (final f in _fz) {'liga_id': widget.ligaId, 'tipo': 'finalista', 'equipo_id': f},
        if (_ch != null) {'liga_id': widget.ligaId, 'tipo': 'campeon', 'equipo_id': _ch},
        if (_t3 != null) {'liga_id': widget.ligaId, 'tipo': 'tercer_puesto', 'equipo_id': _t3},
      ];
      if (filas.isNotEmpty) await db.from('predicciones').insert(filas);
      setState(() => _guardado = true);
      if (mounted) avisar(context, '✓ Porra guardada. Puedes cambiarla hasta el cierre.');
    } catch (e) {
      if (mounted) avisar(context, 'No se ha podido guardar: ${mensajeError(e)}', error: true);
    }
    if (mounted) setState(() => _guardando = false);
  }

  void _cambio(VoidCallback f) => setState(() {
        f();
        _guardado = false;
      });

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    final equipos = datos.equiposDeLiga[widget.ligaId] ?? const <String>[];
    if (equipos.length < 4) {
      return const EstadoVacio('Esta liga aún no tiene sus equipos. La porra se abre cuando estén todos.');
    }
    final cerrada = !datos.porraAbierta(widget.ligaId);
    final ancho = esAncho(context);
    final cuatro = equipos.where((e) => e != _out).toList();
    final restantes = _out == null || _fz.length < 2 ? <String>[] : cuatro.where((e) => !_fz.contains(e)).toList();
    final hechas = (_lw != null ? 1 : 0) + (_out != null ? 1 : 0) + _fz.length + (_ch != null ? 1 : 0) + (_t3 != null ? 1 : 0);

    Widget paso(String titulo, String puntos, String ayuda, Widget hijo) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Tarjeta(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
                Text(titulo.toUpperCase(), style: MarbelText.titular(ancho ? 30 : 24).copyWith(fontStyle: FontStyle.normal)),
                Text(puntos, style: const TextStyle(color: MarbelColors.cian, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              Text(ayuda, style: const TextStyle(color: MarbelColors.apagado, fontSize: 14)),
              const SizedBox(height: 12),
              hijo,
            ]),
          ),
        );

    Widget botones(List<String> ids, bool Function(String) elegido, void Function(String) tocar,
        {bool Function(String)? desactivado, Color colorElegido = MarbelColors.cian, String marca = '★'}) {
      return LayoutBuilder(builder: (context, c) {
        final cols = ancho ? 3 : 2;
        final w = (c.maxWidth - 10 * (cols - 1)) / cols;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final id in ids)
            SizedBox(
              width: w,
              child: _BotonEquipo(
                equipoId: id,
                elegido: elegido(id),
                desactivado: cerrada || (desactivado?.call(id) ?? false),
                colorElegido: colorElegido,
                marca: marca,
                onTap: () => tocar(id),
              ),
            ),
        ]);
      });
    }

    final pendienteFinal = _fz.length < 2;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!ancho) ...[_Cierre(ligaId: widget.ligaId), const SizedBox(height: 14)],
      paso('1 · ¿Quién gana la liga?', '+3 pts',
          'Liga de ${equipos.length} equipos: cada uno juega 4 partidos y los 4 primeros pasan a semifinales.',
          botones(equipos, (e) => _lw == e, (e) => _cambio(() {
                _lw = e;
                if (_out == e) _out = null;
              }))),
      paso('2 · ¿Quién se queda sin semis?', '+2 pts', 'Elige el equipo que crees que acabará 5º.',
          botones(equipos, (e) => _out == e, (e) => _cambio(() {
                _out = e;
                _fz.remove(e);
                _ch = null;
                _t3 = null;
              }), desactivado: (e) => e == _lw, colorElegido: const Color(0xFFFF7A85), marca: '✕')),
      paso('3 · Finalistas y campeón', '+4 por finalista · +8 campeón',
          'Semis: 1º vs 4º y 2º vs 3º. Marca los 2 equipos que llegan a la final y después toca tu campeón.',
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_out == null)
              const Text('Elige antes quién se queda sin semis.', style: TextStyle(color: MarbelColors.apagado))
            else
              botones(cuatro, (e) => _fz.contains(e), (e) => _cambio(() {
                    if (_fz.contains(e)) {
                      _fz.remove(e);
                    } else if (_fz.length < 2) {
                      _fz = [..._fz, e];
                    }
                    _ch = null;
                    _t3 = null;
                  }), desactivado: (e) => _fz.length >= 2 && !_fz.contains(e), marca: '✓'),
            const SizedBox(height: 14),
            Text('TU FINAL', style: MarbelText.etiqueta(color: MarbelColors.medio)),
            const SizedBox(height: 8),
            if (pendienteFinal)
              const Text('Marca los dos finalistas para elegir campeón.', style: TextStyle(color: MarbelColors.apagado))
            else
              botones(_fz, (e) => _ch == e, (e) => _cambio(() => _ch = e), colorElegido: MarbelColors.medio, marca: '🏆'),
            const SizedBox(height: 16),
            Text('TU 3ER PUESTO 🥉', style: MarbelText.etiqueta(color: const Color(0xFFE0A060))),
            const SizedBox(height: 8),
            if (restantes.isEmpty)
              const Text('Se elige entre los dos semifinalistas que no llegan a la final.', style: TextStyle(color: MarbelColors.apagado))
            else
              botones(restantes, (e) => _t3 == e, (e) => _cambio(() => _t3 = e), colorElegido: const Color(0xFFCD7F32), marca: '🥉'),
            const SizedBox(height: 8),
            Text('+2 pts por acertar el 3er puesto', style: const TextStyle(color: MarbelColors.cian, fontWeight: FontWeight.w700, fontSize: 13)),
          ])),
      Wrap(spacing: 16, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        BotonCian(cerrada ? 'Porra cerrada' : 'Guardar mi porra', onTap: cerrada ? null : _guardar, cargando: _guardando),
        Text('$hechas de 6 predicciones hechas', style: const TextStyle(color: MarbelColors.apagado)),
        if (_guardado)
          const Text('✓ Guardada · puedes cambiarla hasta el cierre',
              style: TextStyle(color: MarbelColors.elite, fontWeight: FontWeight.w700)),
      ]),
    ]);
  }
}

class _BotonEquipo extends StatelessWidget {
  const _BotonEquipo({
    required this.equipoId,
    required this.elegido,
    required this.desactivado,
    required this.colorElegido,
    required this.marca,
    required this.onTap,
  });
  final String equipoId;
  final bool elegido;
  final bool desactivado;
  final Color colorElegido;
  final String marca;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = datos.equipo(equipoId);
    final fondo = elegido ? colorElegido : (desactivado ? MarbelColors.tarjeta : const Color(0xFF131B6B));
    final texto = elegido ? MarbelColors.fondo : (desactivado ? const Color(0xFF4C55A9) : MarbelColors.blanco);
    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: desactivado ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(children: [
            Opacity(opacity: desactivado && !elegido ? .4 : 1, child: Escudo(e, tamano: 30)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(e?.nombre ?? '?',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: texto)),
            ),
            if (elegido) Text(marca, style: TextStyle(color: texto, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ranking
// ---------------------------------------------------------------------------
class _Ranking extends StatefulWidget {
  const _Ranking({required this.ligaId});
  final String? ligaId;

  @override
  State<_Ranking> createState() => _RankingState();
}

class _RankingState extends State<_Ranking> {
  bool _soloLiga = false;
  Future<List<FilaRanking>>? _f;
  String? _clave;

  Future<List<FilaRanking>> _cargar() async {
    final r = await db.rpc('ranking_porra', params: {'p_liga': _soloLiga ? widget.ligaId : null});
    return (r as List).map((m) => FilaRanking.fromMap(Map<String, dynamic>.from(m as Map))).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clave = '${_soloLiga ? widget.ligaId : 'todas'}-${datos.partidos.where((p) => p.estado == Estado.finalizado).length}';
    if (_clave != clave) {
      _clave = clave;
      _f = _cargar();
    }
    return Tarjeta(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('🏆 RANKING', style: MarbelText.titular(30).copyWith(fontStyle: FontStyle.normal)),
        const SizedBox(height: 8),
        if (widget.ligaId != null)
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChipFiltro(texto: 'General', elegido: !_soloLiga, onTap: () => setState(() => _soloLiga = false)),
            ChipFiltro(texto: 'Esta categoría', elegido: _soloLiga, onTap: () => setState(() => _soloLiga = true)),
          ]),
        const SizedBox(height: 12),
        FutureBuilder<List<FilaRanking>>(
          future: _f,
          builder: (context, s) {
            if (s.hasError) return Text('No se ha podido cargar: ${s.error}', style: const TextStyle(color: MarbelColors.apagado));
            if (!s.hasData) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
            final filas = s.data!;
            if (filas.isEmpty) {
              return const Text('Aún no hay porras. ¡Sé el primero!', style: TextStyle(color: MarbelColors.apagado));
            }
            const medallas = ['🥇', '🥈', '🥉'];
            return Column(children: [
              for (final f in filas.take(50))
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: f.soyYo ? MarbelColors.azul : (f.pos == 1 ? const Color(0xFF1A1FA8) : MarbelColors.fondoAlto),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    SizedBox(
                      width: 32,
                      child: Text(f.pos <= 3 ? medallas[f.pos - 1] : '${f.pos}',
                          style: MarbelText.titular(22).copyWith(fontStyle: FontStyle.normal)),
                    ),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(f.soyYo ? '${f.nombre} (tú)' : f.nombre, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(f.equipo, style: const TextStyle(color: MarbelColors.apagado, fontSize: 12)),
                      ]),
                    ),
                    Text('${f.puntos}', style: MarbelText.titular(24, color: MarbelColors.cian).copyWith(fontStyle: FontStyle.normal)),
                  ]),
                ),
            ]);
          },
        ),
        const SizedBox(height: 6),
        const Text('Solo se muestra el nombre, la inicial del apellido y el equipo.',
            style: TextStyle(color: MarbelColors.apagado, fontSize: 12)),
      ]),
    );
  }
}
