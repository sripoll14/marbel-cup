import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/contenido.dart';
import '../data/datos.dart';
import '../data/modelos.dart';
import '../theme/app_theme.dart';

/// ¿Pantalla de ordenador?
bool esAncho(BuildContext context) => MediaQuery.sizeOf(context).width >= 1000;

Future<void> abrir(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Abre una página legal (están en web/legal/).
Future<void> abrirLegal(String doc) {
  final url = kIsWeb
      ? Uri.base.resolve('legal/$doc.html').toString()
      : 'https://sripoll14.github.io/marbel-cup/legal/$doc.html';
  return launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
}

/// Contenido centrado con ancho máximo (como la web del diseño).
/// Glifos de la fuente propia assets/fonts/MarcasMarbel.otf
/// (hecha con los iconos de Simple Icons, licencia CC0).
abstract final class Marcas {
  static const whatsapp = IconData(0xE001, fontFamily: 'MarcasMarbel');
  static const instagram = IconData(0xE002, fontFamily: 'MarcasMarbel');
  static const gmail = IconData(0xE003, fontFamily: 'MarcasMarbel');
}

class AnchoMax extends StatelessWidget {
  const AnchoMax({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(
          padding: padding ??
              EdgeInsets.symmetric(horizontal: esAncho(context) ? 24 : 16),
          child: child,
        ),
      ),
    );
  }
}

/// Etiqueta pequeña + titular grande (+ algo a la derecha).
class TituloSeccion extends StatelessWidget {
  const TituloSeccion({
    super.key,
    this.etiqueta,
    required this.titulo,
    this.derecha,
    this.tamano,
    this.subtitulo,
  });
  final String? etiqueta;
  final String titulo;
  final Widget? derecha;
  final double? tamano;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final izq = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (etiqueta != null) ...[
          Text(etiqueta!.toUpperCase(), style: MarbelText.etiqueta(size: 15)),
          const SizedBox(height: 4),
        ],
        Text(titulo.toUpperCase(),
            style: MarbelText.titular(tamano ?? (ancho ? 48 : 34))),
        if (subtitulo != null) ...[
          const SizedBox(height: 8),
          Text(subtitulo!,
              style: const TextStyle(
                  color: Color(0xFFC8D0F5), fontSize: 16, height: 1.45)),
        ],
      ],
    );
    if (derecha == null) return izq;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 12,
      spacing: 16,
      children: [izq, derecha!],
    );
  }
}

/// Tarjeta oscura con borde.
class Tarjeta extends StatelessWidget {
  const Tarjeta({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = MarbelColors.tarjeta,
    this.borde,
    this.radio = 20,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borde;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: borde ?? MarbelColors.borde, width: borde == null ? 1 : 2),
      ),
      child: child,
    );
  }
}

/// Píldora de color (nivel, estado...).
class Pastilla extends StatelessWidget {
  const Pastilla(this.texto,
      {super.key, required this.fondo, required this.color, this.icono, this.tamano = 12});
  final String texto;
  final Color fondo;
  final Color color;
  final IconData? icono;
  final double tamano;

  factory Pastilla.nivel(Nivel n, {String? texto, double tamano = 12}) =>
      Pastilla(texto ?? n.nombre, fondo: n.color, color: n.texto, tamano: tamano);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: tamano * .8, vertical: tamano * .3),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: tamano + 2, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(texto,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontSize: tamano, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Chip seleccionable (filtros).
class ChipFiltro extends StatelessWidget {
  const ChipFiltro({
    super.key,
    required this.texto,
    required this.elegido,
    required this.onTap,
    this.punto,
    this.colorElegido = MarbelColors.cian,
  });
  final String texto;
  final bool elegido;
  final VoidCallback onTap;
  final Color? punto;
  final Color colorElegido;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: elegido ? colorElegido : MarbelColors.tarjeta,
      shape: StadiumBorder(
        side: elegido ? BorderSide.none : const BorderSide(color: Color(0xFF2B35A6)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (punto != null) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: punto, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
              ],
              Text(texto,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: elegido ? MarbelColors.fondo : MarbelColors.texto2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila deslizable de chips (en móvil no se cortan).
class FilaChips extends StatelessWidget {
  const FilaChips({super.key, required this.children, this.envolver});
  final List<Widget> children;
  final bool? envolver;

  @override
  Widget build(BuildContext context) {
    if (envolver ?? esAncho(context)) {
      return Wrap(spacing: 8, runSpacing: 8, children: children);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Escudo de un equipo (imagen incluida o subida; si no, iniciales).
class Escudo extends StatelessWidget {
  const Escudo(this.equipo, {super.key, this.tamano = 40});
  final Equipo? equipo;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final url = equipo?.escudoUrl;
    Widget dentro;
    if (url == null || url.isEmpty) {
      dentro = Center(
        child: Text(equipo?.iniciales ?? '?',
            style: TextStyle(
                fontFamily: 'BarlowCondensed',
                fontWeight: FontWeight.w800,
                fontSize: tamano * .4,
                color: MarbelColors.fondo)),
      );
    } else {
      dentro = url.startsWith('http')
          ? Image.network(url, fit: BoxFit.contain)
          : Image.asset(url, fit: BoxFit.contain);
    }
    return Container(
      width: tamano,
      height: tamano,
      padding: EdgeInsets.all(tamano * .06),
      decoration: BoxDecoration(
        color: MarbelColors.blanco,
        borderRadius: BorderRadius.circular(tamano * .25),
      ),
      child: dentro,
    );
  }
}

/// Imagen de assets/ o de internet según la ruta.
class Imagen extends StatelessWidget {
  const Imagen(this.url, {super.key, this.fit = BoxFit.cover, this.etiqueta});
  final String url;
  final BoxFit fit;
  final String? etiqueta;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('http')) {
      return Image.network(url, fit: fit, semanticLabel: etiqueta);
    }
    return Image.asset(url, fit: fit, semanticLabel: etiqueta);
  }
}

class EstadoVacio extends StatelessWidget {
  const EstadoVacio(this.texto, {super.key, this.icono = Icons.info_outline_rounded});
  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E2672), width: 2),
      ),
      child: Column(
        children: [
          Icon(icono, color: MarbelColors.apagado, size: 32),
          const SizedBox(height: 10),
          Text(texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: MarbelColors.apagado, fontWeight: FontWeight.w600, height: 1.4)),
        ],
      ),
    );
  }
}

/// Envuelve una pantalla: si los datos aún cargan o fallan, lo dice.
class ConDatos extends StatelessWidget {
  const ConDatos({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: datos,
      builder: (context, _) {
        if (datos.cargando) {
          return const Center(child: CircularProgressIndicator());
        }
        if (datos.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EstadoVacio(datos.error!, icono: Icons.cloud_off_rounded),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () {
                      datos.error = null;
                      datos.cargando = true;
                      datos.iniciar();
                    },
                    child: const Text('REINTENTAR'),
                  ),
                ],
              ),
            ),
          );
        }
        return builder(context);
      },
    );
  }
}

/// Botón cian grande.
class BotonCian extends StatelessWidget {
  const BotonCian(this.texto, {super.key, required this.onTap, this.icono, this.cargando = false});
  final String texto;
  final VoidCallback? onTap;
  final Object? icono; // IconData o Marca
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final hijo = cargando
        ? const SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
        : Text(texto.toUpperCase());
    if (icono != null && !cargando) {
      return FilledButton.icon(
          onPressed: onTap, icon: Icono(icono!, tamano: 20), label: hijo);
    }
    return FilledButton(onPressed: cargando ? null : onTap, child: hijo);
  }
}

/// Botón de contorno.
class BotonContorno extends StatelessWidget {
  const BotonContorno(this.texto, {super.key, required this.onTap, this.icono});
  final String texto;
  final VoidCallback? onTap;
  final Object? icono; // IconData o Marca

  @override
  Widget build(BuildContext context) {
    final estilo = OutlinedButton.styleFrom(
      foregroundColor: MarbelColors.blanco,
      side: const BorderSide(color: Color(0xFF2B35A6), width: 2),
      minimumSize: const Size(44, 48),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(
          fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w800, fontSize: 17),
    );
    if (icono != null) {
      return OutlinedButton.icon(
          onPressed: onTap, style: estilo, icon: Icono(icono!, tamano: 20), label: Text(texto.toUpperCase()));
    }
    return OutlinedButton(onPressed: onTap, style: estilo, child: Text(texto.toUpperCase()));
  }
}

/// Pie de las páginas públicas: lema, WhatsApp (los dos), Instagram, email y legales.
class Pie extends StatelessWidget {
  const Pie({super.key});

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final lema = Text.rich(
      TextSpan(children: [
        TextSpan(text: 'UNA GRAN FAMILIA,\n', style: MarbelText.titular(ancho ? 64 : 44)),
        TextSpan(
            text: 'MAREA AZUL',
            style: MarbelText.titular(ancho ? 64 : 44, color: MarbelColors.cian)),
      ]),
    );
    final contacto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LineaContacto(
          icono: Marca.whatsapp,
          hijos: [
            _Enlace(Contenido.whatsapp1, () => abrir(Contenido.whatsappUrl1)),
            const Text('  ·  ', style: TextStyle(color: MarbelColors.cian, fontSize: 20)),
            _Enlace(Contenido.whatsapp2, () => abrir(Contenido.whatsappUrl2)),
          ],
        ),
        const SizedBox(height: 14),
        _LineaContacto(
          icono: Marca.instagram,
          hijos: [_Enlace(Contenido.instagram, () => abrir(Contenido.instagramUrl))],
        ),
        const SizedBox(height: 14),
        _LineaContacto(
          icono: Marca.gmail,
          hijos: [_Enlace(Contenido.email, () => abrir('mailto:${Contenido.email}'))],
        ),
        const SizedBox(height: 16),
        const Text('Comunidad Valenciana · Torneos de fútbol base',
            style: TextStyle(color: MarbelColors.texto2, fontSize: 15)),
        const SizedBox(height: 4),
        const Text(
            'Por protección de menores, no publicamos plantillas ni fotos de perfil de jugadores.',
            style: TextStyle(color: MarbelColors.texto2, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _EnlaceLegal('Aviso legal', 'aviso-legal'),
            _EnlaceLegal('Política de privacidad', 'privacidad'),
            _EnlaceLegal('Política de cookies', 'cookies'),
          ],
        ),
      ],
    );
    return Container(
      color: MarbelColors.azul,
      child: AnchoMax(
        padding: EdgeInsets.symmetric(horizontal: ancho ? 24 : 16, vertical: 48),
        child: ancho
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [Expanded(child: lema), const SizedBox(width: 40), contacto],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [lema, const SizedBox(height: 28), contacto],
              ),
      ),
    );
  }
}

class _LineaContacto extends StatelessWidget {
  const _LineaContacto({required this.icono, required this.hijos});
  final Object icono;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: MarbelColors.fondo, borderRadius: BorderRadius.circular(14)),
          child: Center(child: Icono(icono, color: MarbelColors.cian, tamano: 24)),
        ),
        const SizedBox(width: 12),
        Flexible(child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: hijos)),
      ],
    );
  }
}

class _Enlace extends StatelessWidget {
  const _Enlace(this.texto, this.onTap);
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(texto,
          style: const TextStyle(
              color: MarbelColors.blanco,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: Color(0x66FFFFFF))),
    );
  }
}

class _EnlaceLegal extends StatelessWidget {
  const _EnlaceLegal(this.texto, this.doc);
  final String texto;
  final String doc;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => abrirLegal(doc),
      child: Text(texto,
          style: const TextStyle(
              color: MarbelColors.blanco,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: Color(0x99FFFFFF))),
    );
  }
}

/// Página pública desplazable con el pie al final.
class PaginaPublica extends StatelessWidget {
  const PaginaPublica({super.key, required this.children, this.conPie = true});
  final List<Widget> children;
  final bool conPie;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ...children,
        if (conPie) ...[const SizedBox(height: 48), const Pie()],
      ],
    );
  }
}

/// Mensaje breve abajo.
void avisar(BuildContext context, String texto, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(texto),
    backgroundColor: error ? MarbelColors.enJuego : MarbelColors.azul,
    behavior: SnackBarBehavior.floating,
  ));
}

/// Logos de WhatsApp, Instagram y Gmail.
enum Marca {
  whatsapp(Marcas.whatsapp),
  instagram(Marcas.instagram),
  gmail(Marcas.gmail);

  const Marca(this.icono);
  final IconData icono;
}

/// Pinta un icono normal de Flutter (IconData) o el logo de una Marca.
class Icono extends StatelessWidget {
  const Icono(this.icono, {super.key, this.tamano = 24, this.color});
  final Object icono;
  final double tamano;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? MarbelColors.blanco;
    final i = icono;
    if (i is Marca) return Icon(i.icono, size: tamano, color: c);
    return Icon(i as IconData, size: tamano, color: c);
  }
}
