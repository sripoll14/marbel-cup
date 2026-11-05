import 'package:flutter/material.dart';

import '../data/contenido.dart';
import '../data/datos.dart';
import '../data/favoritos.dart';
import '../data/modelos.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/competicion.dart';
import '../widgets/marco_app.dart';
import '../widgets/partidos.dart';

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  int _dia = -1; // -1 = todos
  String _nivel = 'todos';
  String _sede = 'todas';
  bool _soloFavoritos = false;
  int _seg = 0; // móvil: 0 partidos, 1 clasificación, 2 fase final
  String? _ligaMovil;

  @override
  Widget build(BuildContext context) {
    return ConDatos(
      builder: (context) => ListenableBuilder(
        listenable: favoritos,
        builder: (context, _) => esAncho(context) ? _web(context) : _movil(context),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Filtros comunes
  // -------------------------------------------------------------------------
  List<DateTime> get _dias => datos.diasTorneo;

  List<Partido> _filtrados() {
    return datos.partidos.where((p) {
      if (_dia >= 0 && _dia < _dias.length && soloDia(p.hora) != _dias[_dia]) return false;
      if (_nivel != 'todos' && datos.liga(p.ligaId)?.nivelId != _nivel) return false;
      if (_sede != 'todas' && p.sedeId != _sede) return false;
      if (_soloFavoritos && !favoritos.es(p.localId ?? '') && !favoritos.es(p.visitanteId ?? '')) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _chipsDias({bool conTodos = true}) {
    return FilaChips(
      children: [
        if (conTodos)
          _ChipDia(arriba: 'Ver', grande: 'Todos', elegido: _dia == -1, onTap: () => setState(() => _dia = -1)),
        for (var i = 0; i < _dias.length; i++)
          _ChipDia(
            arriba: diaSemanaCorto(_dias[i]),
            grande: '${_dias[i].day} ${mesCorto(_dias[i])}',
            elegido: _dia == i,
            onTap: () => setState(() => _dia = i),
          ),
      ],
    );
  }

  Widget _chipsNivel() {
    return FilaChips(
      children: [
        ChipFiltro(
            texto: 'Todos', punto: MarbelColors.blanco, elegido: _nivel == 'todos',
            colorElegido: MarbelColors.blanco, onTap: () => setState(() => _nivel = 'todos')),
        for (final n in Nivel.todos)
          ChipFiltro(
              texto: n.nombre, punto: n.color, elegido: _nivel == n.id,
              colorElegido: MarbelColors.blanco, onTap: () => setState(() => _nivel = n.id)),
      ],
    );
  }

  Widget _listaPartidos(BuildContext context) {
    final lista = _filtrados();
    if (lista.isEmpty) {
      return EstadoVacio(datos.partidos.isEmpty
          ? 'El calendario de partidos se publica cuando la organización cierre las ligas.'
          : 'No hay partidos con estos filtros.');
    }
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 2 : 1;
      final w = (c.maxWidth - 14 * (cols - 1)) / cols;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [for (final p in lista) SizedBox(width: w, child: TarjetaPartido(p))],
      );
    });
  }

  // -------------------------------------------------------------------------
  // Ordenador
  // -------------------------------------------------------------------------
  Widget _web(BuildContext context) {
    final diasHorario = _dia == -1
        ? Contenido.horario
        : Contenido.horario.where((d) => _dia < _dias.length && soloDia(d.dia) == _dias[_dia]).toList();
    return PaginaPublica(
      children: [
        const SizedBox(height: 48),
        const AnchoMax(
          child: TituloSeccion(
            etiqueta: 'IV Torneo Navideño',
            titulo: 'Calendario',
            tamano: 80,
            subtitulo: 'Fechas, categorías y niveles por sede. Toca un nivel para ver solo sus categorías.',
          ),
        ),
        const SizedBox(height: 24),
        AnchoMax(child: _chipsDias()),
        const SizedBox(height: 14),
        AnchoMax(
          child: Row(children: [
            Text('NIVEL:', style: MarbelText.etiqueta(color: MarbelColors.apagado)),
            const SizedBox(width: 10),
            Expanded(child: _chipsNivel()),
          ]),
        ),
        const SizedBox(height: 20),
        for (final d in diasHorario) ...[
          AnchoMax(child: RejillaDia(dia: d, nivel: _nivel)),
          const SizedBox(height: 18),
        ],
        const AnchoMax(
          child: Text('Todo el día = la categoría juega en dos sedes a la vez.',
              style: TextStyle(color: MarbelColors.apagado)),
        ),
        const SizedBox(height: 48),
        AnchoMax(
          child: TituloSeccion(
            titulo: 'Partidos y resultados',
            derecha: Wrap(spacing: 8, runSpacing: 8, children: [
              ChipFiltro(
                  texto: '★ Mis favoritos', elegido: _soloFavoritos, colorElegido: MarbelColors.medio,
                  onTap: () => setState(() => _soloFavoritos = !_soloFavoritos)),
              ChipFiltro(texto: 'Todas las sedes', elegido: _sede == 'todas', onTap: () => setState(() => _sede = 'todas')),
              for (final s in datos.sedes)
                ChipFiltro(texto: s.corto, elegido: _sede == s.id, onTap: () => setState(() => _sede = s.id)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        AnchoMax(child: _listaPartidos(context)),
        const SizedBox(height: 56),
        const AnchoMax(child: Competicion()),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Móvil (Partidos / Clasificación / Fase final)
  // -------------------------------------------------------------------------
  Widget _movil(BuildContext context) {
    final segs = ['Partidos', 'Clasificación', 'Fase final'];
    Widget cuerpo;
    switch (_seg) {
      case 1:
        cuerpo = _clasificacionesMovil();
      case 2:
        final ligas = datos.ligasActuales;
        _ligaMovil ??= ligaInicial();
        cuerpo = ligas.isEmpty
            ? const EstadoVacio('Las ligas aún no están publicadas.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectorLiga(ligaId: _ligaMovil, onCambio: (l) => setState(() => _ligaMovil = l)),
                  const SizedBox(height: 16),
                  CuadroFinal(ligaId: datos.liga(_ligaMovil ?? '') == null ? ligas.first.id : _ligaMovil!),
                ],
              );
      default:
        if (_dia == -1) {
          // En móvil empezamos en el día de hoy (o el primero).
          final hoy = soloDia(DateTime.now());
          final i = _dias.indexOf(hoy);
          _dia = i >= 0 ? i : 0;
        }
        cuerpo = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chipsDias(conTodos: false),
            const SizedBox(height: 10),
            FilaChips(children: [
              ChipFiltro(
                  texto: '★ Mis favoritos', elegido: _soloFavoritos, colorElegido: MarbelColors.medio,
                  onTap: () => setState(() => _soloFavoritos = !_soloFavoritos)),
              for (final n in Nivel.todos)
                ChipFiltro(
                    texto: n.nombre, punto: n.color, elegido: _nivel == n.id, colorElegido: MarbelColors.blanco,
                    onTap: () => setState(() => _nivel = _nivel == n.id ? 'todos' : n.id)),
            ]),
            const SizedBox(height: 10),
            if (_dia >= 0 && _dia < _dias.length)
              Text(diaLargo(_dias[_dia]), style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
            const SizedBox(height: 10),
            _listaPartidos(context),
            const SizedBox(height: 18),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('QUÉ SE JUEGA EN CADA SEDE', style: MarbelText.etiqueta()),
              children: [
                for (final d in Contenido.horario) ...[
                  RejillaDia(dia: d, nivel: _nivel),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ],
        );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const CabeceraMovil('Partidos'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: MarbelColors.tarjeta, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                for (var i = 0; i < segs.length; i++)
                  Expanded(
                    child: Material(
                      color: _seg == i ? MarbelColors.azul : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _seg = i),
                        child: SizedBox(
                          height: 42,
                          child: Center(
                            child: Text(segs[i],
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: _seg == i ? MarbelColors.blanco : MarbelColors.apagado)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: cuerpo),
      ],
    );
  }

  bool _clasifFavs = true;

  Widget _clasificacionesMovil() {
    final ligasFav = <Liga>[];
    for (final e in favoritos.equipos) {
      for (final l in datos.ligasDeEquipo(e)) {
        if (!ligasFav.any((x) => x.id == l.id)) ligasFav.add(l);
      }
    }
    _ligaMovil ??= ligaInicial();
    Widget tabla(String ligaId) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Tarjeta(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Pastilla.nivel(datos.nivelDeLiga(ligaId), texto: datos.nombreLiga(ligaId), tamano: 11),
                  const SizedBox(width: 8),
                  Text('LIGA · J${datos.jornadaActual(ligaId)} DE ${datos.jornadasTotales(ligaId)}',
                      style: MarbelText.titular(17).copyWith(fontStyle: FontStyle.normal)),
                ]),
                const SizedBox(height: 6),
                TablaClasificacion(ligaId: ligaId),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          ChipFiltro(
              texto: '★ Mis favoritos', elegido: _clasifFavs, colorElegido: MarbelColors.medio,
              onTap: () => setState(() => _clasifFavs = true)),
          const SizedBox(width: 8),
          ChipFiltro(texto: 'Buscar', elegido: !_clasifFavs, onTap: () => setState(() => _clasifFavs = false)),
        ]),
        const SizedBox(height: 12),
        if (_clasifFavs) ...[
          if (ligasFav.isEmpty)
            const EstadoVacio('Marca tus equipos con ★ en la pestaña Equipos y aquí verás sus clasificaciones.',
                icono: Icons.star_outline_rounded)
          else
            for (final l in ligasFav) tabla(l.id),
        ] else if (datos.ligasActuales.isEmpty)
          const EstadoVacio('Las ligas aún no están publicadas.')
        else ...[
          SelectorLiga(ligaId: _ligaMovil, onCambio: (l) => setState(() => _ligaMovil = l)),
          const SizedBox(height: 12),
          tabla(datos.liga(_ligaMovil ?? '') == null ? datos.ligasActuales.first.id : _ligaMovil!),
        ],
        const Text(
          'Liga de 5: cada equipo juega 4 partidos · los 4 primeros pasan a semifinales (1º vs 4º · 2º vs 3º) · empate a puntos: diferencia de goles',
          style: TextStyle(color: MarbelColors.apagado, fontSize: 12),
        ),
      ],
    );
  }
}

class _ChipDia extends StatelessWidget {
  const _ChipDia({required this.arriba, required this.grande, required this.elegido, required this.onTap});
  final String arriba;
  final String grande;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: elegido ? MarbelColors.cian : MarbelColors.tarjeta,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 72, minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: elegido ? null : Border.all(color: const Color(0xFF2B35A6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(arriba.toUpperCase(),
                  style: MarbelText.etiqueta(
                      color: elegido ? MarbelColors.fondo : MarbelColors.apagado, size: 12)),
              Text(grande.toUpperCase(),
                  style: MarbelText.titular(22, color: elegido ? MarbelColors.fondo : MarbelColors.blanco)
                      .copyWith(fontStyle: FontStyle.normal)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rejilla de un día: sedes en columnas y mañana / tarde en filas.
class RejillaDia extends StatelessWidget {
  const RejillaDia({super.key, required this.dia, required this.nivel});
  final DiaHorario dia;
  final String nivel; // 'todos' o id de nivel

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final sedes = datos.sedes;
    final nombres = sedes.isEmpty
        ? const ['Albatera', 'Granja de Rocamora', 'Rafal', 'Bigastro']
        : sedes.map((s) => s.nombre).toList();
    final alto = ancho ? 84.0 : 70.0;

    Widget bloque(Bloque b, double h) {
      final activo = nivel == 'todos' || b.niveles.any((n) => n.id == nivel);
      final c1 = b.niveles.first.color;
      final c2 = b.niveles.length > 1 ? b.niveles[1].color : c1;
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: activo ? 1 : .15,
        child: Container(
          height: h,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c1, c1, c2, c2],
              stops: const [0, .5, .5, 1],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                b.franja == Franja.todoElDia ? '${b.categoria} · todo el día' : b.categoria,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: ancho ? 15 : 12, color: b.niveles.first.texto),
              ),
              Text(b.nivelesTexto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: ancho ? 12 : 10, color: b.niveles.first.texto)),
            ],
          ),
        ),
      );
    }

    Widget vacio(double h) => Container(
          height: h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E2672), width: 2),
          ),
          child: const Text('—', style: TextStyle(color: MarbelColors.apagado)),
        );

    Widget columna(List<Bloque> bs) {
      final todo = bs.where((b) => b.franja == Franja.todoElDia).firstOrNull;
      if (todo != null) return bloque(todo, alto * 2 + 8);
      final m = bs.where((b) => b.franja == Franja.manana).firstOrNull;
      final t = bs.where((b) => b.franja == Franja.tarde).firstOrNull;
      return Column(children: [
        m == null ? vacio(alto) : bloque(m, alto),
        const SizedBox(height: 8),
        t == null ? vacio(alto) : bloque(t, alto),
      ]);
    }

    final rejilla = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: ancho ? 80 : 54),
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    (ancho ? nombres[i] : sedes.isEmpty ? nombres[i] : sedes[i].corto).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MarbelText.etiqueta(color: MarbelColors.texto2, size: ancho ? 14 : 11),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: ancho ? 80 : 54,
              child: Column(children: [
                SizedBox(height: alto, child: Center(child: Text('Mañana', style: _franja(ancho)))),
                const SizedBox(height: 8),
                SizedBox(height: alto, child: Center(child: Text('Tarde', style: _franja(ancho)))),
              ]),
            ),
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: columna(i < dia.sedes.length ? dia.sedes[i] : const []),
                ),
              ),
          ],
        ),
      ],
    );

    return Tarjeta(
      padding: EdgeInsets.all(ancho ? 18 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(diaLargo(dia.dia).toUpperCase(),
              style: MarbelText.titular(ancho ? 28 : 22).copyWith(fontStyle: FontStyle.normal)),
          const SizedBox(height: 12),
          rejilla,
        ],
      ),
    );
  }

  TextStyle _franja(bool ancho) => TextStyle(
      color: MarbelColors.apagado, fontWeight: FontWeight.w700, fontSize: ancho ? 14 : 11);
}
