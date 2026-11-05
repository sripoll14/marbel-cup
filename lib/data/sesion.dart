import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'datos.dart';
import 'modelos.dart';

/// Quién está conectado y con qué rol.
class Sesion extends ChangeNotifier {
  User? usuario;
  Perfil? perfil;

  /// Se activa al abrir el enlace del email de "recuperar contraseña".
  bool modoNuevaPassword = false;

  StreamSubscription<AuthState>? _sub;

  bool get conectado => usuario != null;
  Rol get rol => perfil?.rol ?? Rol.usuario;
  bool get esPersonal => perfil?.esPersonal ?? false;
  bool get esAdmin => tiene(Rol.admin);
  bool tiene(Rol r) => perfil?.tiene(r) ?? false;

  Future<void> iniciar() async {
    if (!Env.configurado) return;

    // "Mantener sesión iniciada" desmarcado: al volver a abrir, se cierra.
    final prefs = await SharedPreferences.getInstance();
    final mantener = prefs.getBool('mantener_sesion') ?? true;
    // (No se cierra si venimos de un enlace del email: recuperar o confirmar cuenta.)
    final vieneDeEnlace = kIsWeb && Uri.base.queryParameters.containsKey('code');
    if (!mantener && !vieneDeEnlace && db.auth.currentUser != null) {
      await db.auth.signOut();
    }

    usuario = db.auth.currentUser;
    await _cargarPerfil();

    _sub = db.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        modoNuevaPassword = true;
      }
      usuario = data.session?.user;
      await _cargarPerfil();
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _cargarPerfil() async {
    final u = usuario;
    if (u == null) {
      perfil = null;
      return;
    }
    try {
      final m = await db.from('perfiles').select().eq('id', u.id).maybeSingle();
      perfil = m == null ? null : Perfil.fromMap(m);
    } catch (_) {
      perfil = null;
    }
  }

  Future<void> recargarPerfil() async {
    await _cargarPerfil();
    notifyListeners();
  }

  /// Dirección a la que vuelven los enlaces de los emails.
  String get _vuelta {
    if (kIsWeb) {
      final b = Uri.base;
      return Uri(scheme: b.scheme, host: b.host, port: b.hasPort ? b.port : null, path: b.path)
          .toString();
    }
    return 'https://sripoll14.github.io/marbel-cup/';
  }

  Future<void> _guardarMantener(bool mantener) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mantener_sesion', mantener);
  }

  Future<void> entrar(String email, String password, {required bool mantener}) async {
    await _guardarMantener(mantener);
    await db.auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Devuelve true si hay que confirmar el email antes de entrar.
  Future<bool> registrar({
    required String nombre,
    required String apellidos,
    required String email,
    required String password,
    required String? equipoId,
    required bool mantener,
  }) async {
    await _guardarMantener(mantener);
    final r = await db.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: _vuelta,
      data: {
        'nombre': nombre.trim(),
        'apellidos': apellidos.trim(),
        'equipo_id': equipoId ?? '',
      },
    );
    return r.session == null;
  }

  Future<void> salir() async {
    await db.auth.signOut();
    perfil = null;
    usuario = null;
    notifyListeners();
  }

  Future<void> pedirRecuperacion(String email) async {
    await db.auth.resetPasswordForEmail(email.trim(), redirectTo: _vuelta);
  }

  Future<void> cambiarPassword(String nueva) async {
    await db.auth.updateUser(UserAttributes(password: nueva));
    modoNuevaPassword = false;
    // Cierra la sesión en los demás dispositivos.
    await db.auth.signOut(scope: SignOutScope.others);
    notifyListeners();
  }

  Future<void> cambiarEquipo(String? equipoId) async {
    final u = usuario;
    if (u == null) return;
    await db.from('perfiles').update({'equipo_id': equipoId}).eq('id', u.id);
    await recargarPerfil();
  }

  Future<void> borrarCuenta() async {
    await db.rpc('borrar_mi_cuenta');
    await salir();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final sesion = Sesion();

/// Reglas de contraseña (las mismas en registro y recuperación).
String? validarPassword(String p) {
  if (p.isEmpty) return 'Escribe una contraseña';
  if (p.length < 8 || !RegExp(r'[a-z]').hasMatch(p) || !RegExp(r'\d').hasMatch(p)) {
    return 'Mínimo 8 caracteres, con una minúscula y un número';
  }
  return null;
}

String? validarEmail(String e) {
  final t = e.trim();
  if (t.isEmpty) return 'Escribe tu email';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Ese email no parece válido';
  return null;
}

/// Traduce los errores más comunes de Supabase.
String mensajeError(Object e) {
  final s = e is AuthException ? e.message : e.toString();
  final l = s.toLowerCase();
  if (l.contains('invalid login')) return 'Email o contraseña incorrectos.';
  if (l.contains('email not confirmed')) {
    return 'Aún no has confirmado tu email. Revisa tu correo (y la carpeta de spam).';
  }
  if (l.contains('already registered') || l.contains('already been registered')) {
    return 'Ya hay una cuenta con ese email. Prueba a entrar o a recuperar la contraseña.';
  }
  if (l.contains('rate limit') || l.contains('too many')) {
    return 'Demasiados intentos. Espera unos minutos y vuelve a probar.';
  }
  if (l.contains('should be different')) return 'La contraseña nueva debe ser distinta de la anterior.';
  return s;
}
