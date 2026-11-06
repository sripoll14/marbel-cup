// Marbel Cup · Notificaciones push (Supabase Edge Function "notificar")
//
// Secretos necesarios (Edge Functions → Secrets): VAPID_PUBLIC_KEY y VAPID_PRIVATE_KEY.
// SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY los pone Supabase solo.
// Sin dependencias: el cifrado de Web Push está hecho con WebCrypto.

// ---------- Web Push (RFC 8291 aes128gcm + VAPID RFC 8292) solo con WebCrypto ----------

type Bytes = Uint8Array<ArrayBuffer>;
const enc = new TextEncoder();

function b64urlADatos(s: string): Bytes {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4);
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function datosAB64url(d: Bytes): string {
  let bin = "";
  for (const b of d) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function unir(...partes: Bytes[]): Bytes {
  const out = new Uint8Array(partes.reduce((n, p) => n + p.length, 0));
  let i = 0;
  for (const p of partes) {
    out.set(p, i);
    i += p.length;
  }
  return out;
}

async function hmac(clave: Bytes, datos: Bytes): Promise<Bytes> {
  const k = await crypto.subtle.importKey("raw", clave, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return new Uint8Array(await crypto.subtle.sign("HMAC", k, datos));
}

/** Cifra el mensaje para una suscripción (RFC 8291, un solo registro). */
async function cifrar(texto: string, p256dh: string, auth: string): Promise<Bytes> {
  const uaPublica = b64urlADatos(p256dh);
  const secreto = b64urlADatos(auth);

  const efimera = (await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"])) as CryptoKeyPair;
  const asPublica = new Uint8Array(await crypto.subtle.exportKey("raw", efimera.publicKey));
  const uaClave = await crypto.subtle.importKey("raw", uaPublica, { name: "ECDH", namedCurve: "P-256" }, false, []);
  const compartido = new Uint8Array(await crypto.subtle.deriveBits({ name: "ECDH", public: uaClave }, efimera.privateKey, 256));

  // IKM = HKDF(auth, ecdh, "WebPush: info\0" || ua_public || as_public, 32)
  const prkClave = await hmac(secreto, compartido);
  const info = unir(enc.encode("WebPush: info\0"), uaPublica, asPublica, new Uint8Array([1]));
  const ikm = (await hmac(prkClave, info)).slice(0, 32);

  const sal = crypto.getRandomValues(new Uint8Array(16));
  const prk = await hmac(sal, ikm);
  const cek = (await hmac(prk, unir(enc.encode("Content-Encoding: aes128gcm\0"), new Uint8Array([1])))).slice(0, 16);
  const nonce = (await hmac(prk, unir(enc.encode("Content-Encoding: nonce\0"), new Uint8Array([1])))).slice(0, 12);

  const clave = await crypto.subtle.importKey("raw", cek, { name: "AES-GCM" }, false, ["encrypt"]);
  const claro = unir(enc.encode(texto), new Uint8Array([2])); // 0x02 = último registro
  const cifrado = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, clave, claro));

  const rs = new Uint8Array([0, 0, 0x10, 0]); // 4096
  return unir(sal, rs, new Uint8Array([asPublica.length]), asPublica, cifrado);
}

/** Cabecera Authorization de VAPID para el servicio de push de ese endpoint. */
async function cabeceraVapid(endpoint: string, publica: string, privada: string, contacto: string): Promise<string> {
  const pub = b64urlADatos(publica);
  const jwk = {
    kty: "EC",
    crv: "P-256",
    d: privada,
    x: datosAB64url(pub.slice(1, 33)),
    y: datosAB64url(pub.slice(33, 65)),
    ext: true,
  };
  const clave = await crypto.subtle.importKey("jwk", jwk, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const cab = datosAB64url(enc.encode(JSON.stringify({ typ: "JWT", alg: "ES256" })));
  const cuerpo = datosAB64url(enc.encode(JSON.stringify({
    aud: new URL(endpoint).origin,
    exp: Math.floor(Date.now() / 1000) + 12 * 3600,
    sub: contacto,
  })));
  const firma = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, clave, enc.encode(`${cab}.${cuerpo}`)));
  return `vapid t=${cab}.${cuerpo}.${datosAB64url(firma)}, k=${publica}`;
}

interface Suscripcion {
  endpoint: string;
  p256dh: string;
  auth: string;
}

/** Envía una notificación. Devuelve el código HTTP del servicio de push. */
async function enviarPush(
  s: Suscripcion,
  mensaje: unknown,
  vapid: { publica: string; privada: string; contacto: string },
): Promise<number> {
  const cuerpo = await cifrar(JSON.stringify(mensaje), s.p256dh, s.auth);
  const r = await fetch(s.endpoint, {
    method: "POST",
    headers: {
      "Content-Encoding": "aes128gcm",
      "Content-Type": "application/octet-stream",
      TTL: "86400",
      Urgency: "high",
      Authorization: await cabeceraVapid(s.endpoint, vapid.publica, vapid.privada, vapid.contacto),
    },
    body: cuerpo,
  });
  await r.body?.cancel();
  return r.status;
}

// ---------- Qué notificación recibe cada suscripción ----------

interface Sus {
  endpoint: string;
  p256dh: string;
  auth: string;
  equipos: string[] | null;
  prefs: boolean[] | null;
}
interface Evento {
  id: number;
  tipo: "empieza" | "gol" | "final" | "cambio" | "pronto" | "aviso" | "porra";
  datos: Record<string, any>;
}
interface Mensaje {
  title: string;
  body: string;
  url: string;
  tag: string;
}
interface Contexto {
  web: string;
  equipo: Map<string, string>; // id -> nombre
  sede: Map<string, string>; // id -> nombre
  equiposPorSede: Map<string, Set<string>>; // nombre sede -> equipos que juegan allí
  equiposPorCategoria: Map<string, Set<string>>; // nombre categoría -> equipos
}

// Preferencias (mismo orden que en la app)
const HORARIOS = 0, RESULTADOS = 1, GENERALES = 3, PORRA = 4;

const hora = (iso: string) =>
  new Intl.DateTimeFormat("es-ES", { hour: "2-digit", minute: "2-digit", timeZone: "Europe/Madrid" }).format(new Date(iso));

function lugar(c: Contexto, d: Record<string, any>) {
  const s = c.sede.get(d.sede_id) ?? "";
  return [s, d.campo].filter(Boolean).join(", ");
}

/** Devuelve el mensaje y a quién mandarlo. */
function preparar(e: Evento, c: Contexto, subs: Sus[]): { mensaje: Mensaje; para: Sus[] } | null {
  const d = e.datos;
  const L = c.equipo.get(d.local_id) ?? "Local";
  const V = c.equipo.get(d.visitante_id) ?? "Visitante";
  const marcador = `${L} ${d.goles_local ?? 0} – ${d.goles_visitante ?? 0} ${V}`;
  const pref = (s: Sus, i: number) => (s.prefs ?? [true, true, true, true, false])[i] ?? false;
  const sigue = (s: Sus, ids: Iterable<string>) => {
    const mios = new Set(s.equipos ?? []);
    for (const id of ids) if (mios.has(id)) return true;
    return false;
  };
  const delPartido = (i: number) => subs.filter((s) => pref(s, i) && sigue(s, [d.local_id, d.visitante_id]));
  const tagPartido = `partido-${d.partido_id}`;
  const cal = c.web + "#/calendario";

  switch (e.tipo) {
    case "pronto":
      return {
        mensaje: { title: `⏰ ${L} – ${V} empieza en 15 min`, body: `${hora(d.hora_real)} · ${lugar(c, d)}`, url: cal, tag: tagPartido },
        para: delPartido(HORARIOS),
      };
    case "cambio":
      return {
        mensaje: { title: `📍 Cambio: ${L} – ${V}`, body: `Ahora a las ${hora(d.hora_real)} en ${lugar(c, d)}`, url: cal, tag: tagPartido },
        para: delPartido(HORARIOS),
      };
    case "empieza":
      return {
        mensaje: { title: `🔴 ¡Empieza! ${L} – ${V}`, body: `${lugar(c, d)}. Síguelo en directo.`, url: cal, tag: tagPartido },
        para: delPartido(RESULTADOS),
      };
    case "gol": {
      const quien = d.gol_de === d.visitante_id ? V : L;
      return {
        mensaje: { title: `⚽ ¡Gol de ${quien}!`, body: marcador, url: cal, tag: tagPartido },
        para: delPartido(RESULTADOS),
      };
    }
    case "final": {
      const pen = d.penaltis_local != null && d.penaltis_visitante != null
        ? ` (${d.penaltis_local}-${d.penaltis_visitante} pen.)` : "";
      return {
        mensaje: { title: `✅ Final: ${marcador}${pen}`, body: "Mira la clasificación actualizada.", url: cal, tag: tagPartido },
        para: delPartido(RESULTADOS),
      };
    }
    case "porra":
      return {
        mensaje: { title: "🎯 La Porra cierra pronto", body: `Haz tus predicciones antes de las ${hora(d.cierre)}.`, url: c.web + "#/porra", tag: "porra" },
        para: subs.filter((s) => pref(s, PORRA)),
      };
    case "aviso": {
      const texto = String(d.texto ?? "");
      const mensaje = {
        title: d.automatico ? "🕒 Aviso de la organización" : "📣 Marbel Cup",
        body: texto.length > 180 ? texto.slice(0, 177) + "…" : texto,
        url: c.web + "#/avisos",
        tag: `aviso-${d.aviso_id}`,
      };
      let para: Sus[];
      switch (d.ambito) {
        case "equipo": {
          const ids = [...c.equipo].filter(([, n]) => n === d.ambito_ref).map(([id]) => id);
          para = subs.filter((s) => (pref(s, HORARIOS) || pref(s, GENERALES)) && sigue(s, ids));
          break;
        }
        case "sede":
          para = subs.filter((s) => (pref(s, HORARIOS) || pref(s, GENERALES)) && sigue(s, c.equiposPorSede.get(d.ambito_ref) ?? []));
          break;
        case "categoria":
          para = subs.filter((s) => (pref(s, HORARIOS) || pref(s, GENERALES)) && sigue(s, c.equiposPorCategoria.get(d.ambito_ref) ?? []));
          break;
        default:
          para = subs.filter((s) => pref(s, GENERALES));
      }
      return { mensaje, para };
    }
  }
  return null;
}

// ---------- La función ----------
// La llama la base de datos (sin datos) cada vez que hay algo en cola_push.
// Coge lo pendiente, decide a quién va cada cosa y lo envía.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const VAPID = {
  publica: Deno.env.get("VAPID_PUBLIC_KEY") ?? "",
  privada: Deno.env.get("VAPID_PRIVATE_KEY") ?? "",
  contacto: "mailto:marbel.sport@gmail.com",
};
const WEB = Deno.env.get("WEB_URL") ?? "https://sripoll14.github.io/marbel-cup/";

/** Consulta a la base de datos (API REST de Supabase) con la clave de servidor. */
async function rest(ruta: string, opciones: RequestInit = {}): Promise<any> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...opciones,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
      ...(opciones.headers ?? {}),
    },
  });
  if (!r.ok) throw new Error(`${ruta}: ${r.status} ${await r.text()}`);
  return r.status === 204 ? null : r.json();
}

Deno.serve(async () => {
  try {
    if (!VAPID.publica || !VAPID.privada) {
      return Response.json({ error: "Faltan los secretos VAPID_PUBLIC_KEY y VAPID_PRIVATE_KEY" }, { status: 500 });
    }

    // 1. Coger lo pendiente (y marcarlo para que no se envíe dos veces)
    const eventos: Evento[] = await rest("cola_push?enviado=is.null&select=id,tipo,datos", {
      method: "PATCH",
      body: JSON.stringify({ enviado: new Date().toISOString() }),
    });
    if (!eventos.length) return Response.json({ eventos: 0 });
    eventos.sort((a, b) => a.id - b.id);

    // 2. Datos para escribir los mensajes y elegir destinatarios
    const [subs, equipos, sedes, torneo] = await Promise.all([
      rest("suscripciones_push?select=endpoint,p256dh,auth,equipos,prefs") as Promise<Sus[]>,
      rest("equipos?select=id,nombre"),
      rest("sedes?select=id,nombre"),
      rest("torneos?activo=is.true&select=id&limit=1"),
    ]);
    if (!subs.length) return Response.json({ eventos: eventos.length, enviados: 0 });

    const ctx: Contexto = {
      web: WEB,
      equipo: new Map(equipos.map((e: any) => [e.id, e.nombre])),
      sede: new Map(sedes.map((s: any) => [s.id, s.nombre])),
      equiposPorSede: new Map(),
      equiposPorCategoria: new Map(),
    };
    if (eventos.some((e) => e.tipo === "aviso") && torneo.length) {
      const t = torneo[0].id;
      const [partidos, ligas] = await Promise.all([
        rest(`partidos?select=sede_id,local_id,visitante_id,ligas!inner(torneo_id)&ligas.torneo_id=eq.${t}`),
        rest(`ligas?torneo_id=eq.${t}&select=categorias(nombre),liga_equipos(equipo_id)`),
      ]);
      for (const p of partidos) {
        const n = ctx.sede.get(p.sede_id);
        if (!n) continue;
        const set = ctx.equiposPorSede.get(n) ?? new Set<string>();
        if (p.local_id) set.add(p.local_id);
        if (p.visitante_id) set.add(p.visitante_id);
        ctx.equiposPorSede.set(n, set);
      }
      for (const l of ligas) {
        const n = l.categorias?.nombre;
        if (!n) continue;
        const set = ctx.equiposPorCategoria.get(n) ?? new Set<string>();
        for (const le of l.liga_equipos ?? []) set.add(le.equipo_id);
        ctx.equiposPorCategoria.set(n, set);
      }
    }

    // 3. Enviar
    let enviados = 0;
    const caducadas = new Set<string>();
    for (const e of eventos) {
      const r = preparar(e, ctx, subs);
      if (!r) continue;
      const pendientes = r.para.filter((s) => !caducadas.has(s.endpoint));
      for (let i = 0; i < pendientes.length; i += 20) {
        await Promise.all(pendientes.slice(i, i + 20).map(async (s) => {
          try {
            const estado = await enviarPush(s, r.mensaje, VAPID);
            if (estado === 404 || estado === 410) caducadas.add(s.endpoint);
            else if (estado < 300) enviados++;
            else console.error("push", estado, new URL(s.endpoint).host);
          } catch (err) {
            console.error("push", err);
          }
        }));
      }
    }

    // 4. Borrar suscripciones que ya no existen (app desinstalada, permiso quitado...)
    for (const endpoint of caducadas) {
      await rest(`suscripciones_push?endpoint=eq.${encodeURIComponent(endpoint)}`, { method: "DELETE" });
    }

    return Response.json({ eventos: eventos.length, enviados, borradas: caducadas.size });
  } catch (err) {
    console.error(err);
    return Response.json({ error: String(err) }, { status: 500 });
  }
});
