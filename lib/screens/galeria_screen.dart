import 'package:flutter/material.dart';

import '../data/datos.dart';
import '../theme/app_theme.dart';
import '../widgets/carrusel.dart';
import '../widgets/comunes.dart';
import '../widgets/marco_app.dart';

class GaleriaScreen extends StatelessWidget {
  const GaleriaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ConDatos(builder: (context) {
      final ancho = esAncho(context);
      final fotos = datos.fotos;
      final rejilla = LayoutBuilder(builder: (context, c) {
        final cols = ancho ? 4 : 2;
        const hueco = 12.0;
        final celda = (c.maxWidth - hueco * (cols - 1)) / cols;
        // Mosaico sencillo: las verticales ocupan dos filas; cada 5ª horizontal, dos columnas.
        return Wrap(
          spacing: hueco,
          runSpacing: hueco,
          children: [
            for (var i = 0; i < fotos.length; i++)
              _Celda(
                ancho: (ancho && !fotos[i].vertical && i % 5 == 0) ? celda * 2 + hueco : celda,
                alto: fotos[i].vertical ? celda * 1.5 : celda * .75,
                url: fotos[i].url,
                pie: fotos[i].pie,
                onTap: () => abrirVisor(context, fotos, i),
              ),
          ],
        );
      });
      final cabecera = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('EDICIONES ANTERIORES', style: MarbelText.etiqueta(size: 15)),
        Text.rich(TextSpan(children: [
          TextSpan(text: 'REVIVE LA\n', style: MarbelText.titular(ancho ? 80 : 48)),
          TextSpan(text: 'MAREA AZUL', style: MarbelText.titular(ancho ? 80 : 48, color: MarbelColors.cian)),
        ])),
        const SizedBox(height: 10),
        const Text(
          'Así se viven los torneos Marbel: grada llena, medallas, fruta y agua, asistencia sanitaria y una gran familia. Pulsa una foto para verla en grande.',
          style: TextStyle(color: Color(0xFFC8D0F5), fontSize: 16, height: 1.5),
        ),
      ]);
      final contenido = [
        cabecera,
        const SizedBox(height: 24),
        if (fotos.isEmpty) const EstadoVacio('Todavía no hay fotos.') else rejilla,
        const SizedBox(height: 14),
        const Text('Fotos de ediciones anteriores, publicadas con la autorización de los clubes participantes.',
            style: TextStyle(color: MarbelColors.apagado, fontSize: 14)),
      ];
      if (!ancho) {
        return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          const CabeceraMovil('Galería', atras: true),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: contenido)),
        ]);
      }
      return PaginaPublica(children: [
        const SizedBox(height: 48),
        AnchoMax(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: contenido)),
      ]);
    });
  }
}

class _Celda extends StatefulWidget {
  const _Celda({required this.ancho, required this.alto, required this.url, required this.pie, required this.onTap});
  final double ancho;
  final double alto;
  final String url;
  final String pie;
  final VoidCallback onTap;

  @override
  State<_Celda> createState() => _CeldaState();
}

class _CeldaState extends State<_Celda> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.zoomIn,
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _encima ? 1.03 : 1,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: widget.ancho,
            height: widget.alto,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFF131B6B),
              boxShadow: _encima ? const [BoxShadow(color: MarbelColors.cian, spreadRadius: 3)] : const [],
            ),
            child: Stack(fit: StackFit.expand, children: [
              Imagen(widget.url, etiqueta: widget.pie),
              if (_encima)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: const Color(0xD1060A2B),
                    padding: const EdgeInsets.all(12),
                    child: Text(widget.pie, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
