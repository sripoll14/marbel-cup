import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/contenido.dart';
import '../data/datos.dart';
import '../data/favoritos.dart';
import '../data/modelos.dart';
import '../theme/app_theme.dart';
import '../widgets/carrusel.dart';
import '../widgets/comunes.dart';
import '../widgets/competicion.dart';
import '../widgets/mapa_sedes.dart';
import '../widgets/marco_app.dart';
import '../widgets/partidos.dart';

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
          return PaginaPublica(
            children: [
              if (!ancho) const _CabeceraApp(),
              const _Hero(),
              hueco,
              const AnchoMax(child: _Avisos()),
              hueco,
              const AnchoMax(child: _EnDirecto()),
              hueco,
              const AnchoMax(child: Competicion()),
              hueco,
              const AnchoMax(child: _Niveles()),
              hueco,
              AnchoMax(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TituloSeccion(
                      etiqueta: 'Vega Baja · Alicante',
                      titulo: '4 sedes, 10–15 min entre ellas',
                      subtitulo:
                          'Amplía la Vega Baja y pasa el ratón (o toca) una chincheta para ver la sede, qué se juega allí y cómo llegar.',
                    ),
                    const SizedBox(height: 18),
                    if (datos.sedes.isEmpty)
                      const EstadoVacio('Las sedes aún no están cargadas.')
                    else
                      MapaSedes(sedes: [for (final s in datos.sedes) s.raw]),
                  ],
                ),
              ),
              hueco,
              const AnchoMax(child: _Momentazos()),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cabecera móvil (logo + campana de avisos)
// ---------------------------------------------------------------------------
class _CabeceraApp extends StatelessWidget {
  const _CabeceraApp();

  @override
  Widget build(BuildContext context) {
    final nuevos = datos.avisos.where((a) => a.creado.isAfter(favoritos.vistoHasta)).length;
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
          Badge(
            isLabelVisible: nuevos > 0,
            label: Text('$nuevos'),
            backgroundColor: MarbelColors.enJuego,
            child: IconButton(
              tooltip: 'Avisos',
              onPressed: () => context.go('/avisos'),
              icon: const Icon(Icons.notifications_rounded, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Portada + cuenta atrás
// ---------------------------------------------------------------------------
enum _Fase { antes, descanso, jugando, finalizado }

({_Fase fase, DateTime objetivo, int jornada}) _faseActual() {
  final ahora = DateTime.now();
  final js = Contenido.jornadas;
  for (var i = 0; i < js.length; i++) {
    final ini = js[i].add(const Duration(hours: 9));
    final fin = js[i].add(const Duration(hours: 21));
    if (!ahora.isBefore(ini) && !ahora.isAfter(fin)) {
      return (fase: _Fase.jugando, objetivo: ini, jornada: i);
    }
  }
  for (var i = 0; i < js.length; i++) {
    final ini = js[i].add(const Duration(hours: 9));
    if (ini.isAfter(ahora)) {
      return (fase: i == 0 ? _Fase.antes : _Fase.descanso, objetivo: ini, jornada: i);
    }
  }
  return (fase: _Fase.finalizado, objetivo: ahora, jornada: js.length - 1);
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final t = datos.torneo;
    final f = _faseActual();
    final (etiqueta, fondoEt, colorEt) = switch (f.fase) {
      _Fase.antes => ('Inscripción abierta', MarbelColors.cian, MarbelColors.fondo),
      _Fase.descanso => ('En juego · próxima jornada ${f.objetivo.day} ${mesCorto(f.objetivo)}',
          MarbelColors.enJuego, MarbelColors.blanco),
      _Fase.jugando => ('En juego ahora', MarbelColors.enJuego, MarbelColors.blanco),
      _Fase.finalizado => ('Finalizado', const Color(0xFF1E2672), MarbelColors.texto2),
    };
    final nombre = (t?.nombre ?? 'IV Torneo Navideño').toUpperCase();
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
            const Pastilla('Torneo actual', fondo: MarbelColors.azul, color: MarbelColors.blanco, tamano: 13),
            Pastilla(etiqueta, fondo: fondoEt, color: colorEt, tamano: 13),
          ],
        ),
        const SizedBox(height: 14),
        Text('FÚTBOL BASE · F8 Y F11 · MASCULINO Y FEMENINO',
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
        if (ancho)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: const Text(Contenido.lema,
                style: TextStyle(fontSize: 20, height: 1.5, color: Color(0xFFC8D0F5))),
          ),
        if (ancho) const SizedBox(height: 22),
        Wrap(
          spacing: 28,
          runSpacing: 12,
          alignment: ancho ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _Dato('Fechas', (t?.fechasTexto ?? '26–27 dic · 2–3 ene').toUpperCase()),
            const _Dato('Dónde', 'VEGA BAJA · 4 SEDES'),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          alignment: ancho ? WrapAlignment.start : WrapAlignment.center,
          children: [
            BotonCian('Toda la info', icono: Icons.arrow_forward_rounded, onTap: () => context.go('/torneo')),
            BotonContorno('Calendario', onTap: () => context.go('/calendario')),
          ],
        ),
      ],
    );

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
            const _CuentaAtras(),
          ],
        ),
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

/// Cuenta atrás que cambia según la fase del torneo.
class _CuentaAtras extends StatefulWidget {
  const _CuentaAtras();

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
    final f = _faseActual();
    final ancho = esAncho(context);
    const nombres = ['Sábado 26 dic', 'Domingo 27 dic', 'Sábado 2 ene', 'Domingo 3 ene'];

    if (f.fase == _Fase.finalizado) {
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
              BotonCian('Resultados finales', onTap: () => context.go('/calendario')),
              BotonContorno('Galería', onTap: () => context.go('/galeria')),
            ]),
          ],
        ),
      );
    }

    if (f.fase == _Fase.jugando) {
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
            Text('Jornada ${f.jornada + 1} de 4 · ${nombres[f.jornada]} · sigue los resultados aquí abajo',
                textAlign: TextAlign.center, style: const TextStyle(color: MarbelColors.texto2, fontSize: 16)),
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
        Text(f.fase == _Fase.antes ? 'EMPIEZA EN' : 'PRÓXIMA JORNADA EN',
            style: MarbelText.etiqueta(size: 16)),
        const SizedBox(height: 4),
        Text(
          f.fase == _Fase.antes
              ? 'Sábado 26 de diciembre · 9:00'
              : '${nombres[f.jornada]} · 9:00 · ya se jugaron las ${f.jornada} primeras jornadas',
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
                                    style: MarbelText.titular(120,
                                        color: i == 0 ? MarbelColors.cian : MarbelColors.blanco)),
                              ),
                            ),
                            Text(unidades[i].$2,
                                style: MarbelText.etiqueta(color: MarbelColors.apagado, size: ancho ? 15 : 11)),
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
// Avisos
// ---------------------------------------------------------------------------
class _Avisos extends StatelessWidget {
  const _Avisos();

  @override
  Widget build(BuildContext context) {
    final lista = datos.avisos.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TituloSeccion(
          etiqueta: 'De la organización',
          titulo: 'Avisos',
          derecha: TextButton(onPressed: () => context.go('/avisos'), child: const Text('Ver todos →')),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// En directo
// ---------------------------------------------------------------------------
class _EnDirecto extends StatelessWidget {
  const _EnDirecto();

  @override
  Widget build(BuildContext context) {
    var lista = datos.enDirecto;
    final hayDirecto = lista.isNotEmpty;
    if (!hayDirecto) {
      // Si no hay nada jugándose, los próximos partidos.
      final ahora = DateTime.now();
      lista = datos.partidos
          .where((p) => p.estado == Estado.programado && p.horaReal.isAfter(ahora.subtract(const Duration(minutes: 30))))
          .take(4)
          .toList();
    }
    final ancho = esAncho(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TituloSeccion(
          etiqueta: hayDirecto ? '● Ahora mismo' : 'Lo próximo',
          titulo: hayDirecto ? 'En directo' : 'Próximos partidos',
          derecha: TextButton(onPressed: () => context.go('/calendario'), child: const Text('Todos los partidos →')),
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
// Niveles y categorías
// ---------------------------------------------------------------------------
class _Niveles extends StatelessWidget {
  const _Niveles();

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final tarjetas = LayoutBuilder(builder: (context, c) {
      final cols = ancho ? 4 : 2;
      final w = (c.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (n, desc) in Contenido.niveles)
            Container(
              width: w,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: n.color, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.nombre.toUpperCase(), style: MarbelText.titular(ancho ? 34 : 26, color: n.texto)),
                  const SizedBox(height: 6),
                  Text(desc, style: TextStyle(color: n.texto, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      );
    });

    Widget lista(String titulo, List<String> items, {String prefijo = ''}) => Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo.toUpperCase(), style: MarbelText.titular(24).copyWith(fontStyle: FontStyle.normal)),
              const SizedBox(height: 8),
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('$prefijo$i', style: const TextStyle(color: MarbelColors.texto2, fontSize: 15)),
                ),
            ],
          ),
        );

    final listas = [
      lista('Masculino', Contenido.categoriasMasculino),
      lista('Femenino', Contenido.categoriasFemenino),
      lista('¿Quién puede participar?', Contenido.quienParticipa, prefijo: '→ '),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TituloSeccion(
          etiqueta: '3 niveles + femenino',
          titulo: 'Tú eliges el nivel',
          subtitulo: 'En masculino, tres niveles en cada categoría y año; en femenino, nivel único. '
              'Mínimo cuatro partidos asegurados para cada equipo.',
        ),
        const SizedBox(height: 18),
        tarjetas,
        const SizedBox(height: 14),
        if (ancho)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < listas.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: listas[i]),
              ],
            ],
          )
        else
          Column(children: [for (final l in listas) Padding(padding: const EdgeInsets.only(bottom: 12), child: SizedBox(width: double.infinity, child: l))]),
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
