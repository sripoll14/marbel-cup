import 'package:flutter/material.dart';

import '../../data/datos.dart';
import '../../data/modelos.dart';
import '../../data/sesion.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';
import 'utiles.dart';

/// Quién puede hacer qué. Para dar acceso a alguien: que se cree una cuenta
/// normal (web → Entrar → Crear cuenta) y aquí le cambias el rol.
class SeccionPersonal extends StatefulWidget {
  const SeccionPersonal({super.key});

  @override
  State<SeccionPersonal> createState() => _SeccionPersonalState();
}

class _SeccionPersonalState extends State<SeccionPersonal> {
  List<Perfil>? _perfiles;
  String _buscar = '';
  bool _soloPersonal = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await db.from('perfiles').select().order('nombre', ascending: true);
      if (mounted) setState(() => _perfiles = r.map(Perfil.fromMap).toList());
    } catch (e) {
      if (mounted) avisar(context, 'No se han podido cargar las cuentas: ${mensajeError(e)}', error: true);
    }
  }

  /// Marca o desmarca un rol de una persona.
  Future<void> _alternarRol(Perfil p, Rol r, bool activar) async {
    if (!activar && r == Rol.admin && p.id == sesion.usuario?.id) {
      final ok = await confirmar(context, '¿Quitarte a ti el rol de administración?',
          'Perderás el acceso a esta sección. Solo otra persona administradora podrá devolvértelo.',
          boton: 'Sí, quitar');
      if (!ok || !mounted) return;
    }
    final nuevos = {...p.roles};
    activar ? nuevos.add(r) : nuevos.remove(r);
    await _cambiar(p, {
      'roles': [for (final x in nuevos) rolSql(x)],
      if (!nuevos.contains(Rol.mesa)) 'sede_id': null,
    });
  }

  Future<void> _cambiar(Perfil p, Map<String, dynamic> cambios) async {
    await ejecutar(context, () async {
      await db.from('perfiles').update(cambios).eq('id', p.id);
      await _cargar();
      if (p.id == sesion.usuario?.id) await sesion.recargarPerfil();
    }, ok: 'Permisos actualizados');
  }

  @override
  Widget build(BuildContext context) {
    final todos = _perfiles;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Tarjeta(
        color: MarbelColors.fondoAlto,
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CÓMO DAR ACCESO', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
          SizedBox(height: 6),
          Text(
            '1. La persona se crea una cuenta normal en la web (Entrar → Crear cuenta).\n'
            '2. Búscala aquí por nombre o email y cámbiale el rol.\n'
            '3. Entra en …/#/gestion con su email y contraseña.\n\n'
            'Puedes marcar varios roles a la vez (por ejemplo, Mesa de sede + Comunicación).\n'
            '• Administración: todo.\n'
            '• Mesa de sede: resultados, goles, campos, retrasos y avisos de SU sede.\n'
            '• Comunicación: avisos y galería.\n'
            '• Sin ningún rol marcado: usuario normal (solo La Porra).',
            style: TextStyle(color: MarbelColors.texto2, height: 1.45),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 300,
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar por nombre o email'),
            onChanged: (v) => setState(() => _buscar = v.trim().toLowerCase()),
          ),
        ),
        FilterChip(
          label: const Text('Solo personal'),
          selected: _soloPersonal && _buscar.isEmpty,
          onSelected: (v) => setState(() => _soloPersonal = v),
        ),
        IconButton(tooltip: 'Recargar', onPressed: _cargar, icon: const Icon(Icons.refresh_rounded)),
      ]),
      const SizedBox(height: 14),
      if (todos == null)
        const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
      else ...() {
        final lista = todos.where((p) {
          if (_buscar.isNotEmpty) {
            return '${p.nombre} ${p.apellidos} ${p.email ?? ''}'.toLowerCase().contains(_buscar);
          }
          return !_soloPersonal || p.esPersonal;
        }).toList();
        if (lista.isEmpty) {
          return <Widget>[EstadoVacio(_buscar.isEmpty ? 'Nadie tiene rol de personal todavía.' : 'Ninguna cuenta coincide.')];
        }
        return <Widget>[
          Text('${lista.length} de ${todos.length} cuentas', style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
          const SizedBox(height: 8),
          for (final p in lista) ...[
            Tarjeta(
              padding: const EdgeInsets.all(14),
              child: Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.end, children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 240),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('${p.nombre} ${p.apellidos}${p.id == sesion.usuario?.id ? ' (tú)' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(p.email ?? '—', style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  const Text('Roles', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFC8D0F5))),
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final r in const [Rol.mesa, Rol.comunicacion, Rol.admin])
                      FilterChip(
                        label: Text(rolTexto(r)),
                        selected: p.tiene(r),
                        onSelected: (v) => _alternarRol(p, r, v),
                      ),
                  ]),
                ]),
                if (p.tiene(Rol.mesa))
                  SizedBox(
                    width: 220,
                    child: Desplegable<String>(
                      etiqueta: 'Sede',
                      valor: p.sedeId,
                      opciones: [for (final s in datos.sedes) (s.id, s.nombre)],
                      onCambio: (v) => _cambiar(p, {'sede_id': v}),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
          ],
        ];
      }(),
    ]);
  }
}
