// Fuera de la web (por ejemplo, en los tests) no hay notificaciones push.
bool soportado() => false;
bool necesitaInstalar() => false;
String permiso() => 'unsupported';
Future<String> activar(String clave) async => '';
Future<String> actual() async => '';
Future<String> desactivar() async => '';
