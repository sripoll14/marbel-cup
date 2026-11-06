// Marbel Cup · Service worker de notificaciones.
// Recibe los avisos del servidor y los enseña aunque la app esté cerrada.

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

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
