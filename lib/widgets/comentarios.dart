import 'package:flutter/material.dart';

import '../data/datos.dart';
import '../data/sesion.dart';
import '../theme/app_theme.dart';
import 'comunes.dart';
import 'cuenta.dart';

/// «Déjanos tu opinión»: cada persona escribe y solo administración lo lee
/// (Panel → Opiniones). Hace falta cuenta para saber quién la envía.
class DejanosTuOpinion extends StatefulWidget {
  const DejanosTuOpinion({super.key});

  @override
  State<DejanosTuOpinion> createState() => _DejanosTuOpinionState();
}

class _DejanosTuOpinionState extends State<DejanosTuOpinion> {
  final _texto = TextEditingController();
  bool _enviando = false;
  bool _enviada = false;

  @override
  void initState() {
    super.initState();
    _texto.addListener(() => setState(() {}));
    sesion.addListener(_alCambiar);
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    sesion.removeListener(_alCambiar);
    _texto.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final t = _texto.text.trim();
    if (t.length < 2 || _enviando) return;
    setState(() => _enviando = true);
    try {
      await db.rpc('opinar', params: {'p_texto': t});
      _texto.clear();
      if (mounted) setState(() => _enviada = true);
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e), error: true);
    }
    if (mounted) setState(() => _enviando = false);
  }

  Future<void> _pedirCuenta() async {
    var registro = false;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          backgroundColor: MarbelColors.tarjeta,
          title: Text(registro ? 'Crear cuenta' : 'Entrar'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: registro
                  ? FormularioRegistro(alEntrar: () => Navigator.pop(c), alTenerCuenta: () => set(() => registro = false))
                  : FormularioEntrar(alEntrar: () => Navigator.pop(c), alCrearCuenta: () => set(() => registro = true)),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cerrar'))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const privado = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.lock_outline_rounded, size: 16, color: MarbelColors.apagado),
      SizedBox(width: 6),
      Expanded(
        child: Text('Solo la organización del torneo lee las opiniones. No se publican.',
            style: TextStyle(color: MarbelColors.apagado, fontSize: 12.5)),
      ),
    ]);

    if (!sesion.conectado) {
      return Tarjeta(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.rate_review_outlined, color: MarbelColors.cian),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('¿Qué te ha parecido el torneo? Para dejarnos tu opinión necesitas una cuenta (la misma de La Porra).',
                  style: TextStyle(color: MarbelColors.texto2)),
            ),
            const SizedBox(width: 8),
            BotonCian('Entrar', onTap: _pedirCuenta),
          ]),
          const SizedBox(height: 10),
          privado,
        ]),
      );
    }

    if (sesion.perfil?.comentariosBloqueado ?? false) {
      return const Tarjeta(
        padding: EdgeInsets.all(16),
        child: Text('Tu cuenta no puede enviar opiniones. Si crees que es un error, habla con la organización.',
            style: TextStyle(color: MarbelColors.texto2)),
      );
    }

    if (_enviada) {
      return Tarjeta(
        padding: const EdgeInsets.all(18),
        borde: MarbelColors.cian,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.check_circle_rounded, color: MarbelColors.cian),
            SizedBox(width: 10),
            Expanded(child: Text('¡Gracias! Hemos recibido tu opinión.', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ]),
          const SizedBox(height: 6),
          const Text('La leerá la organización del torneo.', style: TextStyle(color: MarbelColors.texto2)),
          const SizedBox(height: 8),
          TextButton(onPressed: () => setState(() => _enviada = false), child: const Text('Escribir otra')),
        ]),
      );
    }

    final listo = _texto.text.trim().length >= 2 && !_enviando;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _texto,
        maxLength: 1000,
        minLines: 3,
        maxLines: 8,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: '¿Qué te ha gustado? ¿Qué mejorarías?',
          border: OutlineInputBorder(),
        ),
      ),
      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        BotonCian('Enviar opinión', icono: Icons.send_rounded, onTap: listo ? _enviar : null, cargando: _enviando),
      ]),
      const SizedBox(height: 10),
      privado,
    ]);
  }
}
