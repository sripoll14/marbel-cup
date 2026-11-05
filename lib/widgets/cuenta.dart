import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/datos.dart';
import '../data/sesion.dart';
import '../theme/app_theme.dart';
import 'comunes.dart';

/// Campo de texto con el estilo de la app.
class Campo extends StatelessWidget {
  const Campo({
    super.key,
    required this.etiqueta,
    required this.controller,
    this.error,
    this.obligatorio = true,
    this.password = false,
    this.autofill,
    this.teclado,
    this.ayuda,
    this.alEnviar,
  });
  final String etiqueta;
  final TextEditingController controller;
  final String? error;
  final bool obligatorio;
  final bool password;
  final Iterable<String>? autofill;
  final TextInputType? teclado;
  final String? ayuda;
  final VoidCallback? alEnviar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: etiqueta, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFC8D0F5))),
          if (obligatorio) const TextSpan(text: ' *', style: TextStyle(color: MarbelColors.cian, fontWeight: FontWeight.w800)),
        ])),
        const SizedBox(height: 6),
        _CampoTexto(
          controller: controller,
          password: password,
          autofill: autofill,
          teclado: teclado,
          error: error,
          alEnviar: alEnviar,
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: const TextStyle(color: Color(0xFFFF7A85), fontSize: 13, fontWeight: FontWeight.w600)),
        ] else if (ayuda != null) ...[
          const SizedBox(height: 4),
          Text(ayuda!, style: const TextStyle(color: MarbelColors.apagado, fontSize: 12)),
        ],
      ],
    );
  }
}

class _CampoTexto extends StatefulWidget {
  const _CampoTexto({required this.controller, required this.password, this.autofill, this.teclado, this.error, this.alEnviar});
  final TextEditingController controller;
  final bool password;
  final Iterable<String>? autofill;
  final TextInputType? teclado;
  final String? error;
  final VoidCallback? alEnviar;

  @override
  State<_CampoTexto> createState() => _CampoTextoState();
}

class _CampoTextoState extends State<_CampoTexto> {
  bool _ver = false;

  @override
  Widget build(BuildContext context) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: widget.error != null ? const Color(0xFFFF7A85) : const Color(0xFF2B35A6), width: widget.error != null ? 2 : 1),
    );
    return TextField(
      controller: widget.controller,
      obscureText: widget.password && !_ver,
      autofillHints: widget.autofill,
      keyboardType: widget.teclado,
      autocorrect: !widget.password,
      enableSuggestions: !widget.password,
      onSubmitted: widget.alEnviar == null ? null : (_) => widget.alEnviar!(),
      decoration: InputDecoration(
        filled: true,
        fillColor: MarbelColors.fondoAlto,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: borde,
        border: borde,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MarbelColors.cian, width: 2),
        ),
        suffixIcon: widget.password
            ? IconButton(
                tooltip: _ver ? 'Ocultar contraseña' : 'Ver contraseña',
                onPressed: () => setState(() => _ver = !_ver),
                icon: Icon(_ver ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              )
            : null,
      ),
    );
  }
}

class CasillaMantener extends StatelessWidget {
  const CasillaMantener({super.key, required this.valor, required this.onCambio});
  final bool valor;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onCambio(!valor),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Checkbox(value: valor, onChanged: (v) => onCambio(v ?? false)),
        const Text('Mantener sesión iniciada', style: TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Formulario para entrar (email + contraseña + mantener sesión).
class FormularioEntrar extends StatefulWidget {
  const FormularioEntrar({super.key, this.alEntrar, this.alCrearCuenta});
  final VoidCallback? alEntrar;
  final VoidCallback? alCrearCuenta;

  @override
  State<FormularioEntrar> createState() => _FormularioEntrarState();
}

class _FormularioEntrarState extends State<FormularioEntrar> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _mantener = true;
  bool _cargando = false;
  String? _error;

  Future<void> _entrar() async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Escribe tu email y tu contraseña.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await sesion.entrar(_email.text, _pass.text, mantener: _mantener);
      TextInput.finishAutofillContext(); // el móvil ofrece guardar la contraseña
      widget.alEntrar?.call();
    } catch (e) {
      setState(() => _error = mensajeError(e));
    }
    if (mounted) setState(() => _cargando = false);
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Campo(
            etiqueta: 'Email',
            controller: _email,
            teclado: TextInputType.emailAddress,
            autofill: const [AutofillHints.email, AutofillHints.username],
          ),
          const SizedBox(height: 12),
          Campo(
            etiqueta: 'Contraseña',
            controller: _pass,
            password: true,
            autofill: const [AutofillHints.password],
            alEnviar: _entrar,
          ),
          const SizedBox(height: 4),
          CasillaMantener(valor: _mantener, onCambio: (v) => setState(() => _mantener = v)),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF7A85), fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 10),
          BotonCian('Entrar', onTap: _entrar, cargando: _cargando),
          const SizedBox(height: 6),
          Wrap(alignment: WrapAlignment.spaceBetween, children: [
            TextButton(onPressed: () => context.go('/recuperar'), child: const Text('He olvidado mi contraseña')),
            if (widget.alCrearCuenta != null)
              TextButton(onPressed: widget.alCrearCuenta, child: const Text('Crear cuenta')),
          ]),
        ],
      ),
    );
  }
}

/// Formulario de registro para La Porra.
class FormularioRegistro extends StatefulWidget {
  const FormularioRegistro({super.key, this.alEntrar, this.alTenerCuenta});
  final VoidCallback? alEntrar;
  final VoidCallback? alTenerCuenta;

  @override
  State<FormularioRegistro> createState() => _FormularioRegistroState();
}

class _FormularioRegistroState extends State<FormularioRegistro> {
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String? _equipo; // '' = sin equipo
  bool _privacidad = false;
  bool _edad = false;
  bool _mantener = true;
  bool _intentado = false;
  bool _cargando = false;
  String? _error;
  bool _revisaCorreo = false;

  Map<String, String?> _errores() => {
        'n': _nombre.text.trim().isEmpty ? 'Escribe tu nombre' : null,
        'a': _apellidos.text.trim().isEmpty ? 'Escribe tus apellidos' : null,
        'e': validarEmail(_email.text),
        'p': validarPassword(_pass.text),
        't': _equipo == null ? 'Elige tu equipo o «No pertenezco a ningún equipo»' : null,
        'ok': _privacidad ? null : 'Tienes que aceptar la política de privacidad',
        'edad': _edad ? null : 'Tienes que confirmarlo para crear la cuenta',
      };

  Future<void> _crear() async {
    setState(() => _intentado = true);
    if (_errores().values.any((e) => e != null)) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final confirmar = await sesion.registrar(
        nombre: _nombre.text,
        apellidos: _apellidos.text,
        email: _email.text,
        password: _pass.text,
        equipoId: _equipo == '' ? null : _equipo,
        mantener: _mantener,
      );
      TextInput.finishAutofillContext();
      if (confirmar) {
        setState(() => _revisaCorreo = true);
      } else {
        widget.alEntrar?.call();
      }
    } catch (e) {
      setState(() => _error = mensajeError(e));
    }
    if (mounted) setState(() => _cargando = false);
  }

  @override
  void dispose() {
    for (final c in [_nombre, _apellidos, _email, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_revisaCorreo) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.mark_email_read_rounded, size: 48, color: MarbelColors.cian),
        const SizedBox(height: 10),
        Text('REVISA TU CORREO', style: MarbelText.titular(30)),
        const SizedBox(height: 8),
        Text('Te hemos enviado un enlace a ${_email.text.trim()} para confirmar tu cuenta. '
            'Ábrelo y ya podrás jugar. Mira también en la carpeta de spam.',
            style: const TextStyle(color: MarbelColors.texto2, height: 1.4)),
      ]);
    }
    final err = _intentado ? _errores() : <String, String?>{};
    final equipos = [...datos.equipos]..sort((a, b) => a.nombre.compareTo(b.nombre));
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text.rich(TextSpan(children: [
            TextSpan(text: 'Los campos con '),
            TextSpan(text: '*', style: TextStyle(color: MarbelColors.cian, fontWeight: FontWeight.w800)),
            TextSpan(text: ' son obligatorios.'),
          ]), style: TextStyle(color: MarbelColors.apagado, fontSize: 13)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final dos = c.maxWidth > 460;
            final n = Campo(etiqueta: 'Nombre', controller: _nombre, error: err['n'], autofill: const [AutofillHints.givenName]);
            final a = Campo(etiqueta: 'Apellidos', controller: _apellidos, error: err['a'], autofill: const [AutofillHints.familyName]);
            return dos
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: n), const SizedBox(width: 12), Expanded(child: a)])
                : Column(children: [n, const SizedBox(height: 12), a]);
          }),
          const SizedBox(height: 12),
          Campo(
            etiqueta: 'Email',
            controller: _email,
            error: err['e'],
            teclado: TextInputType.emailAddress,
            autofill: const [AutofillHints.email, AutofillHints.username],
          ),
          const SizedBox(height: 12),
          Campo(
            etiqueta: 'Contraseña',
            controller: _pass,
            error: err['p'],
            password: true,
            autofill: const [AutofillHints.newPassword],
            ayuda: 'Mínimo 8 caracteres, con una minúscula y un número. Tu móvil puede sugerirte una segura y guardarla.',
          ),
          const SizedBox(height: 12),
          const Text.rich(TextSpan(children: [
            TextSpan(text: '¿De qué equipo eres?'),
            TextSpan(text: ' *', style: TextStyle(color: MarbelColors.cian, fontWeight: FontWeight.w800)),
          ]), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFC8D0F5))),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _equipo,
            isExpanded: true,
            dropdownColor: MarbelColors.tarjeta,
            hint: const Text('Elige una opción'),
            decoration: InputDecoration(
              filled: true,
              fillColor: MarbelColors.fondoAlto,
              isDense: true,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: err['t'] != null ? const Color(0xFFFF7A85) : const Color(0xFF2B35A6)),
              ),
            ),
            items: [
              for (final e in equipos) DropdownMenuItem(value: e.id, child: Text(e.nombre)),
              const DropdownMenuItem(value: '', child: Text('No pertenezco a ningún equipo')),
            ],
            onChanged: (v) => setState(() => _equipo = v),
          ),
          if (err['t'] != null) ...[
            const SizedBox(height: 4),
            Text(err['t']!, style: const TextStyle(color: Color(0xFFFF7A85), fontSize: 13, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 10),
          _Casilla(
            valor: _edad,
            onCambio: (v) => setState(() => _edad = v),
            error: err['edad'],
            child: const Text('Tengo 14 años o más, o tengo permiso de mi padre, madre o tutor para crear la cuenta.'),
          ),
          _Casilla(
            valor: _privacidad,
            onCambio: (v) => setState(() => _privacidad = v),
            error: err['ok'],
            child: Text.rich(TextSpan(children: [
              const TextSpan(text: 'Acepto la '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: InkWell(
                  onTap: () => abrirLegal('privacidad'),
                  child: const Text('política de privacidad',
                      style: TextStyle(color: MarbelColors.cian, decoration: TextDecoration.underline, decorationColor: MarbelColors.cian)),
                ),
              ),
              const TextSpan(text: ' *. En el ranking solo se verá mi nombre, la inicial del apellido y mi equipo.'),
            ])),
          ),
          CasillaMantener(valor: _mantener, onCambio: (v) => setState(() => _mantener = v)),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF7A85), fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 10),
          BotonCian('Crear cuenta y jugar', onTap: _crear, cargando: _cargando),
          if (widget.alTenerCuenta != null) ...[
            const SizedBox(height: 6),
            TextButton(onPressed: widget.alTenerCuenta, child: const Text('Ya tengo cuenta · Entrar')),
          ],
        ],
      ),
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({required this.valor, required this.onCambio, required this.child, this.error});
  final bool valor;
  final ValueChanged<bool> onCambio;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Checkbox(
          value: valor,
          onChanged: (v) => onCambio(v ?? false),
          side: BorderSide(color: error != null ? const Color(0xFFFF7A85) : MarbelColors.apagado, width: 2),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 14, height: 1.35), child: child),
          ),
        ),
      ]),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(left: 48, bottom: 6),
          child: Text(error!, style: const TextStyle(color: Color(0xFFFF7A85), fontSize: 13, fontWeight: FontWeight.w600)),
        ),
    ]);
  }
}
