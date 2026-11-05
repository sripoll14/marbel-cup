import 'package:flutter/material.dart';

import '../data/datos.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/marco_app.dart';

/// Estadísticas calculadas solas a partir de los resultados y goles.
class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  String _grupo = 'Todas';
  static const _grupos = ['Todas', 'Prebenjamín', 'Benjamín', 'Alevín', 'Infantil F11', 'Sub 12', 'Infantil F8'];

  @override
  Widget build(BuildContext context) {
    return ConDatos(builder: (context) {
      final ancho = esAncho(context);
      final ps = datos.finalizados(grupoCategoria: _grupo == 'Todas' ? null : _grupo);
      final ligaIds = ps.map((p) => p.ligaId).toSet();
      final goles = ps.fold<int>(0, (s, p) => s + p.golesLocal! + p.golesVisitante!);
      final empates = ps.where((p) => p.golesLocal == p.golesVisitante).length;
      final media = ps.isEmpty ? 0.0 : goles / ps.length;

      // Goles a favor / en contra por equipo
      final gf = <String, int>{}, gc = <String, int>{}, cero = <String, int>{};
      for (final p in ps) {
        if (p.localId == null || p.visitanteId == null) continue;
        gf[p.localId!] = (gf[p.localId!] ?? 0) + p.golesLocal!;
        gf[p.visitanteId!] = (gf[p.visitanteId!] ?? 0) + p.golesVisitante!;
        gc[p.localId!] = (gc[p.localId!] ?? 0) + p.golesVisitante!;
        gc[p.visitanteId!] = (gc[p.visitanteId!] ?? 0) + p.golesLocal!;
        if (p.golesVisitante == 0) cero[p.localId!] = (cero[p.localId!] ?? 0) + 1;
        if (p.golesLocal == 0) cero[p.visitanteId!] = (cero[p.visitanteId!] ?? 0) + 1;
      }
      List<MapEntry<String, int>> top(Map<String, int> m, {bool menor = false}) =>
          (m.entries.toList()..sort((a, b) => menor ? a.value.compareTo(b.value) : b.value.compareTo(a.value)))
              .take(5)
              .toList();
      final masGoleadores = top(gf);
      final mayorGoleada = ps.isEmpty
          ? null
          : (ps.toList()
                ..sort((a, b) => (b.golesLocal! - b.golesVisitante!).abs().compareTo((a.golesLocal! - a.golesVisitante!).abs())))
              .first;

      // Goleadores (jugadores): "Nombre I." + equipo
      final idsPs = ps.map((p) => p.id).toSet();
      final porJugador = <String, int>{};
      for (final g in datos.goles.where((g) => idsPs.contains(g.partidoId))) {
        final k = '${g.jugador}|${g.equipoId}';
        porJugador[k] = (porJugador[k] ?? 0) + 1;
      }
      final pichichis = (porJugador.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();

      // Rachas
      final equiposConPartidos = {...gf.keys};
      final rachas = equiposConPartidos.map((e) => (e, datos.rachaDe(e))).toList()
        ..sort((a, b) => b.$2.racha.compareTo(a.$2.racha));

      String ligaTexto(String equipoId) {
        final l = datos.ligasDeEquipo(equipoId).where((x) => ligaIds.contains(x.id)).firstOrNull;
        return l == null ? '' : datos.nombreLiga(l.id);
      }

      final premios = <(String, String, String?, String, Color)>[
        if (masGoleadores.isNotEmpty)
          ('⚽', 'Más goleador', masGoleadores.first.key, '${masGoleadores.first.value} goles', MarbelColors.medio),
        if (cero.isNotEmpty)
          ('🧤', 'Porterías a cero', top(cero).first.key, '${top(cero).first.value} partidos sin encajar', MarbelColors.elite),
        if (rachas.isNotEmpty && rachas.first.$2.racha > 0)
          ('🔥', 'Mejor racha', rachas.first.$1, '${rachas.first.$2.racha} victorias seguidas', MarbelColors.iniciacion),
        if (gc.isNotEmpty)
          ('🛡️', 'Menos goleado', top(gc, menor: true).first.key, '${top(gc, menor: true).first.value} goles en contra', MarbelColors.femenino),
        if (mayorGoleada != null)
          ('💥', 'Mayor goleada', mayorGoleada.ganadorId,
              '${mayorGoleada.golesLocal} – ${mayorGoleada.golesVisitante} · ${datos.nombreEquipo(mayorGoleada.localId)} vs ${datos.nombreEquipo(mayorGoleada.visitanteId)}',
              MarbelColors.medio),
      ];

      final cifras = [
        ('$goles', '⚽ Goles totales'),
        ('${ps.length}', '🏟️ Partidos jugados'),
        (media.toStringAsFixed(1).replaceAll('.', ','), '📈 Goles por partido'),
        ('$empates', '🤝 Empates'),
      ];

      final contenido = <Widget>[
        FilaChips(children: [
          for (final g in _grupos) ChipFiltro(texto: g, elegido: _grupo == g, onTap: () => setState(() => _grupo = g)),
        ]),
        const SizedBox(height: 16),
        if (ps.isEmpty)
          const EstadoVacio('Las estadísticas se calculan solas en cuanto haya resultados. ¡Vuelve durante el torneo!',
              icono: Icons.bar_chart_rounded)
        else ...[
          LayoutBuilder(builder: (context, c) {
            final cols = ancho ? 4 : 2;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final (i, (v, t)) in cifras.indexed)
                SizedBox(
                  width: w,
                  child: Tarjeta(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(v, style: MarbelText.titular(ancho ? 54 : 40, color: i == 0 ? MarbelColors.cian : MarbelColors.blanco)),
                      Text(t.toUpperCase(), style: MarbelText.etiqueta(color: MarbelColors.apagado, size: 12)),
                    ]),
                  ),
                ),
            ]);
          }),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final cols = ancho ? 3 : (c.maxWidth > 500 ? 2 : 1);
            final w = (c.maxWidth - 14 * (cols - 1)) / cols;
            return Wrap(spacing: 14, runSpacing: 14, children: [
              for (final (emo, titulo, eq, valor, color) in premios)
                SizedBox(
                  width: w,
                  child: Tarjeta(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(emo, style: const TextStyle(fontSize: 34)),
                        const Spacer(),
                        if (eq != null && ligaTexto(eq).isNotEmpty)
                          Pastilla(ligaTexto(eq), fondo: color, color: MarbelColors.fondo, tamano: 11),
                      ]),
                      const SizedBox(height: 8),
                      Text(titulo.toUpperCase(), style: MarbelText.etiqueta(color: MarbelColors.apagado, size: 13)),
                      Text(datos.nombreEquipo(eq, siNo: '—').toUpperCase(),
                          style: MarbelText.titular(30).copyWith(fontStyle: FontStyle.normal)),
                      const SizedBox(height: 4),
                      Text(valor, style: const TextStyle(color: MarbelColors.cian, fontWeight: FontWeight.w600, fontSize: 16)),
                    ]),
                  ),
                ),
            ]);
          }),
          const SizedBox(height: 16),
          _dosColumnas(ancho, [
            Tarjeta(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('⚽ EQUIPOS MÁS GOLEADORES', style: MarbelText.titular(24).copyWith(fontStyle: FontStyle.normal)),
                const SizedBox(height: 12),
                for (final (i, e) in masGoleadores.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      SizedBox(width: 22, child: Text('${i + 1}', style: const TextStyle(color: MarbelColors.apagado, fontWeight: FontWeight.w800))),
                      SizedBox(
                        width: ancho ? 200 : 130,
                        child: Text(datos.nombreEquipo(e.key), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: e.value / masGoleadores.first.value,
                            minHeight: 24,
                            backgroundColor: MarbelColors.fondo,
                            color: MarbelColors.azul,
                          ),
                        ),
                      ),
                      SizedBox(width: 40, child: Text('${e.value}', textAlign: TextAlign.right, style: MarbelText.titular(22).copyWith(fontStyle: FontStyle.normal))),
                    ]),
                  ),
              ]),
            ),
            Tarjeta(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('👟 MÁXIMOS GOLEADORES', style: MarbelText.titular(24).copyWith(fontStyle: FontStyle.normal)),
                const SizedBox(height: 12),
                if (pichichis.isEmpty)
                  const Text('Aún no hay goles con autor. La mesa de cada sede los apunta al meter el resultado.',
                      style: TextStyle(color: MarbelColors.apagado))
                else
                  for (final (i, e) in pichichis.indexed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: MarbelColors.fondo, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        SizedBox(width: 30, child: Text(['🥇', '🥈', '🥉', '4', '5'][i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 20))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.key.split('|').first, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            Text(datos.nombreEquipo(e.key.split('|').last), style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
                          ]),
                        ),
                        Text('${e.value}', style: MarbelText.titular(26, color: MarbelColors.cian).copyWith(fontStyle: FontStyle.normal)),
                        const Text(' goles', style: TextStyle(color: MarbelColors.apagado, fontSize: 13)),
                      ]),
                    ),
              ]),
            ),
            Tarjeta(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🔥 EN RACHA', style: MarbelText.titular(24).copyWith(fontStyle: FontStyle.normal)),
                const SizedBox(height: 12),
                for (final (e, r) in rachas.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      SizedBox(
                        width: ancho ? 200 : 120,
                        child: Text(datos.nombreEquipo(e), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Expanded(
                        child: Wrap(spacing: 6, children: [
                          for (final x in r.ultimos) _Resultado(x),
                        ]),
                      ),
                      Text(r.racha > 0 ? '${r.racha} seguidas' : '', style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
                    ]),
                  ),
                const SizedBox(height: 6),
                const Wrap(spacing: 14, children: [
                  Text.rich(TextSpan(children: [TextSpan(text: 'V ', style: TextStyle(color: MarbelColors.elite, fontWeight: FontWeight.w800)), TextSpan(text: 'victoria')]), style: TextStyle(color: MarbelColors.apagado, fontSize: 13)),
                  Text.rich(TextSpan(children: [TextSpan(text: 'E ', style: TextStyle(color: MarbelColors.medio, fontWeight: FontWeight.w800)), TextSpan(text: 'empate')]), style: TextStyle(color: MarbelColors.apagado, fontSize: 13)),
                  Text.rich(TextSpan(children: [TextSpan(text: 'D ', style: TextStyle(color: Color(0xFFFF7A85), fontWeight: FontWeight.w800)), TextSpan(text: 'derrota')]), style: TextStyle(color: MarbelColors.apagado, fontSize: 13)),
                ]),
              ]),
            ),
          ]),
        ],
        const SizedBox(height: 12),
        const Text('Se calculan solas a partir de los resultados que mete el personal. De cada jugador o jugadora solo mostramos su nombre, la inicial del apellido y su equipo.',
            style: TextStyle(color: MarbelColors.apagado, fontSize: 13)),
      ];

      if (!ancho) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const CabeceraMovil('Estadísticas', atras: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: contenido),
            ),
          ],
        );
      }
      return PaginaPublica(children: [
        const SizedBox(height: 48),
        const AnchoMax(
          child: TituloSeccion(
            etiqueta: 'IV Torneo Navideño · se actualiza con cada resultado',
            titulo: 'Estadísticas',
            tamano: 80,
          ),
        ),
        const SizedBox(height: 20),
        AnchoMax(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: contenido)),
      ]);
    });
  }

  Widget _dosColumnas(bool ancho, List<Widget> hijos) {
    if (!ancho) {
      return Column(children: [
        for (final h in hijos) Padding(padding: const EdgeInsets.only(bottom: 14), child: SizedBox(width: double.infinity, child: h)),
      ]);
    }
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 16) / 2;
      return Wrap(spacing: 16, runSpacing: 16, children: [for (final h in hijos) SizedBox(width: w, child: h)]);
    });
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado(this.r);
  final String r;

  @override
  Widget build(BuildContext context) {
    final (fondo, color) = switch (r) {
      'V' => (MarbelColors.elite, const Color(0xFF03220F)),
      'E' => (MarbelColors.medio, const Color(0xFF1A1400)),
      _ => (const Color(0xFFFF7A85), const Color(0xFF2A0008)),
    };
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(8)),
      child: Text(r, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
    );
  }
}
