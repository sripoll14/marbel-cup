// Marbel Cup · Service worker.
// 1) Guarda una copia de la app para que abra aunque no haya conexión.
// 2) Recibe las notificaciones push y las enseña aunque la app esté cerrada.

const CACHE = 'marbel-app-v1';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil((async () => {
  // Borra copias de versiones anteriores de este service worker
  for (const k of await caches.keys()) if (k.startsWith('marbel-app-') && k !== CACHE) await caches.delete(k);
  await self.clients.claim();
})()));

// Lo que no se guarda: los datos (los guarda la propia app) y lo que no es de la web
function guardable(url) {
  if (url.hostname.endsWith('supabase.co') || url.hostname.endsWith('supabase.in')) return false;
  return url.protocol === 'https:' || url.hostname === 'localhost';
}

// Primero la red (así siempre llega la última versión). Sin conexión, o si la
// red tarda más de 4 segundos (cobertura mala), se usa la copia guardada.
self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (!guardable(url)) return;
  e.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const red = fetch(req).then((res) => {
      if (res && (res.ok || res.type === 'opaque')) cache.put(req, res.clone()).catch(() => {});
      return res;
    });
    let copia = await cache.match(req, { ignoreSearch: true });
    if (!copia && req.mode === 'navigate') {
      copia = await cache.match(new URL('./', self.registration.scope).href)
        || await cache.match(new URL('index.html', self.registration.scope).href);
    }
    if (!copia) return red;
    return Promise.race([
      red.catch(() => copia),
      new Promise((r) => setTimeout(() => r(copia), 4000)),
    ]);
  })());
});

// La página avisa de los archivos que ya ha cargado (la primera vez aún no
// pasaban por aquí) para guardarlos también.
self.addEventListener('message', (e) => {
  const d = e.data || {};
  if (d.tipo !== 'guardar' || !Array.isArray(d.urls)) return;
  e.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    for (const u of d.urls.slice(0, 200)) {
      try {
        const url = new URL(u, self.registration.scope);
        if (!guardable(url) || await cache.match(url.href)) continue;
        const res = await fetch(url.href, { mode: url.origin === self.location.origin ? 'same-origin' : 'cors' });
        if (res.ok) await cache.put(url.href, res);
      } catch (_) {}
    }
  })());
});

self.addEventListener('push', (e) => {
  let d = {};
  try {
    d = e.data ? e.data.json() : {};
  } catch (_) {
    d = { body: e.data ? e.data.text() : '' };
  }
  e.waitUntil(
    self.registration.showNotification(d.title || 'Marbel Cup', {
      body: d.body || '',
      icon: 'icons/Icon-192.png',
      badge: 'icons/badge-96.png',
      tag: d.tag || undefined,
      renotify: !!d.tag,
      lang: 'es',
      data: { url: d.url || './' },
    })
  );
});

// Al tocar la notificación: abre la app (o la trae al frente) en la sección que toca
self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const url = new URL((e.notification.data && e.notification.data.url) || './', self.registration.scope).href;
  e.waitUntil((async () => {
    const ventanas = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const v of ventanas) {
      if (v.url.startsWith(self.registration.scope)) {
        try {
          if (v.navigate) await v.navigate(url);
        } catch (_) {}
        return v.focus();
      }
    }
    return self.clients.openWindow(url);
  })());
});
