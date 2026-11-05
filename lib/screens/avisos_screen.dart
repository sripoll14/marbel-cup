import 'package:flutter/material.dart';

import '../data/datos.dart';
import '../data/favoritos.dart';
import '../data/modelos.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/marco_app.dart';
import 'inicio_screen.dart' show TarjetaAviso;

/// Avisos: los de la organización y los "para ti" (de tus equipos favoritos),
/// más qué quieres recibir.
class AvisosScreen extends StatefulWidget {
  const AvisosScreen({super.key});

  @override
  State<AvisosScreen> createState() => _AvisosScreenState();
}

class _AvisosScreenState extends State<AvisosScreen> {
  bool _paraTi = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => favoritos.marcarVistos());
  }

  /// Avisos personales generados a partir de los partidos de tus equipos.
  List<(String, String, String, DateTime, bool)> _paraTiLista() {
    final r = <(String, String, String, DateTime, bool)>[];
    final ahora = DateTime.now();
    final p = favoritos.preferencias;
    for (final eId in favoritos.equipos) {
      final nombre = datos.nombreEquipo(eId);
      for (final m in datos.partidosDeEquipo(eId)) {
        final rival = datos.nombreEquipo(m.localId == eId ? m.visitanteId : m.localId);
        final sede = datos.sede(m.sedeId);
        final donde = '${sede?.nombre ?? ''}${m.campo == null ? '' : ', ${m.campo}'}';
        final falta = m.horaReal.difference(ahora);
        if (p[0] && m.estado == Estado.programado && !falta.isNegative && falta.inHours < 24) {
          r.add(('⏰', '$nombre juega ${falta.inMinutes < 90 ? 'dentro de ${falta.inMinutes} min' : 'hoy a las ${hhmm(m.horaReal)}'}',
              '${hhmm(m.horaReal)} · $donde · contra $rival', m.horaReal.subtract(const Duration(hours: 1)), falta.inMinutes < 90));
        }
        if (p[0] && m.retrasoMin > 0 && m.estado == Estado.programado) {
          r.add(('🕒', 'Retraso en el partido de $nombre', 'Empieza a las ${hhmm(m.horaReal)} (${m.retrasoMin} min tarde) · $donde',
              m.actualizado ?? m.hora, true));
        }
        if (p[1] && m.estado == Estado.finalizado && m.tieneMarcador) {
          r.add(('✅', 'Final: ${datos.nombreEquipo(m.localId)} ${m.golesLocal} – ${m.golesVisitante} ${datos.nombreEquipo(m.visitanteId)}',
              datos.nombreLiga(m.ligaId), m.actualizado ?? m.hora, false));
        }
        if (p[1] && m.estado == Estado.enJuego) {
          r.add(('🔴', '$nombre está jugando ahora', '${datos.nombreEquipo(m.localId)} ${m.golesLocal ?? 0} – ${m.golesVisitante ?? 0} ${datos.nombreEquipo(m.visitanteId)} · $donde',
              m.horaReal, true));
        }
      }
      if (p[2]) {
        final racha = datos.rachaDe(eId).racha;
        if (racha >= 3) r.add(('🔥', '$nombre está en racha', '$racha victorias seguidas. ¡Imparables!', ahora, true));
      }
    }
    if (p[4]) {
      for (final l in datos.ligasActuales) {
        final c = datos.cierrePorra(l.id);
        if (c != null && c.isAfter(ahora) && c.difference(ahora).inHours < 24) {
          r.add(('🏆', 'La Porra de ${datos.nombreLiga(l.id)} cierra pronto', 'A las ${hhmm(c)} · ¡haz tu predicción!', ahora, false));
        }
      }
    }
    r.sort((a, b) => b.$4.compareTo(a.$4));
    return r;
  }

  @override
  Widget build(BuildContext context) {
    return ConDatos(
      builder: (context) => ListenableBuilder(
        listenable: favoritos,
        builder: (context, _) {
          final ancho = esAncho(context);
          final generales = favoritos.preferencias[3] ? datos.avisos : datos.avisos.where((a) => a.ambito != 'todos').toList();
          final mios = _paraTiLista();
          final segs = Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: MarbelColors.tarjeta, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              for (final (v, t) in [(false, 'Organización'), (true, 'Para ti · ${mios.length}')])
                Expanded(
                  child: Material(
                    color: _paraTi == v ? MarbelColors.azul : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _paraTi = v),
                      child: SizedBox(
                        height: 42,
                        child: Center(
                          child: Text(t,
                              style: TextStyle(fontWeight: FontWeight.w700, color: _paraTi == v ? MarbelColors.blanco : MarbelColors.apagado)),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          );

          final lista = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!_paraTi) ...[
              if (generales.isEmpty)
                const EstadoVacio('Aún no hay avisos de la organización.', icono: Icons.campaign_outlined)
              else
                for (final a in generales) Padding(padding: const EdgeInsets.only(bottom: 10), child: TarjetaAviso(a)),
            ] else ...[
              if (favoritos.equipos.isEmpty)
                const EstadoVacio('Sigue a tus equipos con ★ (en Equipos) y aquí verás sus horarios, cambios de campo, resultados y rachas.',
                    icono: Icons.star_outline_rounded)
              else if (mios.isEmpty)
                const EstadoVacio('Nada nuevo de tus equipos por ahora.')
              else
                for (final (emo, titulo, texto, cuando_, destacado) in mios)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Tarjeta(
                      borde: destacado ? MarbelColors.cian : null,
                      padding: const EdgeInsets.all(14),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(emo, style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(texto, style: const TextStyle(color: MarbelColors.texto2)),
                            const SizedBox(height: 4),
                            Text(cuando(cuando_), style: const TextStyle(color: MarbelColors.apagado, fontSize: 12)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
            ],
          ]);

          final preferencias = Tarjeta(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('QUÉ QUIERO RECIBIR', style: MarbelText.titular(24).copyWith(fontStyle: FontStyle.normal)),
              const SizedBox(height: 4),
              const Text('Se guarda en este dispositivo.', style: TextStyle(color: MarbelColors.apagado, fontSize: 13)),
              const SizedBox(height: 8),
              for (var i = 0; i < Favoritos.preferenciasTexto.length; i++)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: favoritos.preferencias[i],
                  onChanged: (v) => favoritos.cambiarPreferencia(i, v),
                  activeTrackColor: MarbelColors.elite,
                  title: Text(Favoritos.preferenciasTexto[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
            ]),
          );

          if (!ancho) {
            return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
              const CabeceraMovil('Avisos', atras: true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  segs,
                  const SizedBox(height: 14),
                  lista,
                  const SizedBox(height: 14),
                  preferencias,
                ]),
              ),
            ]);
          }
          return PaginaPublica(children: [
            const SizedBox(height: 48),
            const AnchoMax(child: TituloSeccion(etiqueta: 'Avisos y notificaciones', titulo: 'Avisos', tamano: 80)),
            const SizedBox(height: 20),
            AnchoMax(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 62, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [segs, const SizedBox(height: 14), lista])),
                const SizedBox(width: 20),
                Expanded(flex: 38, child: preferencias),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
