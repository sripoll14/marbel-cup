import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/contenido.dart';
import '../theme/app_theme.dart';

/// Mapa de la Comunidad Valenciana con zoom a la Vega Baja y las 4 sedes,
/// más el panel lateral con los botones de cada sede y su ficha.
/// Es el mismo mapa del diseño (dibujo en un lienzo de 380 x 620).
class MapaSedes extends StatefulWidget {
  const MapaSedes({super.key, required this.sedes});

  /// Filas de la tabla `sedes`.
  final List<Map<String, dynamic>> sedes;

  @override
  State<MapaSedes> createState() => _MapaSedesState();
}

class _MapaSedesState extends State<MapaSedes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _zoom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final Animation<double> _t =
      CurvedAnimation(parent: _zoom, curve: const Cubic(.2, .7, .2, 1));
  int _sel = 0;

  void _ampliar() => _zoom.forward();
  void _alejar() => _zoom.reverse();

  void _elegir(int i, {bool ampliar = false}) {
    setState(() => _sel = i);
    if (ampliar) _ampliar();
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final ancho = c.maxWidth >= 900;
      final mapa = SizedBox(
        height: ancho ? 680 : 480,
        child: _Mapa(
          t: _t,
          sedes: widget.sedes,
          sel: _sel,
          onElegir: (i) => _elegir(i),
          onAmpliar: _ampliar,
          onAlejar: _alejar,
        ),
      );
      final panel = _Panel(
        sedes: widget.sedes,
        sel: _sel,
        onElegir: (i) => _elegir(i, ampliar: true),
      );
      if (ancho) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 64, child: mapa),
            const SizedBox(width: 20),
            Expanded(flex: 36, child: panel),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [mapa, const SizedBox(height: 16), panel],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Geometría del dibujo (coordenadas del lienzo 380 x 620)
// ---------------------------------------------------------------------------

const _contorno = <Offset>[
  Offset(330, 64), Offset(289, 45), Offset(250, 20), Offset(218, 12),
  Offset(195, 40), Offset(164, 60), Offset(120, 60), Offset(133, 110),
  Offset(101, 150), Offset(117, 180), Offset(94, 200), Offset(55, 220),
  Offset(16, 260), Offset(23, 290), Offset(62, 320), Offset(78, 380),
  Offset(109, 420), Offset(101, 450), Offset(86, 480), Offset(94, 520),
  Offset(101, 550), Offset(109, 580), Offset(140, 600), Offset(137, 600),
  Offset(152, 574), Offset(172, 532), Offset(183, 502), Offset(222, 470),
  Offset(265, 442), Offset(293, 424), Offset(273, 402), Offset(234, 374),
  Offset(223, 336), Offset(208, 280), Offset(223, 236), Offset(254, 176),
  Offset(279, 150), Offset(320, 98),
];

/// Límites entre provincias (líneas discontinuas).
const _limites = [
  [Offset(117, 180), Offset(228, 222)],
  [Offset(101, 450), Offset(248, 386)],
];

/// Río Segura: curvas de Bézier (inicio, control 1, control 2, fin)...
const _rio = [
  Offset(98, 555),
  Offset(101, 553), Offset(103, 553), Offset(106, 552),
  Offset(109, 551), Offset(114, 551), Offset(118, 550.5),
  Offset(122, 550), Offset(124, 548.5), Offset(127, 548),
  Offset(130, 547.5), Offset(141, 551), Offset(147.4, 552),
];

const _kZoom = 12.0; // cuánto se amplía la Vega Baja
const _centroVB = Offset(113, 546); // punto de la Vega Baja que queda en el centro

/// Pasa longitud/latitud a coordenadas del dibujo.
Offset _proyectar(double lon, double lat) =>
    Offset(156 * (lon + 1.6), 200 * (40.85 - lat));

/// Convierte un punto del dibujo a píxeles de pantalla según el zoom (t: 0-1).
class _Vista {
  _Vista(Size tam, this.t)
      : s = math.min(tam.width / 380, tam.height / 620),
        centro = Offset(tam.width / 2, tam.height / 2);

  final double s;
  final double t;
  final Offset centro;

  double get escala => 1 + t * (_kZoom - 1);

  Offset aPantalla(Offset p) {
    // Sin zoom: el dibujo centrado. Con zoom: el centro de la Vega Baja al centro.
    const medio = Offset(190, 310);
    final foco = Offset.lerp(medio, _centroVB, t)!;
    return centro + (p - foco) * (s * escala);
  }
}

// ---------------------------------------------------------------------------
// Mapa
// ---------------------------------------------------------------------------

class _Mapa extends StatelessWidget {
  const _Mapa({
    required this.t,
    required this.sedes,
    required this.sel,
    required this.onElegir,
    required this.onAmpliar,
    required this.onAlejar,
  });

  final Animation<double> t;
  final List<Map<String, dynamic>> sedes;
  final int sel;
  final ValueChanged<int> onElegir;
  final VoidCallback onAmpliar;
  final VoidCallback onAlejar;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F45),
          border: Border.all(color: MarbelColors.borde),
          borderRadius: BorderRadius.circular(24),
        ),
        child: AnimatedBuilder(
          animation: t,
          builder: (context, _) => LayoutBuilder(builder: (context, c) {
            final tam = Size(c.maxWidth, c.maxHeight);
            final v = _Vista(tam, t.value);
            final ampliado = t.value > .5;
            final opPins = ((t.value - .4) / .6).clamp(0.0, 1.0);

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Dibujo
                Positioned.fill(
                  child: GestureDetector(
                    onTap: ampliado ? null : onAmpliar,
                    child: MouseRegion(
                      cursor: ampliado
                          ? MouseCursor.defer
                          : SystemMouseCursors.zoomIn,
                      child: CustomPaint(painter: _PintorMapa(v)),
                    ),
                  ),
                ),
                // Mar Mediterráneo
                Positioned(
                  right: 18,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: Text('MAR MEDITERRÁNEO',
                          style: MarbelText.etiqueta(
                              color: const Color(0xFF3A44B8), size: 18)),
                    ),
                  ),
                ),
                if (ampliado) ...[
                  Positioned(
                    left: 24,
                    top: 76,
                    child: Opacity(
                      opacity: opPins,
                      child: Text('VEGA BAJA DEL SEGURA',
                          style: MarbelText.titular(22,
                              color: MarbelColors.texto2)),
                    ),
                  ),
                ],
                // Chinchetas de las sedes
                if (opPins > 0)
                  for (var i = 0; i < sedes.length; i++)
                    if (sedes[i]['lat'] != null && sedes[i]['lon'] != null)
                      _Chincheta(
                        pos: v.aPantalla(_proyectar(
                          (sedes[i]['lon'] as num).toDouble(),
                          (sedes[i]['lat'] as num).toDouble(),
                        )),
                        nombre: sedes[i]['nombre'] as String,
                        elegida: i == sel,
                        opacidad: opPins,
                        onElegir: () => onElegir(i),
                      ),
                // Botón de zoom
                Positioned(
                  left: 20,
                  top: 20,
                  child: ampliado
                      ? _BotonMapa(
                          texto: 'Ver toda la Comunidad',
                          icono: Icons.zoom_out_rounded,
                          fondo: MarbelColors.tarjeta,
                          onTap: onAlejar,
                        )
                      : _BotonMapa(
                          texto: 'Ampliar Vega Baja',
                          icono: Icons.zoom_in_rounded,
                          fondo: MarbelColors.enJuego,
                          onTap: onAmpliar,
                        ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _PintorMapa extends CustomPainter {
  _PintorMapa(this.v);
  final _Vista v;

  @override
  void paint(Canvas canvas, Size size) {
    final p = v.aPantalla;

    // Contorno de la Comunidad con brillo cian
    final forma = Path()..addPolygon(_contorno.map(p).toList(), true);
    canvas.drawPath(forma, Paint()..color = const Color(0xFF131B6B));
    canvas.drawPath(
      forma,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0x998FF4FA)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      forma,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF8FF4FA),
    );

    // Límites de provincia (discontinuos)
    final discontinua = Paint()
      ..color = const Color(0xFF4C55C9)
      ..strokeWidth = 2;
    for (final l in _limites) {
      _lineaDiscontinua(canvas, p(l[0]), p(l[1]), discontinua);
    }

    // Río Segura (solo se ve al ampliar)
    final opRio = ((v.t - .4) / .6).clamp(0.0, 1.0);
    if (opRio > 0) {
      final rio = Path()..moveTo(p(_rio[0]).dx, p(_rio[0]).dy);
      for (var i = 1; i + 2 < _rio.length; i += 3) {
        final a = p(_rio[i]), b = p(_rio[i + 1]), c = p(_rio[i + 2]);
        rio.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
      }
      canvas.drawPath(
        rio,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = MarbelColors.azul.withValues(alpha: opRio),
      );
      _texto(canvas, 'Río Segura', p(const Offset(139, 556)) + const Offset(0, 8),
          TextStyle(
              color: const Color(0xFF6E78E0).withValues(alpha: opRio),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic));
    }

    // Rótulos de provincias y marca de la Vega Baja (solo sin ampliar)
    final opFuera = (1 - v.t * 2.5).clamp(0.0, 1.0);
    if (opFuera > 0) {
      final tam = 20 * v.s;
      TextStyle rotulo(Color c, FontWeight w) => TextStyle(
            fontFamily: 'BarlowCondensed',
            fontWeight: w,
            fontSize: tam,
            color: c.withValues(alpha: opFuera),
          );
      _texto(canvas, 'CASTELLÓN', p(const Offset(232, 104)),
          rotulo(MarbelColors.apagado, FontWeight.w700));
      _texto(canvas, 'VALENCIA', p(const Offset(150, 304)),
          rotulo(MarbelColors.apagado, FontWeight.w700));
      _texto(canvas, 'ALICANTE', p(const Offset(180, 484)),
          rotulo(MarbelColors.apagado, FontWeight.w700));
      _texto(canvas, 'VEGA BAJA', p(const Offset(162, 584)),
          rotulo(const Color(0xFFFF7A85), FontWeight.w800));

      final rojo = MarbelColors.enJuego.withValues(alpha: opFuera);
      final a = p(const Offset(100, 528)), b = p(const Offset(152, 588));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromPoints(a, b), Radius.circular(10 * v.s)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = rojo,
      );
      canvas.drawCircle(p(const Offset(122, 556)), 7 * v.s, Paint()..color = rojo);
    }
  }

  void _lineaDiscontinua(Canvas canvas, Offset a, Offset b, Paint paint) {
    const trazo = 6.0, hueco = 6.0;
    final d = (b - a).distance;
    if (d == 0) return;
    final dir = (b - a) / d;
    for (var x = 0.0; x < d; x += trazo + hueco) {
      canvas.drawLine(a + dir * x, a + dir * math.min(x + trazo, d), paint);
    }
  }

  void _texto(Canvas canvas, String s, Offset arribaIzq, TextStyle estilo) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: estilo),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, arribaIzq);
  }

  @override
  bool shouldRepaint(_PintorMapa old) => old.v.t != v.t || old.v.s != v.s;
}

class _Chincheta extends StatelessWidget {
  const _Chincheta({
    required this.pos,
    required this.nombre,
    required this.elegida,
    required this.opacidad,
    required this.onElegir,
  });

  final Offset pos;
  final String nombre;
  final bool elegida;
  final double opacidad;
  final VoidCallback onElegir;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: pos.dx - 22,
      top: pos.dy - 46,
      child: Opacity(
        opacity: opacidad,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => onElegir(),
          child: GestureDetector(
            onTap: onElegir,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: true,
                  label: 'Sede $nombre',
                  child: SizedBox(
                    width: 44,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        const Icon(Icons.location_on,
                            size: 48, color: MarbelColors.blanco),
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Icon(Icons.location_on,
                              size: 42,
                              color: elegida
                                  ? MarbelColors.enJuego
                                  : const Color(0xFFC2283A)),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    nombre.toUpperCase(),
                    style: MarbelText.titular(18).copyWith(
                      fontStyle: FontStyle.normal,
                      shadows: const [
                        Shadow(color: MarbelColors.fondo, blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonMapa extends StatelessWidget {
  const _BotonMapa({
    required this.texto,
    required this.icono,
    required this.fondo,
    required this.onTap,
  });

  final String texto;
  final IconData icono;
  final Color fondo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fondo,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 20, color: MarbelColors.blanco),
              const SizedBox(width: 8),
              Text(texto,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: MarbelColors.blanco)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panel lateral: botones de sede + ficha de la elegida
// ---------------------------------------------------------------------------

class _Panel extends StatelessWidget {
  const _Panel({required this.sedes, required this.sel, required this.onElegir});

  final List<Map<String, dynamic>> sedes;
  final int sel;
  final ValueChanged<int> onElegir;

  @override
  Widget build(BuildContext context) {
    final s = sedes[sel];
    final foto = s['foto_url'] as String?;
    final maps = s['maps_url'] as String?;
    final servicios = (s['servicios'] as List?)?.cast<String>() ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sedes.length; i++) ...[
          _BotonSede(
            nombre: sedes[i]['nombre'] as String,
            elegida: i == sel,
            onTap: () => onElegir(i),
          ),
          const SizedBox(height: 10),
        ],
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: MarbelColors.tarjeta,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: MarbelColors.enJuego, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (foto != null && foto.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: foto.startsWith('http')
                      ? Image.network(foto, fit: BoxFit.cover)
                      : Image.asset(foto, fit: BoxFit.cover),
                ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((s['nombre'] as String).toUpperCase(),
                        style: MarbelText.titular(32)
                            .copyWith(fontStyle: FontStyle.normal)),
                    const SizedBox(height: 6),
                    Text(s['nombre_oficial'] as String? ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final x in servicios) ChipServicio(x)],
                    ),
                    if (Contenido.resumenSede(sel).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(Contenido.resumenSede(sel),
                          style: const TextStyle(color: MarbelColors.texto2, fontSize: 14, height: 1.5)),
                    ],
                    if (maps != null) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => launchUrl(Uri.parse(maps),
                            mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.directions_rounded, size: 20),
                        label: const Text('CÓMO LLEGAR'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BotonSede extends StatelessWidget {
  const _BotonSede(
      {required this.nombre, required this.elegida, required this.onTap});

  final String nombre;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: elegida ? MarbelColors.enJuego : MarbelColors.tarjeta,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: elegida
            ? BorderSide.none
            : const BorderSide(color: Color(0xFF2B35A6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 20,
                    color: elegida ? MarbelColors.blanco : MarbelColors.texto2),
                const SizedBox(width: 12),
                Text(nombre,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: elegida
                            ? MarbelColors.blanco
                            : MarbelColors.texto2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aspecto de cada servicio de la sede (icono y colores del diseño).
const _estiloServicio = {
  'Césped artificial': (Icons.grass_rounded, Color(0xFF0E3B2A), Color(0xFF9FF0C2)),
  'Cantina': (Icons.local_cafe_rounded, Color(0xFF3A2A00), Color(0xFFFFE08A)),
  'Aparcamiento': (Icons.local_parking_rounded, Color(0xFF1E2672), Color(0xFFDCE2FF)),
  'Espacios alternos': (Icons.park_rounded, Color(0xFF1E2672), Color(0xFFDCE2FF)),
};

class ChipServicio extends StatelessWidget {
  const ChipServicio(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) {
    final e = _estiloServicio[texto] ??
        (Icons.check_circle_rounded, const Color(0xFF1E2672), MarbelColors.texto2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: e.$2,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(e.$1, size: 18, color: e.$3),
          const SizedBox(width: 6),
          Text(texto,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: e.$3)),
        ],
      ),
    );
  }
}
