import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/sesion.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/cuenta.dart';
import '../widgets/marco_app.dart';

/// Recuperar contraseña: 1) pedir el enlace por email; 2) (al abrir el enlace)
/// elegir la nueva. Sirve para La Porra y para el panel de gestión.
class RecuperarScreen extends StatefulWidget {
  const RecuperarScreen({super.key});

  @override
  State<RecuperarScreen> createState() => _RecuperarScreenState();
}

class _RecuperarScreenState extends State<RecuperarScreen> {
  final _email = TextEditingController();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _enviado = false;
  bool _cambiada = false;
  bool _cargando = false;
  String? _error;
  int _esperar = 0;

  Future<void> _enviar() async {
    final e = validarEmail(_email.text);
    if (e != null) {
      setState(() => _error = e);
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await sesion.pedirRecuperacion(_email.text);
      setState(() {
        _enviado = true;
        _esperar = 60;
      });
      _cuentaAtras();
    } catch (e) {
      setState(() => _error = mensajeError(e));
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cuentaAtras() async {
    while (_esperar > 0 && mounted) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _esperar--);
    }
  }

  Future<void> _guardar() async {
    final e = validarPassword(_p1.text);
    if (e != null) {
      setState(() => _error = e);
      return;
    }
    if (_p1.text != _p2.text) {
      setState(() => _error = 'Las dos contraseñas no coinciden');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await sesion.cambiarPassword(_p1.text);
      TextInput.finishAutofillContext(); // el móvil actualiza la contraseña guardada
      setState(() => _cambiada = true);
    } catch (e) {
      setState(() => _error = mensajeError(e));
    }
    if (mounted) setState(() => _cargando = false);
  }

  @override
  void dispose() {
    _email.dispose();
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sesion,
      builder: (context, _) {
        Widget cuerpo;
        if (_cambiada) {
          cuerpo = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.check_circle_rounded, size: 56, color: MarbelColors.elite),
            const SizedBox(height: 10),
            Text('CONTRASEÑA CAMBIADA', style: MarbelText.titular(34)),
            const SizedBox(height: 8),
            const Text('Ya puedes entrar con tu contraseña nueva. Por seguridad hemos cerrado la sesión en tus otros dispositivos.',
                style: TextStyle(color: MarbelColors.texto2, height: 1.4)),
            const SizedBox(height: 16),
            BotonCian('Ir a la web', onTap: () => context.go('/')),
          ]);
        } else if (sesion.modoNuevaPassword) {
          cuerpo = AutofillGroup(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('ELIGE UNA CONTRASEÑA NUEVA', style: MarbelText.titular(34)),
              const SizedBox(height: 6),
              Text('Para ${sesion.usuario?.email ?? 'tu cuenta'}.', style: const TextStyle(color: MarbelColors.texto2)),
              const SizedBox(height: 16),
              // Campo oculto con el email: ayuda al gestor de contraseñas a saber de qué cuenta es.
              Offstage(
                child: TextField(
                  controller: TextEditingController(text: sesion.usuario?.email ?? ''),
                  autofillHints: const [AutofillHints.username],
                ),
              ),
              Campo(etiqueta: 'Contraseña nueva', controller: _p1, password: true, autofill: const [AutofillHints.newPassword],
                  ayuda: 'Al menos 8 caracteres, con una letra minúscula y un número. Tu móvil puede sugerirte una segura.'),
              const SizedBox(height: 12),
              Campo(etiqueta: 'Repite la contraseña', controller: _p2, password: true, autofill: const [AutofillHints.newPassword], alEnviar: _guardar),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Color(0xFFFF7A85), fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 14),
              BotonCian('Guardar contraseña', onTap: _guardar, cargando: _cargando),
            ]),
          );
        } else if (_enviado) {
          cuerpo = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.mark_email_read_rounded, size: 56, color: MarbelColors.cian),
            const SizedBox(height: 10),
            Text('REVISA TU CORREO', style: MarbelText.titular(34)),
            const SizedBox(height: 8),
            const Text('Si hay una cuenta con ese email, te hemos enviado un enlace. Caduca en 1 hora. Mira también en la carpeta de spam.',
                style: TextStyle(color: MarbelColors.texto2, height: 1.4)),
            const SizedBox(height: 16),
            BotonContorno(_esperar > 0 ? 'Reenviar en $_esperar s' : 'Reenviar el enlace', onTap: _esperar > 0 ? null : _enviar),
          ]);
        } else {
          cuerpo = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('RECUPERAR CONTRASEÑA', style: MarbelText.titular(38)),
            const SizedBox(height: 8),
            const Text('Escribe el email de tu cuenta y te mandamos un enlace para crear una contraseña nueva. '
                'Sirve tanto para La Porra como para el panel de gestión.',
                style: TextStyle(color: MarbelColors.texto2, height: 1.4)),
            const SizedBox(height: 16),
            AutofillGroup(
              child: Campo(etiqueta: 'Email', controller: _email, teclado: TextInputType.emailAddress,
                  autofill: const [AutofillHints.email], alEnviar: _enviar, error: _error),
            ),
            const SizedBox(height: 14),
            BotonCian('Enviar enlace', onTap: _enviar, cargando: _cargando),
          ]);
        }

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      const LogoMarbel(tamano: 48),
                      const SizedBox(width: 10),
                      Text('MARBEL FOOTBALL CUP', style: MarbelText.titular(22)),
                    ]),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Volver a la web'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Tarjeta(padding: const EdgeInsets.all(22), child: cuerpo),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
