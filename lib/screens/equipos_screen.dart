import 'package:flutter/material.dart';

import '../data/contenido.dart';
import '../data/datos.dart';
import '../data/favoritos.dart';
import '../data/modelos.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/marco_app.dart';
import '../widgets/pedir_notificaciones.dart';

class EquiposScreen extends StatefulWidget {
  const EquiposScreen({super.key});

  @override
  State<EquiposScreen> createState() => _EquiposScreenState();
}

class _EquiposScreenState extends State<EquiposScreen> {
  String _q = '';
  String _cat = 'Todas';
  String _nivel = 'todos';
  String _genero = 'Todos';

  static const _grupos = ['Todas', 'Prebenjamín', 'Benjamín', 'Alevín', 'Infantil F11', 'Sub 12', 'Infantil F8'];

  /// Categoría y nivel de un equipo (según las ligas en las que está).
  List<(Categoria?, Nivel)> _ligas(Equipo e) => datos
      .ligasDeEquipo(e.id)
      .map((l) => (datos.categoria(l.categoriaId), Nivel.de(l.nivelId)))
      .toList();

  List<Equipo> _filtrados() {
    final q = _q.trim().toLowerCase();
    return datos.equipos.where((e) {
      if (q.isNotEmpty && !('${e.nombre} ${e.localidad ?? ''}'.toLowerCase().contains(q))) return false;
      final ls = _ligas(e);
      if (_cat != 'Todas' && !ls.any((x) => x.$1?.grupo == _cat)) return false;
      if (_nivel != 'todos' && !ls.any((x) => x.$2.id == _nivel)) return false;
      if (_genero != 'Todos') {
        final fem = ls.any((x) => x.$1?.femenina ?? false);
        if (_genero == 'Femenino' && !fem) return false;
        if (_genero == 'Masculino' && (ls.isEmpty || fem)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ConDatos(
      builder: (context) => ListenableBuilder(
        listenable: favoritos,
        builder: (context, _) => esAncho(context) ? _web(context) : _movil(context),
      ),
    );
  }

  Widget _buscador() => TextField(
        onChanged: (v) => setState(() => _q = v),
        decoration: InputDecoration(
          hintText: 'Buscar equipo o localidad',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: MarbelColors.tarjeta,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      );

  Widget _chipsCategoria() => FilaChips(children: [
        for (final c in _grupos) ChipFiltro(texto: c, elegido: _cat == c, onTap: () => setState(() => _cat = c)),
      ]);

  Widget _web(BuildContext context) {
    final lista = _filtrados();
    final t = datos.torneo;
    final abierta = t?.inscripcionHasta == null || DateTime.now().isBefore(t!.inscripcionHasta!.add(const Duration(days: 1)));
    return PaginaPublica(children: [
      const SizedBox(height: 48),
      AnchoMax(
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 24,
          runSpacing: 16,
          children: [
            TituloSeccion(etiqueta: t?.nombre ?? 'IV Torneo Navideño', titulo: 'Equipos inscritos', tamano: 80),
            Wrap(spacing: 12, runSpacing: 12, children: [
              Tarjeta(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${datos.equipos.length}', style: MarbelText.titular(56, color: MarbelColors.cian)),
                  Text('EQUIPOS YA DENTRO', style: MarbelText.etiqueta(color: MarbelColors.apagado)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(color: MarbelColors.azul, borderRadius: BorderRadius.circular(18)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: abierta ? MarbelColors.cian : MarbelColors.apagado, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(abierta ? 'Inscripción abierta' : 'Inscripción cerrada', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 6),
                  const Text('Inscripción hasta el 20 de diciembre · plazas limitadas', style: TextStyle(color: MarbelColors.texto2, fontSize: 14)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => abrir(Contenido.whatsappUrl1),
                    child: const Text('Apunta a tu equipo →', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ]),
          ],
        ),
      ),
      const SizedBox(height: 28),
      AnchoMax(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 360, child: _buscador()),
          const SizedBox(width: 14),
          Expanded(child: _chipsCategoria()),
        ]),
      ),
      const SizedBox(height: 14),
      AnchoMax(
        child: Wrap(spacing: 24, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('NIVEL', style: MarbelText.etiqueta(color: MarbelColors.apagado)),
            ChipFiltro(texto: 'Todos', punto: MarbelColors.blanco, elegido: _nivel == 'todos', onTap: () => setState(() => _nivel = 'todos')),
            for (final n in [Nivel.iniciacion, Nivel.medio, Nivel.elite])
              ChipFiltro(texto: n.nombre, punto: n.color, elegido: _nivel == n.id, onTap: () => setState(() => _nivel = n.id)),
          ]),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('GÉNERO', style: MarbelText.etiqueta(color: MarbelColors.apagado)),
            for (final g in ['Todos', 'Masculino', 'Femenino'])
              ChipFiltro(texto: g, elegido: _genero == g, onTap: () => setState(() => _genero = g)),
          ]),
          Text('${lista.length} de ${datos.equipos.length} equipos',
              style: const TextStyle(color: MarbelColors.cian, fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(height: 10),
      const AnchoMax(
        child: Text(
          'Equipos confirmados hasta ahora · la categoría y el nivel de cada equipo se publican en cuanto la organización los confirme. Marca ★ para seguir a un equipo.',
          style: TextStyle(color: MarbelColors.apagado, fontSize: 14),
        ),
      ),
      const SizedBox(height: 18),
      AnchoMax(
        child: lista.isEmpty
            ? const EstadoVacio('Todavía no hay equipos confirmados en ese filtro: las categorías se asignan en breve.')
            : LayoutBuilder(builder: (context, c) {
                final cols = (c.maxWidth / 300).floor().clamp(1, 4);
                final w = (c.maxWidth - 14 * (cols - 1)) / cols;
                return Wrap(spacing: 14, runSpacing: 14, children: [
                  for (final e in lista) SizedBox(width: w, child: _TarjetaEquipo(e, ligas: _ligas(e))),
                ]);
              }),
      ),
    ]);
  }

  Widget _movil(BuildContext context) {
    final lista = _filtrados();
    final nFav = favoritos.equipos.length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        CabeceraMovil('Equipos',
            derecha: Text('${datos.equipos.length} inscritos',
                style: const TextStyle(color: MarbelColors.cian, fontWeight: FontWeight.w700))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buscador()),
        const SizedBox(height: 10),
        Padding(padding: const EdgeInsets.only(left: 16), child: _chipsCategoria()),
        const SizedBox(height: 10),
        if (nFav > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('★ SIGUES A $nFav EQUIPO${nFav == 1 ? '' : 'S'}',
                style: MarbelText.etiqueta(color: MarbelColors.medio, size: 13)),
          ),
        if (lista.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: EstadoVacio('No hay equipos con ese filtro.'),
          ),
        for (final e in lista)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _TarjetaEquipo(e, ligas: _ligas(e), compacta: true),
          ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Toca ★ para seguir a un equipo: verás sus partidos y resultados en Avisos.',
              style: TextStyle(color: MarbelColors.apagado, fontSize: 12)),
        ),
      ],
    );
  }
}

class _TarjetaEquipo extends StatelessWidget {
  const _TarjetaEquipo(this.e, {required this.ligas, this.compacta = false});
  final Equipo e;
  final List<(Categoria?, Nivel)> ligas;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final fav = favoritos.es(e.id);
    return Tarjeta(
      padding: EdgeInsets.all(compacta ? 12 : 18),
      borde: fav ? MarbelColors.medio : null,
      child: Row(
        children: [
          Escudo(e, tamano: compacta ? 52 : 72),
          SizedBox(width: compacta ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.nombre, style: TextStyle(fontWeight: FontWeight.w700, fontSize: compacta ? 16 : 18)),
                const SizedBox(height: 2),
                Text(e.localidad ?? 'Localidad por confirmar',
                    style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (ligas.isEmpty)
                    const Pastilla('Categoría por confirmar', fondo: Color(0xFF1E2672), color: MarbelColors.apagado)
                  else
                    for (final (c, n) in ligas)
                      Pastilla.nivel(n, texto: n.id == 'femenino' ? (c?.corto ?? '') : '${c?.corto ?? ''} · ${n.nombre}'),
                ]),
              ],
            ),
          ),
          IconButton(
            tooltip: fav ? 'Dejar de seguir' : 'Seguir a ${e.nombre}',
            onPressed: () {
              favoritos.alternar(e.id);
              if (!fav) ofrecerNotificaciones(context, e.nombre);
            },
            style: IconButton.styleFrom(
              backgroundColor: fav ? const Color(0xFF2A2500) : const Color(0xFF131B6B),
              minimumSize: const Size(44, 44),
            ),
            icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded,
                color: fav ? MarbelColors.medio : MarbelColors.apagado),
          ),
        ],
      ),
    );
  }
}
