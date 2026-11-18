import 'package:flutter/material.dart';

import '../data/contenido.dart';
import '../data/datos.dart';
import '../data/modelos.dart';
import '../data/proyecto.dart';
import '../screens/calendario_screen.dart' show RejillaDia;
import '../theme/app_theme.dart';
import 'comentarios.dart';
import 'comunes.dart';
import 'mapa_sedes.dart';
import 'torneos.dart';

/// Pinta los bloques de un proyecto de torneo, uno debajo de otro.
/// Los tipos de bloque están explicados en PROYECTOS.md.
class BloquesProyecto extends StatelessWidget {
  const BloquesProyecto(this.bloques, {super.key, this.anchoMax = false});
  final List<Map<String, dynamic>> bloques;

  /// Envolver cada bloque en [AnchoMax] (portada) o no (página de información).
  final bool anchoMax;

  @override
  Widget build(BuildContext context) {
    final hueco = SizedBox(height: esAncho(context) ? 56 : 36);
    final hijos = <Widget>[];
    for (final b in bloques) {
      final w = _bloque(b);
      if (w == null) continue;
      if (hijos.isNotEmpty) hijos.add(hueco);
      hijos.add(anchoMax ? AnchoMax(child: w) : w);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos);
  }

  Widget? _bloque(Map<String, dynamic> b) => switch (b['tipo']) {
        'niveles' => _Niveles(b),
        'mapa_sedes' => _MapaSedes(b),
        'sedes' => _Sedes(b),
        'horario' => _Horario(b),
        'lista_iconos' => _ListaIconos(b),
        'equipos_destacados' => _EquiposDestacados(b),
        'precios' => _Precios(b),
        'preguntas' => _Preguntas(b),
        'texto' => _Texto(b),
        'imagen' => _ImagenBloque(b),
        'contacto' => _Contacto(b),
        'opinion' => _Opinion(b),
        _ => null,
      };
}

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------
String? _s(dynamic v) => v == null ? null : '$v';
List<dynamic> _l(dynamic v) => v is List ? v : const [];

/// Título del bloque (con su etiqueta pequeña y subtítulo, si los tiene).
Widget? _titulo(Map<String, dynamic> b, {Widget? derecha}) {
  final t = _s(b['titulo']);
  if (t == null || t.isEmpty) return null;
  return TituloSeccion(etiqueta: _s(b['etiqueta']), titulo: t, subtitulo: _s(b['subtitulo']), derecha: derecha);
}

Widget _conTitulo(Map<String, dynamic> b, Widget cuerpo, {Widget? derecha}) {
  final t = _titulo(b, derecha: derecha);
  if (t == null) return cuerpo;
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [t, const SizedBox(height: 14), cuerpo]);
}

// ---------------------------------------------------------------------------
// niveles: tarjetas de color por nivel + listas (categorías, quién participa...)
// ---------------------------------------------------------------------------
class _Niveles extends StatelessWidget {
  const _Niveles(this.b);
  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final niveles = [
      for (final n in _l(b['niveles']))
        if (n is List && n.isNotEmpty) (Nivel.de('${n[0]}'), n.length > 1 ? '${n[1]}' : ''),
    ];
    final tarjetas = LayoutBuilder(builder: (context, c) {
      final cols = ancho ? 4 : 2;
      final w = (c.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final (n, desc) in niveles)
          Container(
            width: w,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: n.color, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.nombre.toUpperCase(), style: MarbelText.titular(ancho ? 34 : 26, color: n.texto)),
              const SizedBox(height: 6),
              Text(desc, style: TextStyle(color: n.texto, fontWeight: FontWeight.w700)),
            ]),
          ),
      ]);
    });

    final listas = [
      for (final l in _l(b['listas']))
        if (l is Map)
          Tarjeta(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${l['titulo'] ?? ''}'.toUpperCase(), style: MarbelText.titular(24).copyWith(fontStyle: FontStyle.normal)),
              const SizedBox(height: 8),
              for (final i in _l(l['items']))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('${l['prefijo'] ?? ''}$i', style: const TextStyle(color: MarbelColors.texto2, fontSize: 15)),
                ),
            ]),
          ),
    ];

    return _conTitulo(
      b,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (niveles.isNotEmpty) tarjetas,
        if (listas.isNotEmpty) ...[
          const SizedBox(height: 14),
          if (ancho)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < listas.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: listas[i]),
              ],
            ])
          else
            Column(children: [
              for (final l in listas) Padding(padding: const EdgeInsets.only(bottom: 12), child: SizedBox(width: double.infinity, child: l)),
            ]),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// mapa_sedes: el mapa de la Vega Baja con las sedes del torneo
// sedes: tarjetas de las sedes (foto, servicios, cómo llegar)
// ---------------------------------------------------------------------------
class _MapaSedes extends StatelessWidget {
  const _MapaSedes(this.b);
  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) {
    final sedes = datos.sedesTorneo;
    final p = datos.proyecto;
    // El mapa está dibujado para la Vega Baja: si alguna sede no tiene coordenadas, tarjetas.
    final enMapa = sedes.isNotEmpty && sedes.every((s) => s.lat != null && s.lon != null);
    return _conTitulo(
      b,
      sedes.isEmpty
          ? const EstadoVacio('Las sedes aún no están cargadas.')
          : enMapa
              ? MapaSedes(sedes: [for (final s in sedes) s.raw], resumen: p?.resumenSede)
              : const SedesDelTorneo(),
    );
  }
}

class _Sedes extends StatelessWidget {
  const _Sedes(this.b);
  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) => _conTitulo(b, const SedesDelTorneo());
}

// ---------------------------------------------------------------------------
// horario: qué se juega cada día en cada sede (con filtro por nivel)
// ---------------------------------------------------------------------------
class _Horario extends StatefulWidget {
  const _Horario(this.b);
  final Map<String, dynamic> b;

  @override
  State<_Horario> createState() => _HorarioState();
}

class _HorarioState extends State<_Horario> {
  String _nivel = 'todos';

  @override
  Widget build(BuildContext context) {
    final dias = horarioDe(widget.b);
    final niveles = <Nivel>[];
    for (final d in dias) {
      for (final s in d.sedes) {
        for (final x in s) {
          for (final n in x.niveles) {
            if (!niveles.contains(n)) niveles.add(n);
          }
        }
      }
    }
    niveles.sort((a, b) => Nivel.todos.indexOf(a).compareTo(Nivel.todos.indexOf(b)));
    final nota = _s(widget.b['nota']);
    return _conTitulo(
      widget.b,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (niveles.length > 1) ...[
          FilaChips(children: [
            ChipFiltro(
                texto: 'Todos',
                punto: MarbelColors.blanco,
                elegido: _nivel == 'todos',
                colorElegido: MarbelColors.blanco,
                onTap: () => setState(() => _nivel = 'todos')),
            for (final n in niveles)
              ChipFiltro(
                  texto: n.nombre,
                  punto: n.color,
                  elegido: _nivel == n.id,
                  colorElegido: MarbelColors.blanco,
                  onTap: () => setState(() => _nivel = n.id)),
          ]),
          const SizedBox(height: 14),
        ],
        for (final d in dias) ...[RejillaDia(dia: d, nivel: _nivel), const SizedBox(height: 12)],
        if (nota != null) Text(nota, style: const TextStyle(color: MarbelColors.apagado, fontSize: 14)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// lista_iconos: tarjetas con icono (qué incluye...) + destacados
// ---------------------------------------------------------------------------
class _ListaIconos extends StatelessWidget {
  const _ListaIconos(this.b);
  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final items = [
      for (final i in _l(b['items']))
        if (i is List && i.length >= 2) (iconoDe(i[0]), '${i[1]}'),
    ];
    final destacados = [for (final d in _l(b['destacados'])) if (d is Map) d];
    return _conTitulo(
      b,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 900 ? 4 : 2;
          final w = (c.maxWidth - 12 * (cols - 1)) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final (icono, texto) in items)
              SizedBox(
                width: w,
                height: ancho ? 150 : 140,
                child: Tarjeta(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: MarbelColors.azul, borderRadius: BorderRadius.circular(16)),
                      child: Icon(icono, color: MarbelColors.cian, size: 26),
                    ),
                    const Spacer(),
                    Text(texto, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.3)),
                  ]),
                ),
              ),
          ]);
        }),
        if (destacados.isNotEmpty) ...[
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 700 ? 2 : 1;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final d in destacados)
                SizedBox(
                  width: w,
                  child: d['estilo'] == 'relleno'
                      ? Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: MarbelColors.enJuego, borderRadius: BorderRadius.circular(18)),
                          child: Row(children: [
                            Icon(iconoDe(d['icono']), size: 30),
                            const SizedBox(width: 14),
                            Expanded(child: Text('${d['texto'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4))),
                          ]),
                        )
                      : Tarjeta(
                          borde: MarbelColors.enJuego,
                          child: Row(children: [
                            Icon(iconoDe(d['icono']), size: 30, color: MarbelColors.enJuego),
                            const SizedBox(width: 14),
                            Expanded(child: Text('${d['texto'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4))),
                          ]),
                        ),
                ),
            ]);
          }),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// equipos_destacados: cabezas de serie (null = por anunciar)
// ---------------------------------------------------------------------------
class _EquiposDestacados extends StatelessWidget {
  const _EquiposDestacados(this.b);
  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) {
    final nombres = [for (final e in _l(b['equipos'])) e == null ? null : '$e'];
    return _conTitulo(
      b,
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 3 : 2;
        final w = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final nombre in nombres)
            SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: nombre == null ? MarbelColors.fondoAlto : MarbelColors.azul,
                  borderRadius: BorderRadius.circular(18),
                  border: nombre == null ? Border.all(color: const Color(0xFF2B35A6), width: 2) : null,
                ),
                child: Row(children: [
                  if (nombre == null)
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFF131B6B), borderRadius: BorderRadius.circular(12)),
                      child: const Text('?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF8F99D6))),
                    )
                  else
                    Escudo(datos.equipos.where((e) => e.nombre == nombre).firstOrNull, tamano: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(nombre ?? 'Por anunciar',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: nombre == null ? const Color(0xFF8F99D6) : MarbelColors.blanco)),
                  ),
                ]),
              ),
            ),
        ]);
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// precios: precios + pasos para inscribirse + aviso + botones de contacto
// ---------------------------------------------------------------------------
class _Precios extends StatelessWidget {
  const _Precios(this.b);
  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) {
    final precios = [
      for (final p in _l(b['precios']))
        if (p is List && p.length >= 2) ('${p[0]}', '${p[1]}', p.length > 2 ? '${p[2]}' : ''),
    ];
    final pasos = [
      for (final p in _l(b['pasos']))
        if (p is List && p.isNotEmpty) ('${p[0]}', p.length > 1 ? '${p[1]}' : ''),
    ];
    final aviso = _s(b['aviso']);
    final pastilla = _s(b['pastilla']);
    return _conTitulo(
      b,
      derecha: pastilla == null ? null : Pastilla(pastilla, fondo: MarbelColors.enJuego, color: MarbelColors.blanco, tamano: 13),
      LayoutBuilder(builder: (context, c) {
        final ancho2 = c.maxWidth >= 800;
        final cajas = Row(children: [
          for (final (i, (m, p, sub)) in precios.indexed) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: i.isEven ? MarbelColors.azul : MarbelColors.cian,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.toUpperCase(), style: MarbelText.etiqueta(color: i.isEven ? MarbelColors.cian : MarbelColors.fondo)),
                  Text(p, style: MarbelText.titular(64, color: i.isEven ? MarbelColors.blanco : MarbelColors.fondo)),
                  if (sub.isNotEmpty)
                    Text(sub, style: TextStyle(fontWeight: FontWeight.w700, color: i.isEven ? MarbelColors.texto2 : MarbelColors.fondo)),
                ]),
              ),
            ),
          ],
        ]);
        final lista = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, (titulo, texto)) in pasos.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Tarjeta(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: MarbelColors.cian, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: MarbelText.titular(22, color: MarbelColors.fondo).copyWith(fontStyle: FontStyle.normal)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      if (texto.isNotEmpty) Text(texto, style: const TextStyle(color: MarbelColors.texto2)),
                    ]),
                  ),
                ]),
              ),
            ),
          if (aviso != null) Text(aviso, style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
          if (b['botones'] == true) ...[
            const SizedBox(height: 12),
            const _BotonesContacto(principal: 'Reservar por WhatsApp'),
          ],
        ]);
        if (precios.isEmpty) return lista;
        return ancho2
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: cajas),
                const SizedBox(width: 20),
                Expanded(child: lista),
              ])
            : Column(children: [cajas, const SizedBox(height: 14), lista]);
      }),
    );
  }
}

class _BotonesContacto extends StatelessWidget {
  const _BotonesContacto({this.principal = 'Escribir por WhatsApp'});
  final String principal;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 10, runSpacing: 10, children: [
      BotonCian(principal, icono: Marca.whatsapp, onTap: () => abrir(Contenido.whatsappUrl1)),
      BotonContorno('Escribir un email', icono: Marca.gmail, onTap: () => abrir('mailto:${Contenido.email}')),
    ]);
  }
}

// ---------------------------------------------------------------------------
// preguntas: preguntas frecuentes (se abren al tocarlas)
// ---------------------------------------------------------------------------
class _Preguntas extends StatefulWidget {
  const _Preguntas(this.b);
  final Map<String, dynamic> b;

  @override
  State<_Preguntas> createState() => _PreguntasState();
}

class _PreguntasState extends State<_Preguntas> {
  int _abierta = 0;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final i in _l(widget.b['items']))
        if (i is List && i.length >= 2) ('${i[0]}', '${i[1]}'),
    ];
    return _conTitulo(
      widget.b,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, (q, a)) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Tarjeta(
              padding: EdgeInsets.zero,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _abierta = _abierta == i ? -1 : i),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      Expanded(child: Text(q, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                      Text(_abierta == i ? '−' : '+', style: MarbelText.titular(30, color: MarbelColors.cian)),
                    ]),
                  ),
                ),
                if (_abierta == i)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Text(a, style: const TextStyle(color: MarbelColors.texto2, fontSize: 16, height: 1.5)),
                  ),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// texto, imagen, contacto, opinión
// ---------------------------------------------------------------------------
class _Texto extends StatelessWidget {
  const _Texto(this.b);
  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) => _conTitulo(
        b,
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(_s(b['texto']) ?? '', style: const TextStyle(color: MarbelColors.texto2, fontSize: 17, height: 1.55)),
        ),
      );
}

class _ImagenBloque extends StatelessWidget {
  const _ImagenBloque(this.b);
  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) {
    final url = _s(b['url']);
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    final pie = _s(b['pie']);
    return _conTitulo(
      b,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 560),
            child: Imagen(url, fit: BoxFit.contain, etiqueta: pie),
          ),
        ),
        if (pie != null) ...[
          const SizedBox(height: 8),
          Text(pie, style: const TextStyle(color: MarbelColors.apagado)),
        ],
      ]),
    );
  }
}

class _Contacto extends StatelessWidget {
  const _Contacto(this.b);
  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) {
    final texto = _s(b['texto']);
    return _conTitulo(
      b,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (texto != null) ...[
          Text(texto, style: const TextStyle(color: MarbelColors.texto2, fontSize: 16)),
          const SizedBox(height: 12),
        ],
        const _BotonesContacto(),
      ]),
    );
  }
}

class _Opinion extends StatelessWidget {
  const _Opinion(this.b);
  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) => _conTitulo(b, const DejanosTuOpinion());
}
