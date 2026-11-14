import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datos.dart';
import '../../data/modelos.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';
import 'utiles.dart';

/// Alias de La Porra y filtro de palabras (administración y comunicación).
class SeccionAlias extends StatefulWidget {
  const SeccionAlias({super.key});

  @override
  State<SeccionAlias> createState() => _SeccionAliasState();
}

class _SeccionAliasState extends State<SeccionAlias> {
  int _vista = 0; // 0 alias · 1 filtro
  List<Map<String, dynamic>>? _alias;
  String _buscar = '';
  List<String> _palabras = [];
  final _nueva = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nueva.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final alias = await db.rpc('alias_usuarios');
      final pal = await db.from('palabras_filtradas').select().order('palabra', ascending: true);
      if (!mounted) return;
      setState(() {
        _alias = List<Map<String, dynamic>>.from(alias as List);
        _palabras = [for (final p in pal) p['palabra'] as String];
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is PostgrestException ? e.message : '$e');
    }
  }

  Future<void> _rpc(String fn, Map<String, dynamic> params, {String? ok}) async {
    await ejecutar(context, () async {
      await db.rpc(fn, params: params);
      await _cargar();
    }, ok: ok);
  }

  @override
  Widget build(BuildContext context) {
    final vetados = (_alias ?? const []).where((a) => a['vetado_en'] != null).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FilaChips(children: [
        ChipFiltro(texto: vetados == 0 ? 'Alias' : 'Alias ($vetados vetados)', elegido: _vista == 0, onTap: () => setState(() => _vista = 0)),
        ChipFiltro(texto: 'Filtro de palabras', elegido: _vista == 1, onTap: () => setState(() => _vista = 1)),
      ]),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Actualizar')),
      ),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: Color(0xFFFF7A85)))
      else if (_alias == null)
        const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
      else if (_vista == 0)
        ..._vistaAlias()
      else
        ..._vistaFiltro(),
    ]);
  }

  Future<void> _vetar(String usuario, String alias) async {
    if (!await confirmar(
        context,
        '¿Vetar el alias «$alias»?',
        'En público se verá «Alias en revisión» y la persona tendrá 24 horas para cambiarlo. '
            'Si no lo cambia, no podrá jugar a La Porra hasta que elija otro. '
            'Después, avísale con el botón «Enviar email».',
        boton: 'Vetar')) {
      return;
    }
    if (!mounted) return;
    await _rpc('vetar_alias', {'p_usuario': usuario, 'p_vetar': true}, ok: 'Alias vetado. Ahora avísale desde «Alias».');
  }

  static String _fecha(DateTime d) => '${diaCorto(d).toLowerCase()} a las ${hhmm(d)}';

  /// Mensaje para avisar a quien tiene el alias vetado.
  static String _mensaje(Map<String, dynamic> a) {
    final limite = DateTime.parse(a['limite'] as String).toLocal();
    return 'Hola, ${a['nombre']}:\n\n'
        'La organización de la Marbel Football Cup ha revisado tu alias «${a['alias']}» y no está permitido '
        'porque lo considera ofensivo o fuera de lugar.\n\n'
        'Tienes hasta el ${_fecha(limite)} para cambiarlo desde la app o la web (Más → Alias → Cambiar). '
        'Si no lo cambias, no podrás jugar a La Porra hasta que elijas uno nuevo.\n\n'
        'Gracias por entenderlo.\n'
        'Organización de la Marbel Football Cup';
  }

  List<Widget> _vistaAlias() {
    final q = _buscar.trim().toLowerCase();
    final lista = (_alias ?? const <Map<String, dynamic>>[])
        .where((a) =>
            q.isEmpty ||
            '${a['alias']} ${a['nombre']} ${a['apellidos']} ${a['email']}'.toLowerCase().contains(q))
        .toList();
    return [
      const Text(
        'Es lo que se ve en público (ranking de La Porra). Si un alias es ofensivo, vétalo: '
        'se verá «Alias en revisión» y la persona tendrá 24 horas para cambiarlo. Pasado el plazo no podrá '
        'jugar a La Porra hasta que elija otro (al cambiarlo se quita el veto solo). '
        'Después de vetar, avísale con «Enviar email» o copia el mensaje y mándaselo por WhatsApp.',
        style: TextStyle(color: MarbelColors.texto2, height: 1.4),
      ),
      const SizedBox(height: 12),
      TextField(
        decoration: const InputDecoration(
          hintText: 'Buscar por alias, nombre o email',
          prefixIcon: Icon(Icons.search_rounded),
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) => setState(() => _buscar = v),
      ),
      const SizedBox(height: 12),
      if (lista.isEmpty) const EstadoVacio('No hay ningún alias que coincida.'),
      for (final a in lista.take(200)) ...[_filaAlias(a), const SizedBox(height: 8)],
      if (lista.length > 200)
        const Text('Hay más: usa el buscador.', style: TextStyle(color: MarbelColors.apagado)),
    ];
  }

  Widget _filaAlias(Map<String, dynamic> a) {
    final vetado = a['vetado_en'] != null;
    final vencido = a['vencido'] == true;
    final limite = vetado ? DateTime.parse(a['limite'] as String).toLocal() : null;
    final email = a['email'] as String?;
    return Tarjeta(
      padding: const EdgeInsets.all(14),
      borde: vetado ? (vencido ? const Color(0xFFFF7A85) : MarbelColors.medio) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('${a['alias'] ?? 'Sin alias'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (vetado)
            Pastilla(vencido ? 'Plazo vencido · bloqueado' : 'Vetado · hasta el ${_fecha(limite!)}',
                fondo: (vencido ? const Color(0xFFFF7A85) : MarbelColors.medio).withValues(alpha: .2),
                color: vencido ? const Color(0xFFFF7A85) : MarbelColors.medio,
                tamano: 11),
        ]),
        const SizedBox(height: 2),
        SelectableText('${a['nombre']} ${a['apellidos']} · ${email ?? 'sin email'}',
            style: const TextStyle(color: MarbelColors.apagado, fontSize: 13)),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (!vetado)
            TextButton.icon(
              onPressed: () => _vetar(a['id'] as String, '${a['alias']}'),
              icon: const Icon(Icons.badge_outlined, size: 18, color: Color(0xFFFF7A85)),
              label: const Text('Vetar', style: TextStyle(color: Color(0xFFFF7A85))),
            )
          else ...[
            if (email != null)
              TextButton.icon(
                onPressed: () => abrir('mailto:$email?subject=${Uri.encodeComponent('Tu alias en la Marbel Cup')}'
                    '&body=${Uri.encodeComponent(_mensaje(a))}'),
                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                label: const Text('Enviar email'),
              ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _mensaje(a)));
                if (mounted) avisar(context, 'Mensaje copiado');
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar mensaje'),
            ),
            TextButton.icon(
              onPressed: () => _rpc('vetar_alias', {'p_usuario': a['id'], 'p_vetar': false}, ok: 'Veto quitado'),
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('Quitar veto'),
            ),
          ],
        ]),
      ]),
    );
  }

  List<Widget> _vistaFiltro() {
    return [
      const Text(
        'Nadie puede elegir un alias que contenga alguna de estas palabras '
        '(y en «Opiniones» se marcan las que las llevan). '
        'Escríbelas en minúscula y sin tildes. Con * al final vale todo lo que empiece así (gilipoll* pilla gilipollas); '
        'sin *, solo esa palabra exacta (así «cono» no pilla «conocer»).',
        style: TextStyle(color: MarbelColors.texto2, height: 1.4),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _nueva,
            decoration: const InputDecoration(hintText: 'Añadir palabra (ej.: tontaco*)', border: OutlineInputBorder()),
            onSubmitted: (_) => _anadirPalabra(),
          ),
        ),
        const SizedBox(width: 8),
        BotonCian('Añadir', onTap: _anadirPalabra),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final p in _palabras)
          InputChip(
            label: Text(p),
            onDeleted: () => ejecutar(context, () async {
              await db.from('palabras_filtradas').delete().eq('palabra', p);
              await _cargar();
            }),
          ),
      ]),
    ];
  }

  Future<void> _anadirPalabra() async {
    final p = _nueva.text.trim().toLowerCase();
    if (p.length < 2) return;
    await ejecutar(context, () async {
      await db.from('palabras_filtradas').upsert({'palabra': p}, ignoreDuplicates: true);
      _nueva.clear();
      await _cargar();
    }, ok: 'Añadida');
  }
}
