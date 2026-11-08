import 'package:flutter/material.dart';

import '../../data/contenido.dart';
import '../../data/datos.dart';
import '../../data/modelos.dart';
import '../../theme/app_theme.dart';

/// Lo que se envía a generar_liga.
typedef DatosLiguilla = ({List<Map<String, dynamic>> franjas, int minutos, bool repartir});

class _SedeFranja {
  _SedeFranja(this.sedeId, [this.campos = 2]);
  final String sedeId;
  int campos;
}

/// Un día de juego: de qué hora a qué hora y en qué sedes (con cuántos campos cada una).
class _Franja {
  _Franja(this.dia, this.desde, this.hasta, this.sedes);
  DateTime dia;
  TimeOfDay desde;
  TimeOfDay hasta;
  final List<_SedeFranja> sedes;

  DateTime _en(TimeOfDay h) => DateTime(dia.year, dia.month, dia.day, h.hour, h.minute);

  Map<String, dynamic> aJson() => {
        'inicio': _en(desde).toUtc().toIso8601String(),
        'fin': _en(hasta).toUtc().toIso8601String(),
        'sedes': [for (final s in sedes) {'sede': s.sedeId, 'campos': s.campos}],
      };
}

/// "Sub 12 femenino" y "Sub 12", o "Infantil F8 femenino" y "F8 Infantil", son la misma categoría.
String _normalizar(String s) {
  final palabras = s.toLowerCase().replaceAll('femenino', '').split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList()
    ..sort();
  return palabras.join(' ');
}

(TimeOfDay, TimeOfDay) _horas(Franja f) => switch (f) {
      Franja.manana => (const TimeOfDay(hour: 9, minute: 0), const TimeOfDay(hour: 14, minute: 0)),
      Franja.tarde => (const TimeOfDay(hour: 16, minute: 0), const TimeOfDay(hour: 21, minute: 0)),
      Franja.todoElDia => (const TimeOfDay(hour: 9, minute: 0), const TimeOfDay(hour: 21, minute: 0)),
    };

/// Días y sedes de esta liga según el cuadro «Qué se juega, cuándo y dónde».
List<_Franja> _segunHorario(Liga liga) {
  final cat = datos.categoria(liga.categoriaId);
  if (cat == null) return [];
  final nombre = _normalizar(cat.nombre);
  final porClave = <String, _Franja>{};
  for (final d in Contenido.horario) {
    for (var i = 0; i < d.sedes.length && i < datos.sedes.length; i++) {
      for (final b in d.sedes[i]) {
        if (_normalizar(b.categoria) != nombre) continue;
        if (!b.niveles.any((n) => n.id == liga.nivelId)) continue;
        final (desde, hasta) = _horas(b.franja);
        final clave = '${d.dia}-${b.franja.name}';
        final f = porClave.putIfAbsent(clave, () => _Franja(d.dia, desde, hasta, []));
        f.sedes.add(_SedeFranja(datos.sedes[i].id));
      }
    }
  }
  final lista = porClave.values.toList()..sort((a, b) => a._en(a.desde).compareTo(b._en(b.desde)));
  return lista;
}

Future<DatosLiguilla?> pedirLiguilla(BuildContext context, Liga liga) =>
    showDialog<DatosLiguilla>(context: context, builder: (_) => _DialogoLiguilla(liga));

class _DialogoLiguilla extends StatefulWidget {
  const _DialogoLiguilla(this.liga);
  final Liga liga;

  @override
  State<_DialogoLiguilla> createState() => _DialogoLiguillaState();
}

class _DialogoLiguillaState extends State<_DialogoLiguilla> {
  late final List<_Franja> _franjas;
  late final bool _delHorario;
  final _minutos = TextEditingController(text: '30');
  bool _repartir = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final h = _segunHorario(widget.liga);
    _delHorario = h.isNotEmpty;
    if (h.isNotEmpty) {
      _franjas = h;
    } else {
      final inicio = datos.torneo?.inicio.toLocal() ?? DateTime.now();
      _franjas = [
        _Franja(DateTime(inicio.year, inicio.month, inicio.day), const TimeOfDay(hour: 9, minute: 0),
            const TimeOfDay(hour: 14, minute: 0), [if (datos.sedes.isNotEmpty) _SedeFranja(datos.sedes.first.id)]),
      ];
    }
  }

  @override
  void dispose() {
    _minutos.dispose();
    super.dispose();
  }

  String _hora(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _aceptar() {
    final minutos = int.tryParse(_minutos.text.trim()) ?? 0;
    String? error;
    if (minutos < 5) error = 'Pon los minutos que dura cada partido (con el cambio incluido).';
    for (final f in _franjas) {
      if (f.sedes.isEmpty) error = 'Elige al menos una sede en ${diaCorto(f.dia)}.';
      if (f._en(f.hasta).isBefore(f._en(f.desde).add(Duration(minutes: minutos)))) {
        error = 'En ${diaCorto(f.dia)} la hora de fin es demasiado pronto.';
      }
    }
    if (_franjas.isEmpty) error = 'Añade al menos un día.';
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop<DatosLiguilla>(context, (
      franjas: [for (final f in _franjas) f.aJson()],
      minutos: minutos,
      repartir: _repartir && _franjas.length > 1,
    ));
  }

  Widget _tarjetaFranja(_Franja f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MarbelColors.fondoAlto,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2B35A6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text(diaCorto(f.dia)),
            onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: f.dia, firstDate: DateTime(2025), lastDate: DateTime(2030));
              if (d != null) setState(() => f.dia = d);
            },
          ),
          const Text('de'),
          OutlinedButton(
            child: Text(_hora(f.desde)),
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: f.desde);
              if (t != null) setState(() => f.desde = t);
            },
          ),
          const Text('a'),
          OutlinedButton(
            child: Text(_hora(f.hasta)),
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: f.hasta);
              if (t != null) setState(() => f.hasta = t);
            },
          ),
          IconButton(
            tooltip: 'Quitar este día',
            onPressed: () => setState(() => _franjas.remove(f)),
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF7A85)),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in datos.sedes)
            FilterChip(
              label: Text(s.corto),
              selected: f.sedes.any((x) => x.sedeId == s.id),
              onSelected: (v) => setState(() {
                if (v) {
                  f.sedes.add(_SedeFranja(s.id));
                } else {
                  f.sedes.removeWhere((x) => x.sedeId == s.id);
                }
              }),
            ),
        ]),
        for (final s in f.sedes)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Expanded(child: Text(datos.sede(s.sedeId)?.nombre ?? '', style: const TextStyle(color: MarbelColors.texto2))),
              IconButton(
                onPressed: s.campos > 1 ? () => setState(() => s.campos--) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Text('${s.campos} ${s.campos == 1 ? 'campo' : 'campos'}', style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: s.campos < 6 ? () => setState(() => s.campos++) : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ]),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: MarbelColors.tarjeta,
      title: Text('Liguilla · ${datos.nombreLiga(widget.liga.id)}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
              _delHorario
                  ? 'Días y sedes sacados del cuadro «Qué se juega, cuándo y dónde». Revisa las horas y los campos de cada sede.'
                  : 'Elige los días, las horas y las sedes donde juega esta liga.',
              style: const TextStyle(color: MarbelColors.apagado, fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (final f in _franjas) _tarjetaFranja(f),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  final ultimo = _franjas.isEmpty ? (datos.torneo?.inicio.toLocal() ?? DateTime.now()) : _franjas.last.dia;
                  _franjas.add(_Franja(DateTime(ultimo.year, ultimo.month, ultimo.day), const TimeOfDay(hour: 9, minute: 0),
                      const TimeOfDay(hour: 14, minute: 0), []));
                }),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Añadir otro día'),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _minutos,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minutos por partido (con el cambio incluido)'),
            ),
            if (_franjas.length > 1)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _repartir,
                onChanged: (v) => setState(() => _repartir = v),
                title: const Text('Repartir los partidos entre los días'),
                subtitle: Text(
                  _repartir ? 'Cada día se juega una parte de la liguilla.' : 'Se llena el primer día y lo que no quepa pasa al siguiente.',
                  style: const TextStyle(color: MarbelColors.apagado, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Nadie juega dos partidos a la vez, se intenta que nadie juegue dos seguidos y que cada equipo se quede en la misma sede ese día. '
              'Se respetan los campos que ya usan otras ligas. Luego puedes mover cualquier partido en «Partidos y resultados».',
              style: TextStyle(color: MarbelColors.apagado, fontSize: 12),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFFF7A85), fontWeight: FontWeight.w600)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _aceptar, child: const Text('GENERAR')),
      ],
    );
  }
}
