import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/contenido.dart';
import '../data/datos.dart';
import '../data/modelos.dart';
import '../data/sesion.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/cuenta.dart';
import '../widgets/marco_app.dart';

/// "Más" (móvil): cuenta, panel para el personal y el resto de secciones.
class MasScreen extends StatefulWidget {
  const MasScreen({super.key});

  @override
  State<MasScreen> createState() => _MasScreenState();
}

class _MasScreenState extends State<MasScreen> {
  bool _formulario = false;
  bool _registro = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sesion,
      builder: (context, _) {
        final p = sesion.perfil;
        final sede = datos.sede(p?.sedeId);
        Widget opcion(Object icono, String texto, VoidCallback onTap, {String? sub}) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: MarbelColors.tarjeta,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Icono(icono, color: MarbelColors.cian),
                  title: Text(texto, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: sub == null ? null : Text(sub, style: const TextStyle(color: MarbelColors.apagado)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: MarbelColors.apagado),
                  onTap: onTap,
                ),
              ),
            );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            const CabeceraMovil('Más'),
            // Cuenta
            Tarjeta(
              child: p == null
                  ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text('Sin sesión iniciada', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 4),
                      const Text('Solo necesitas cuenta para jugar a La Porra.', style: TextStyle(color: MarbelColors.apagado)),
                      const SizedBox(height: 12),
                      if (!_formulario)
                        BotonCian('Entrar o crear cuenta', onTap: () => setState(() => _formulario = true))
                      else if (_registro)
                        FormularioRegistro(alTenerCuenta: () => setState(() => _registro = false))
                      else
                        FormularioEntrar(alCrearCuenta: () => setState(() => _registro = true)),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: MarbelColors.azul,
                          child: Text(p.iniciales, style: const TextStyle(fontWeight: FontWeight.w800, color: MarbelColors.blanco)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.nombreCorto, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                            Text(
                              p.esPersonal
                                  ? '${p.rolesTexto}${sede == null ? '' : ' · ${sede.nombre}'}'
                                  : datos.nombreEquipo(p.equipoId, siNo: 'Sin equipo'),
                              style: const TextStyle(color: MarbelColors.apagado),
                            ),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        BotonContorno('Cerrar sesión', onTap: () => sesion.salir()),
                        TextButton(
                          onPressed: () => _confirmarBorrado(context),
                          child: const Text('Borrar mi cuenta', style: TextStyle(color: Color(0xFFFF7A85))),
                        ),
                      ]),
                    ]),
            ),
            const SizedBox(height: 14),
            if (p != null && p.esPersonal)
              opcion(Icons.admin_panel_settings_rounded, 'Panel de gestión', () => context.go('/gestion'),
                  sub: p.tiene(Rol.admin)
                      ? 'Todo el torneo'
                      : [
                          if (p.tiene(Rol.mesa)) 'Resultados y campos${sede == null ? '' : ' de ${sede.nombre}'}',
                          if (p.tiene(Rol.comunicacion)) 'avisos y galería' else 'avisos',
                        ].join(', ').replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase())),
            opcion(Icons.notifications_rounded, 'Avisos y notificaciones', () => context.go('/avisos')),
            opcion(Icons.bar_chart_rounded, 'Estadísticas', () => context.go('/estadisticas')),
            opcion(Icons.photo_library_rounded, 'Galería de ediciones anteriores', () => context.go('/galeria')),
            opcion(Icons.info_rounded, 'Info del torneo y normativa', () => context.go('/torneo')),
            opcion(Marca.whatsapp, 'Contactar por WhatsApp', () => abrir(Contenido.whatsappUrl1), sub: '${Contenido.whatsapp1} · ${Contenido.whatsapp2}'),
            opcion(Marca.instagram, 'Instagram', () => abrir(Contenido.instagramUrl), sub: Contenido.instagram),
            const SizedBox(height: 8),
            Wrap(spacing: 4, children: [
              TextButton(onPressed: () => abrirLegal('privacidad'), child: const Text('Política de privacidad')),
              TextButton(onPressed: () => abrirLegal('aviso-legal'), child: const Text('Aviso legal')),
              TextButton(onPressed: () => abrirLegal('cookies'), child: const Text('Cookies')),
            ]),
            if (p == null)
              Center(
                child: TextButton(
                  onPressed: () => context.go('/gestion'),
                  child: const Text('Acceso para el personal', style: TextStyle(color: MarbelColors.apagado, fontSize: 12)),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmarBorrado(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: MarbelColors.tarjeta,
        title: const Text('¿Borrar tu cuenta?'),
        content: const Text('Se borrarán tu cuenta y tus predicciones de La Porra. No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MarbelColors.enJuego, foregroundColor: MarbelColors.blanco),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('BORRAR'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await sesion.borrarCuenta();
      if (context.mounted) avisar(context, 'Cuenta borrada.');
    } catch (e) {
      if (context.mounted) avisar(context, 'No se ha podido borrar: ${mensajeError(e)}', error: true);
    }
  }
}
