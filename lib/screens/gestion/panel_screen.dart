import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/datos.dart';
import '../../data/modelos.dart';
import '../../data/sesion.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';
import '../../widgets/cuenta.dart';
import '../../widgets/marco_app.dart';
import 'seccion_avisos.dart';
import 'seccion_calendario.dart';
import 'seccion_equipos.dart';
import 'seccion_galeria.dart';
import 'seccion_partidos.dart';
import 'seccion_personal.dart';
import 'seccion_torneos.dart';

class _Apartado {
  const _Apartado(this.nombre, this.icono, this.roles, this.builder);
  final String nombre;
  final IconData icono;
  final Set<Rol> roles;
  final Widget Function() builder;
}

// Sin `const` en las secciones: así se vuelven a pintar cada vez que cambian los datos.
final _apartados = [
  _Apartado('Partidos y resultados', Icons.scoreboard_rounded, {Rol.admin, Rol.mesa}, () => SeccionPartidos()),
  _Apartado('Avisos y notificaciones', Icons.campaign_rounded, {Rol.admin, Rol.comunicacion, Rol.mesa}, () => SeccionAvisos()),
  _Apartado('Torneos', Icons.emoji_events_rounded, {Rol.admin}, () => SeccionTorneos()),
  _Apartado('Equipos e inscripciones', Icons.shield_rounded, {Rol.admin}, () => SeccionEquipos()),
  _Apartado('Calendario y sedes', Icons.calendar_month_rounded, {Rol.admin}, () => SeccionCalendario()),
  _Apartado('Galería', Icons.photo_library_rounded, {Rol.admin, Rol.comunicacion}, () => SeccionGaleria()),
  _Apartado('Personal y permisos', Icons.admin_panel_settings_rounded, {Rol.admin}, () => SeccionPersonal()),
];

/// Panel de gestión (dirección aparte: .../#/gestion). Solo personal autorizado.
class PanelScreen extends StatefulWidget {
  const PanelScreen({super.key});

  @override
  State<PanelScreen> createState() => _PanelScreenState();
}

class _PanelScreenState extends State<PanelScreen> {
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([sesion, datos]),
      builder: (context, _) {
        if (!sesion.conectado) return _acceso(context);
        final p = sesion.perfil;
        if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!p.esPersonal) return _sinPermiso(context);
        if (datos.cargando) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final mios = _apartados.where((a) => a.roles.any(p.tiene)).toList();
        if (_sel >= mios.length) _sel = 0;
        final ancho = esAncho(context);
        final sede = datos.sede(p.sedeId);

        final cabecera = Container(
          color: MarbelColors.fondoAlto,
          padding: EdgeInsets.symmetric(horizontal: ancho ? 24 : 12, vertical: 10),
          child: Row(children: [
            const LogoMarbel(tamano: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('PANEL DE GESTORES', style: MarbelText.titular(22)),
                Text(
                  '${p.nombreCorto} · ${p.rolesTexto}${p.tiene(Rol.mesa) && sede != null ? ' · ${sede.nombre}' : ''}',
                  style: const TextStyle(color: MarbelColors.apagado, fontSize: 13),
                ),
              ]),
            ),
            if (ancho) TextButton(onPressed: () => context.go('/'), child: const Text('Ver web pública ↗')),
            IconButton(tooltip: 'Cerrar sesión', onPressed: () => sesion.salir(), icon: const Icon(Icons.logout_rounded)),
          ]),
        );

        final contenido = mios[_sel].builder();

        if (ancho) {
          return Scaffold(
            body: Column(children: [
              cabecera,
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 270,
                    color: MarbelColors.fondoAlto,
                    padding: const EdgeInsets.all(12),
                    child: ListView(children: [
                      for (var i = 0; i < mios.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: i == _sel ? MarbelColors.azul : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              leading: Icon(mios[i].icono, color: i == _sel ? MarbelColors.blanco : MarbelColors.cian),
                              title: Text(mios[i].nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                              onTap: () => setState(() => _sel = i),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Cada cambio se publica al momento en la web y la app.',
                            style: TextStyle(color: MarbelColors.apagado, fontSize: 12)),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: ListView(padding: const EdgeInsets.all(24), children: [
                      Text(mios[_sel].nombre.toUpperCase(), style: MarbelText.titular(40)),
                      const SizedBox(height: 16),
                      contenido,
                    ]),
                  ),
                ]),
              ),
            ]),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Column(children: [
              cabecera,
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    for (var i = 0; i < mios.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChipFiltro(texto: mios[i].nombre, elegido: i == _sel, onTap: () => setState(() => _sel = i)),
                      ),
                  ],
                ),
              ),
              Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 32), children: [contenido])),
            ]),
          ),
          bottomNavigationBar: SafeArea(
            child: TextButton(onPressed: () => context.go('/'), child: const Text('← Volver a la web')),
          ),
        );
      },
    );
  }

  Widget _acceso(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: LogoMarbel(tamano: 90)),
                const SizedBox(height: 14),
                Text('PANEL DE GESTIÓN', textAlign: TextAlign.center, style: MarbelText.titular(38)),
                const SizedBox(height: 18),
                Tarjeta(padding: const EdgeInsets.all(22), child: FormularioEntrar(alEntrar: () {})),
                const SizedBox(height: 12),
                const Text(
                  'Solo personal autorizado por la administración. Esta dirección no aparece en la web pública.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MarbelColors.apagado, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: () => context.go('/'), child: const Text('← Volver a la web')),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sinPermiso(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_rounded, size: 56, color: MarbelColors.apagado),
              const SizedBox(height: 12),
              Text('SIN PERMISO', style: MarbelText.titular(36)),
              const SizedBox(height: 8),
              Text(
                'Has entrado como ${sesion.perfil?.email ?? sesion.usuario?.email ?? ''}, pero tu cuenta no tiene acceso al panel. '
                'Si formas parte de la organización, pide a administración que te dé un rol.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: MarbelColors.texto2, height: 1.4),
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 10, children: [
                BotonContorno('Cerrar sesión', onTap: () => sesion.salir()),
                BotonCian('Ir a la web', onTap: () => context.go('/')),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
