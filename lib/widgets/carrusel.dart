import 'package:flutter/material.dart';

import '../data/modelos.dart';
import '../theme/app_theme.dart';
import 'comunes.dart';

/// Carrusel horizontal de fotos con flechas; al pasar el ratón se amplían y
/// al pulsar se abren a pantalla completa.
class Carrusel extends StatefulWidget {
  const Carrusel({super.key, required this.fotos});
  final List<Foto> fotos;

  @override
  State<Carrusel> createState() => _CarruselState();
}

class _CarruselState extends State<Carrusel> {
  final _ctrl = ScrollController();

  void _mover(int dir) {
    if (!_ctrl.hasClients) return;
    final destino = (_ctrl.offset + dir * 640).clamp(0.0, _ctrl.position.maxScrollExtent);
    _ctrl.animateTo(destino, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final alto = ancho ? 240.0 : 190.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          height: alto + 16,
          child: ListView.separated(
            controller: _ctrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: widget.fotos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) => _FotoZoom(
              foto: widget.fotos[i],
              ancho: alto * 1.36,
              alto: alto,
              onTap: () => abrirVisor(context, widget.fotos, i),
            ),
          ),
        ),
        if (ancho) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Flecha(Icons.chevron_left_rounded, () => _mover(-1), 'Anteriores'),
              const SizedBox(width: 10),
              _Flecha(Icons.chevron_right_rounded, () => _mover(1), 'Siguientes'),
            ],
          ),
        ],
      ],
    );
  }
}

class _FotoZoom extends StatefulWidget {
  const _FotoZoom({required this.foto, required this.ancho, required this.alto, required this.onTap});
  final Foto foto;
  final double ancho;
  final double alto;
  final VoidCallback onTap;

  @override
  State<_FotoZoom> createState() => _FotoZoomState();
}

class _FotoZoomState extends State<_FotoZoom> {
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
          scale: _encima ? 1.04 : 1,
          duration: const Duration(milliseconds: 220),
          child: Container(
            width: widget.ancho,
            height: widget.alto,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF131B6B),
              boxShadow: _encima
                  ? const [BoxShadow(color: MarbelColors.cian, spreadRadius: 3)]
                  : const [],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Imagen(widget.foto.url, etiqueta: widget.foto.pie),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedOpacity(
                    opacity: _encima ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      color: const Color(0xD1060A2B),
                      padding: const EdgeInsets.all(12),
                      child: Text(widget.foto.pie,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
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

class _Flecha extends StatelessWidget {
  const _Flecha(this.icono, this.onTap, this.etiqueta);
  final IconData icono;
  final VoidCallback onTap;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MarbelColors.tarjeta,
      shape: const CircleBorder(side: BorderSide(color: Color(0xFF2B35A6))),
      child: IconButton(tooltip: etiqueta, onPressed: onTap, icon: Icon(icono)),
    );
  }
}

/// Visor a pantalla completa con flechas (y deslizar en móvil).
void abrirVisor(BuildContext context, List<Foto> fotos, int inicio) {
  showDialog<void>(
    context: context,
    barrierColor: const Color(0xEE060A2B),
    builder: (_) => _Visor(fotos: fotos, inicio: inicio),
  );
}

class _Visor extends StatefulWidget {
  const _Visor({required this.fotos, required this.inicio});
  final List<Foto> fotos;
  final int inicio;

  @override
  State<_Visor> createState() => _VisorState();
}

class _VisorState extends State<_Visor> {
  late final PageController _pag = PageController(initialPage: widget.inicio);
  late int _i = widget.inicio;

  void _ir(int d) {
    final n = (_i + d) % widget.fotos.length;
    _pag.animateToPage(n < 0 ? n + widget.fotos.length : n,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('CERRAR'),
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  if (ancho) _Flecha(Icons.chevron_left_rounded, () => _ir(-1), 'Foto anterior'),
                  Expanded(
                    child: PageView.builder(
                      controller: _pag,
                      itemCount: widget.fotos.length,
                      onPageChanged: (i) => setState(() => _i = i),
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: InteractiveViewer(
                          child: Center(child: Imagen(widget.fotos[i].url, fit: BoxFit.contain)),
                        ),
                      ),
                    ),
                  ),
                  if (ancho) _Flecha(Icons.chevron_right_rounded, () => _ir(1), 'Foto siguiente'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${widget.fotos[_i].pie}  ·  ${_i + 1}/${widget.fotos.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
