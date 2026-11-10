// Marbel Cup · Activar y desactivar las notificaciones push desde la app.
// La app (Flutter) llama a estas funciones mediante window.marbelPush.
window.marbelPush = (function () {
  function soportado() {
    return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
  }

  function esIOS() {
    return /iPhone|iPad|iPod/.test(navigator.userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  }

  function instalada() {
    return window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
  }

  // En iPhone solo funcionan con la app instalada en la pantalla de inicio
  function necesitaInstalar() {
    return esIOS() && !instalada();
  }

  function permiso() {
    return 'Notification' in window ? Notification.permission : 'unsupported';
  }

  function aBytes(b64url) {
    const b64 = b64url.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((b64url.length + 3) % 4);
    const bin = atob(b64);
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }

  function registrar() {
    return navigator.serviceWorker.register('push-sw.js');
  }

  // Pide permiso (tiene que ser lo primero, justo al tocar el botón) y se suscribe.
  // Devuelve la suscripción en JSON, o '' si no hay permiso.
  async function activar(clave) {
    const p = await Notification.requestPermission();
    if (p !== 'granted') return '';
    const reg = await registrar();
    await navigator.serviceWorker.ready;
    let s = await reg.pushManager.getSubscription();
    if (!s) {
      s = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: aBytes(clave) });
    }
    return JSON.stringify(s.toJSON());
  }

  // Suscripción actual (si ya estaban activadas), o ''.
  async function actual() {
    if (!soportado() || Notification.permission !== 'granted') return '';
    const reg = await navigator.serviceWorker.getRegistration();
    if (!reg) return '';
    const s = await reg.pushManager.getSubscription();
    return s ? JSON.stringify(s.toJSON()) : '';
  }

  // Se da de baja. Devuelve la dirección que tenía, para borrarla del servidor.
  async function desactivar() {
    const reg = await navigator.serviceWorker.getRegistration();
    const s = reg && (await reg.pushManager.getSubscription());
    if (!s) return '';
    const endpoint = s.endpoint;
    await s.unsubscribe();
    return endpoint;
  }

  // Quita el service worker antiguo de Flutter y registra el nuestro, que guarda
  // una copia de la app para abrirla sin conexión (y recibe las notificaciones).
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function (regs) {
      regs.forEach(function (r) {
        const w = r.active || r.waiting || r.installing;
        if (w && /flutter_service_worker\.js/.test(w.scriptURL)) r.unregister();
      });
      return registrar();
    }).then(function () {
      return navigator.serviceWorker.ready;
    }).then(function (reg) {
      // Cuando la app termine de cargar, guardar también lo que ya se descargó
      setTimeout(function () {
        try {
          const urls = [location.href.split('#')[0]].concat(
            performance.getEntriesByType('resource').map(function (r) { return r.name; }));
          if (reg.active) reg.active.postMessage({ tipo: 'guardar', urls: urls });
        } catch (_) {}
      }, 8000);
    }).catch(function () {});
  }

  // Abre la ventana con los pasos para instalar la app (está en index.html)
  function mostrarInstalar() {
    var e = document.getElementById('mc-ios');
    if (e) e.classList.add('ver');
  }

  return { soportado, necesitaInstalar, permiso, activar, actual, desactivar, mostrarInstalar };
})();
