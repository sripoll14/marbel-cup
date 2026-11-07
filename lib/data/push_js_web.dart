// Puente con web/push.js (solo en la web).
import 'dart:js_interop';

@JS('marbelPush')
external _MarbelPush? get _push;

extension type _MarbelPush._(JSObject _) implements JSObject {
  external bool soportado();
  external bool necesitaInstalar();
  external String permiso();
  external JSPromise<JSString> activar(String clave);
  external JSPromise<JSString> actual();
  external JSPromise<JSString> desactivar();
  external void mostrarInstalar();
}

bool soportado() => _push?.soportado() ?? false;
bool necesitaInstalar() => _push?.necesitaInstalar() ?? false;
String permiso() => _push?.permiso() ?? 'unsupported';
Future<String> activar(String clave) async => (await _push!.activar(clave).toDart).toDart;
Future<String> actual() async => _push == null ? '' : (await _push!.actual().toDart).toDart;
void mostrarInstalar() => _push?.mostrarInstalar();
Future<String> desactivar() async => _push == null ? '' : (await _push!.desactivar().toDart).toDart;
