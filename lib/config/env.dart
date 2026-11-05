/// Datos de conexión a Supabase.
///
/// No se escriben aquí: se pasan al arrancar con
/// `--dart-define-from-file=env.json` (en tu ordenador) o desde las
/// variables del repositorio (en GitHub). Así no quedan en el código.
///
/// La clave "anon"/"publishable" es pública por diseño: la seguridad la ponen
/// las reglas (RLS) de la base de datos. NUNCA uses aquí la clave
/// "service_role"/"secret".
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get configurado =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
