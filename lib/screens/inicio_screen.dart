import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/datos.dart';
import '../data/favoritos.dart';
import '../data/modelos.dart';
import '../theme/app_theme.dart';
import '../widgets/carrusel.dart';
import '../widgets/comunes.dart';
import '../widgets/marco_app.dart';
import '../widgets/partidos.dart';
import '../widgets/torneos.dart';

/// Inicio: la portada.
/// · Un torneo en marcha → su portada (cuenta atrás, avisos, partidos).
/// · Varios → portada de Marbel con un banner por torneo.
/// · Ninguno → portada de Marbel con el aviso de que no hay torneos en marcha.
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ConDatos(
      builder: (context) => ListenableBuilder(
        listenable: favoritos,
        builder: (context, _) {
          final ancho = esAncho(context);
          final hueco = SizedBox(height: ancho ? 56 : 36);
          final visibles = datos.torneosVisibles;
          if (visibles.length == 1) datos.fijarTorneo(visibles.first.id);
          final uno = visibles.length == 1 ? visibles.first : null;
          return PaginaPublica(
            children: [
              // Sin `const` en lo que lee datos: así se repinta en cuanto llega un gol o un aviso.
              if (!ancho) _CabeceraApp(torneo: uno),
              if (uno != null) ...[
                _Hero(uno),
                hueco,
                AnchoMax(child: _Avisos(uno)),
                hueco,
                AnchoMax(child: _EnDirecto([uno])),
              ] else ...[
                _PortadaMarbel(hayTorneos: visibles.isNotEmpty),
                hueco,
                AnchoMax(
                  child: visibles.isEmpty
                      ? const SinTorneos()
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          const TituloSeccion(etiqueta: 'Elige uno para ver toda su información', titulo: 'Torneos en marcha'),
                          const SizedBox(height: 18),
                          BannersTorneos(visibles),
                        ]),
                ),
                if (visibles.isNotEmpty) ...[
                  hueco,
                  AnchoMax(child: _EnDirecto(visibles)),
                ],
              ],
              hueco,
              AnchoMax(child: _Momentazos()),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cabecera móvil (logo + campana de avisos del torneo)
// ---------------------------------------------------------------------------
class _CabeceraApp extends StatelessWidget {
  const _CabeceraApp({this.torneo});
  final Torneo? torneo;

  @override
  Widget build(BuildContext context) {
    final t = torneo;
    final nuevos = t == null ? 0 : datos.avisos.where((a) => a.creado.isAfter(favoritos.vistoHasta)).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
      child: Row(
        children: [
          const LogoMarbel(tamano: 44),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MARBEL', style: MarbelText.titular(22)),
              Text('FOOTBALL CUP', style: MarbelText.etiqueta(size: 13)),
            ],
          ),
          const Spacer(),
          if (t != null)
            Badge(
              isLabelVisible: nuevos > 0,
              label: Text('$nuevos'),
              backgroundColor: MarbelColors.enJuego,
              child: IconButton(
                tooltip: 'Avisos',
                onPressed: () => context.go(rutaTorneo('avisos', t.id)),
                icon: const Icon(Icons.notifications_rounded, size: 28),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Portada de Marbel (cuando no hay un único torneo)
// ---------------------------------------------------------------------------
class _PortadaMarbel extends StatelessWidget {
  const _PortadaMarbel({required this.hayTorneos});
  final bool hayTorneos;

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final texto = Column(
      crossAxisAlignment: ancho ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text('TORNEOS DE FÚTBOL BASE', textAlign: ancho ? TextAlign.start : TextAlign.center, style: MarbelText.etiqueta(size: ancho ? 15 : 12)),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'MARBEL', style: MarbelText.titular(ancho ? 112 : 58)),
            const TextSpan(text: '\n'),
            TextSpan(text: 'FOOTBALL CUP', style: MarbelText.titular(ancho ? 112 : 58, color: MarbelColors.cian)),
          ]),
          textAlign: ancho ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            hayTorneos
                ? 'Fútbol, diversión y competición. Elige tu torneo para ver su calendario, los equipos, la clasificación y La Porra.'
                : 'Fútbol, diversión y competición para equipos federados, escuelas y academias.',
            textAlign: ancho ? TextAlign.start : TextAlign.center,
            style: TextStyle(fontSize: ancho ? 20 : 16, height: 1.5, color: const Color(0xFFC8D0F5)),
          ),
        ),
        if (hayTorneos) ...[
          const SizedBox(height: 22),
          BotonCian('Ver los torneos', icono: Icons.arrow_forward_rounded, onTap: () => context.go('/torneos')),
        ],
      ],
    );
    return _FondoPortada(
      child: ancho
          ? Row(children: [
              Expanded(flex: 6, child: texto),
              const SizedBox(width: 24),
              const Expanded(flex: 5, child: Center(child: LogoMarbel(tamano: 380, brillo: true))),
            ])
          : Column(children: [const LogoMarbel(tamano: 150, brillo: true), const SizedBox(height: 18), texto]),
    );
  }
}

class _FondoPortada extends StatelessWidget {
  const _FondoPortada({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.6, -0.3),
          radius: 1.3,
          colors: [MarbelColors.azul, Color(0xFF1A1FA8), MarbelColors.fondo],
          stops: [0, .35, .85],
        ),
      ),
      child: AnchoMax(
        padding: EdgeInsets.fromLTRB(ancho ? 24 : 16, ancho ? 56 : 24, ancho ? 24 : 16, ancho ? 56 : 32),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Portada de un torneo + cuenta atrás
// ---------------------------------------------------------------------------
class _Hero extends StatelessWidget {
  const _Hero(this.t);
  final Torneo t;

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final p = t.proyecto;
    final lema = p?.lema;
    final nombre = t.nombre.toUpperCase();
    final partes = nombre.split(' ');
    final linea1 = partes.length > 2 ? partes.sublist(0, partes.length - 1).join(' ') : nombre;
    final linea2 = partes.length > 2 ? partes.last : '';

    final texto = Column(
      crossAxisAlignment: ancho ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: ancho ? WrapAlignment.start : WrapAlignment.center,
          children: [
            const Pastilla('Torneo en marcha', fondo: MarbelColors.azul, color: MarbelColors.blanco, tamano: 13),
            pastillaFase(t, tamano: 13),
          ],
        ),
        const SizedBox(height: 14),
        Text((p?.etiqueta ?? 'Fútbol base').toUpperCase(),
            textAlign: ancho ? TextAlign.start : TextAlign.center,
            style: MarbelText.etiqueta(size: ancho ? 15 : 12)),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: linea1, style: MarbelText.titular(ancho ? 112 : 58)),
            if (linea2.isNotEmpty) ...[
              const TextSpan(text: '\n'),
              TextSpan(text: linea2, style: MarbelText.titular(ancho ? 112 : 58, color: MarbelColors.cian)),
            ],
          ]),
          textAlign: ancho ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: 14),
        if (ancho && lema != null && lema.isNotEmpty) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(lema, style: const TextStyle(fontSize: 20, height: 1.5, color: Color(0xFFC8D0F5))),
          ),
          const SizedBox(height: 22),
        ],
        Wrap(
          spacing: 28,
          runSpacing: 12,
          alignment: ancho ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _Dato('Fechas', t.fechasTexto.toUpperCase()),
            if (t.lugar != null) _Dato('Dónde', t.lugar!.toUpperCase()),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          alignment: ancho ? WrapAlignment.start : WrapAlignment.center,
          children: [
            BotonCian('Entrar al torneo', icono: Icons.arrow_forward_rounded, onTap: () => context.go(rutaTorneo('', t.id))),
            BotonContorno('Calendario', onTap: () => context.go(rutaTorneo('calendario', t.id))),
            if (faseDe(t).fase != FaseTorneo.finalizado)
              BotonContorno('Inscribe tu equipo', onTap: () => abrir(enlaceInscripcion(t))),
          ],
        ),
      ],
    );

    return _FondoPortada(
      child: Column(
        children: [
          if (ancho)
            Row(
              children: [
                Expanded(flex: 6, child: texto),
                const SizedBox(width: 24),
                const Expanded(flex: 5, child: Center(child: LogoMarbel(tamano: 420, brillo: true))),
              ],
            )
          else ...[
            const LogoMarbel(tamano: 150, brillo: true),
            const SizedBox(height: 18),
            texto,
          ],
          SizedBox(height: ancho ? 48 : 28),
          _CuentaAtras(t),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.titulo, this.valor);
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    return Column(
      crossAxisAlignment: ancho ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(titulo.toUpperCase(), style: MarbelText.etiqueta(color: MarbelColors.apagado)),
        Text(valor, style: MarbelText.titular(ancho ? 34 : 26).copyWith(fontStyle: FontStyle.normal)),
      ],
    );
  }
}

class _CuentaAtras extends StatefulWidget {
  const _CuentaAtras(this.t);
  final Torneo t;

  @override
  State<_CuentaAtras> createState() => _CuentaAtrasState();
}

class _CuentaAtrasState extends State<_CuentaAtras> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
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
    final t = widget.t;
    final f = faseDe(t);
    final js = datos.jornadasDe(t);
    final ancho = esAncho(context);
    String nombreDia(int i) => i >= 0 && i < js.length ? diaLargo(js[i]) : '';

    if (f.fase == FaseTorneo.finalizado) {
      return Tarjeta(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('TORNEO FINALIZADO', style: MarbelText.titular(ancho ? 48 : 34)),
            const SizedBox(height: 8),
            const Text('¡Gracias a todos los equipos y familias! Consulta los campeones y revive el torneo en la galería.',
                textAlign: TextAlign.center, style: TextStyle(color: MarbelColors.texto2, fontSize: 16)),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.center, children: [
              BotonCian('Resultados finales', onTap: () => context.go(rutaTorneo('calendario', t.id))),
              BotonContorno('Galería', onTap: () => context.go('/galeria')),
            ]),
          ],
        ),
      );
    }

    if (f.fase == FaseTorneo.jugando) {
      return Tarjeta(
        borde: MarbelColors.enJuego,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 14, height: 14, decoration: const BoxDecoration(color: MarbelColors.enJuego, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Flexible(child: Text('¡SE ESTÁ JUGANDO AHORA!', style: MarbelText.titular(ancho ? 48 : 30))),
            ]),
            const SizedBox(height: 8),
            Text(
                f.total > 1
                    ? 'Jornada ${f.jornada + 1} de ${f.total} · ${nombreDia(f.jornada)} · sigue los resultados aquí abajo'
                    : 'Sigue los resultados aquí abajo',
                textAlign: TextAlign.center,
                style: const TextStyle(color: MarbelColors.texto2, fontSize: 16)),
          ],
        ),
      );
    }

    var resta = f.objetivo.difference(DateTime.now());
    if (resta.isNegative) resta = Duration.zero;
    final d = resta.inDays, h = resta.inHours % 24, m = resta.inMinutes % 60, s = resta.inSeconds % 60;
    String dos(int x) => x.toString().padLeft(2, '0');
    var unidades = [
      ('$d', d == 1 ? 'DÍA' : 'DÍAS'),
      (dos(h), 'HORAS'),
      (dos(m), 'MIN'),
      (dos(s), 'SEG'),
    ];
    if (d == 0) unidades = unidades.sublist(1);
    if (d == 0 && h == 0) unidades = unidades.sublist(1);

    return Column(
      children: [
        Text(f.fase == FaseTorneo.antes ? 'EMPIEZA EN' : 'PRÓXIMA JORNADA EN', style: MarbelText.etiqueta(size: 16)),
        const SizedBox(height: 4),
        Text(
          f.fase == FaseTorneo.antes
              ? '${nombreDia(0)} · ${hhmm(f.objetivo)}'
              : '${nombreDia(f.jornada)} · ${hhmm(f.objetivo)} · ya se jugaron ${f.jornada} de ${f.total} jornadas',
          textAlign: TextAlign.center,
          style: const TextStyle(color: MarbelColors.texto2, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Row(
            children: [
              for (var i = 0; i < unidades.length; i++) ...[
                if (i > 0) SizedBox(width: ancho ? 14 : 8),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(builder: (context, c) {
                      return Container(
                        decoration: BoxDecoration(
                          color: MarbelColors.tarjeta,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: MarbelColors.borde),
                        ),
                        padding: EdgeInsets.all(c.maxWidth * .06),
                        child: Column(
                          children: [
                            Expanded(
                              child: FittedBox(
                                child: Text(unidades[i].$1,
                                    style: MarbelText.titular(120, color: i == 0 ? MarbelColors.cian : MarbelColors.blanco)),
                              ),
                            ),
                            Text(unidades[i].$2, style: MarbelText.etiqueta(color: MarbelColors.apagado, size: ancho ? 15 : 11)),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Avisos del torneo (los 3 últimos)
// ---------------------------------------------------------------------------
class _Avisos extends StatelessWidget {
  const _Avisos(this.t);
  final Torneo t;

  @override
  Widget build(BuildContext context) {
    final lista = datos.avisos.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TituloSeccion(
          etiqueta: 'De la organización',
          titulo: 'Avisos',
          derecha: TextButton(onPressed: () => context.go(rutaTorneo('avisos', t.id)), child: const Text('Ver todos →')),
        ),
        const SizedBox(height: 14),
        if (lista.isEmpty)
          const EstadoVacio('Aquí aparecerán los avisos de la organización: cambios de horario, '
              'campos, entregas de premios…', icono: Icons.campaign_outlined)
        else
          for (final a in lista) ...[TarjetaAviso(a), const SizedBox(height: 10)],
      ],
    );
  }
}

class TarjetaAviso extends StatelessWidget {
  const TarjetaAviso(this.a, {super.key});
  final Aviso a;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      borde: a.fijado ? MarbelColors.medio : null,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LogoMarbel(tamano: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Marbel Cup', style: TextStyle(fontWeight: FontWeight.w800)),
                    Text('· ${cuando(a.creado)}', style: const TextStyle(color: MarbelColors.apagado)),
                    if (a.fijado)
                      const Pastilla('Fijado', fondo: MarbelColors.medio, color: Color(0xFF1A1400), tamano: 11),
                    if (a.ambito != 'todos' && a.ambitoRef != null)
                      Pastilla(a.ambitoRef!, fondo: const Color(0xFF1E2672), color: MarbelColors.texto2, tamano: 11),
                  ],
                ),
                const SizedBox(height: 6),
                Text(a.texto, style: const TextStyle(fontSize: 16, height: 1.4)),
                if (a.imagenes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ImagenesAviso(a.imagenes),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// En directo (o los próximos partidos) de los torneos en marcha
// ---------------------------------------------------------------------------
class _EnDirecto extends StatelessWidget {
  const _EnDirecto(this.torneos);
  final List<Torneo> torneos;

  @override
  Widget build(BuildContext context) {
    final todos = datos.partidosDe(torneos);
    var lista = todos.where((p) => p.estado == Estado.enJuego).toList();
    final hayDirecto = lista.isNotEmpty;
    if (!hayDirecto) {
      // Si no hay nada jugándose, los próximos partidos.
      final ahora = DateTime.now();
      lista = todos
          .where((p) => p.estado == Estado.programado && p.horaReal.isAfter(ahora.subtract(const Duration(minutes: 30))))
          .take(4)
          .toList();
    }
    if (lista.isEmpty && torneos.length > 1) return const SizedBox.shrink();
    final ancho = esAncho(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TituloSeccion(
          etiqueta: hayDirecto ? '● Ahora mismo' : 'Lo próximo',
          titulo: hayDirecto ? 'En directo' : 'Próximos partidos',
          derecha: torneos.length == 1
              ? TextButton(
                  onPressed: () => context.go(rutaTorneo('calendario', torneos.first.id)),
                  child: const Text('Todos los partidos →'))
              : null,
        ),
        const SizedBox(height: 14),
        if (lista.isEmpty)
          const EstadoVacio('Cuando se publique el calendario, aquí verás los partidos en juego con su marcador al momento.',
              icono: Icons.sports_soccer_rounded)
        else
          LayoutBuilder(builder: (context, c) {
            final cols = ancho ? 2 : 1;
            final w = (c.maxWidth - 14 * (cols - 1)) / cols;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [for (final p in lista) SizedBox(width: w, child: TarjetaPartido(p))],
            );
          }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Momentazos (carrusel de fotos)
// ---------------------------------------------------------------------------
class _Momentazos extends StatelessWidget {
  const _Momentazos();

  @override
  Widget build(BuildContext context) {
    final fotos = datos.fotos.take(8).toList();
    if (fotos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TituloSeccion(
          etiqueta: 'Ediciones anteriores',
          titulo: 'Momentazos',
          derecha: TextButton(onPressed: () => context.go('/galeria'), child: const Text('Ver galería →')),
        ),
        const SizedBox(height: 16),
        Carrusel(fotos: fotos),
      ],
    );
  }
}
