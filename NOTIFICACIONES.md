# Notificaciones push (con la app cerrada)

Con esto, quien active las notificaciones recibe en el móvil, **aunque tenga la app cerrada**:

| Cuándo | Ejemplo | A quién |
|---|---|---|
| 15 min antes de un partido | ⏰ C.F. Rafal – Kelme C.F. empieza en 15 min | Quien sigue a esos equipos y tiene «hora y campo» activado |
| Cambio de hora, sede o campo | 📍 Cambio: … Ahora a las 10:15 en Rafal, Campo 2 | Ídem |
| Empieza el partido | 🔴 ¡Empieza! C.F. Rafal – Kelme C.F. | Quien sigue a esos equipos y tiene «resultados» activado |
| Gol | ⚽ ¡Gol de C.F. Rafal! · C.F. Rafal 1 – 0 Kelme C.F. | Ídem |
| Final | ✅ Final: C.F. Rafal 2 – 1 Kelme C.F. | Ídem |
| Aviso para todo el mundo | 📣 Hay fruta y agua en las 4 sedes | Quien tiene «avisos generales» activado |
| Aviso para una sede, categoría o equipo | 🕒 Retraso de 10 min en Rafal | Quien sigue a equipos que juegan allí, son de esa categoría o es ese equipo |
| 1 h antes de que cierre La Porra | 🎯 La Porra cierra pronto | Quien tiene «cierre de La Porra» activado |

No usa Firebase ni ninguna cuenta nueva. Funciona con el estándar de los navegadores (Web Push), y lo envía una función de tu Supabase.

- **Android:** funciona en Chrome, con la app instalada o sin instalar.
- **iPhone:** solo funciona con la app **instalada en la pantalla de inicio** y abierta desde el icono, con iOS 16.4 o posterior.

Tiempo: unos 20 minutos.

---

## 1. Copiar los archivos

Extrae `marbel-cup-notificaciones.zip` **dentro** de `C:\proyectos\marbel_torneo\marbel-cup` → **Reemplazar**.

## 2. Generar las claves (una sola vez)

1. Abre la carpeta `tools` y haz doble clic en `generar-claves-push.html` (se abre en Chrome o Edge).
2. Salen dos claves: la **pública** y la **privada**. **Deja la página abierta** hasta terminar el paso 6. Si la recargas, salen otras distintas.

La privada no la pongas nunca en `env.json` ni en GitHub. Solo va en Supabase.

## 3. Supabase: guardar las claves

1. Supabase → tu proyecto → **Edge Functions** (menú de la izquierda) → **Secrets**.
2. Añade estos dos (botón **Add new secret**):
   - Name `VAPID_PUBLIC_KEY` → Value: la clave **pública**
   - Name `VAPID_PRIVATE_KEY` → Value: la clave **privada**
3. Pulsa **Save**.

## 4. Supabase: crear la función que envía

1. **Edge Functions** → **Deploy a new function** → **Via Editor**.
2. Como nombre pon exactamente `notificar`.
3. Borra el código de ejemplo que aparece.
4. Abre `supabase/functions/notificar/index.ts` con el Bloc de notas, copia todo y pégalo.
5. Pulsa **Deploy function** y espera a que diga que está desplegada.
6. Dentro de la función, en sus ajustes (**Details** o **Settings**), **desactiva «Verify JWT»**. Puede aparecer como *Enforce JWT verification* o *Verify JWT with legacy secret*. Luego pulsa **Save**.

¿Por qué el paso 6? La base de datos llama a esta función sin clave. Es seguro: la función no acepta datos de fuera, solo envía lo que la propia base de datos ha apuntado en su cola.

## 5. Supabase: ejecutar el SQL

1. Abre `supabase/06_notificaciones.sql` con el Bloc de notas.
2. Busca la línea que acaba en `-- <<< cambia esto` y cambia `https://TU-PROYECTO.supabase.co` por tu dirección de Supabase. Es la misma `SUPABASE_URL` de tu `env.json`.
3. Copia todo → **SQL Editor** → **New query** → pega → **Run**. Si sale el aviso de «destructive operations», dale a **Run query**.

Si te sale un error con `pg_cron` o `pg_net`: ve a **Database → Extensions**, activa **pg_cron** y **pg_net**, y vuelve a ejecutar.

## 6. La clave pública en la app

1. En tu `env.json` añade una línea más. Ojo con la coma al final de la línea anterior:
   ```json
   {
     "SUPABASE_URL": "…",
     "SUPABASE_ANON_KEY": "…",
     "VAPID_PUBLIC_KEY": "pega-aquí-la-clave-PÚBLICA"
   }
   ```
2. En GitHub → **Settings → Secrets and variables → Actions → Variables** → **New repository variable**:
   - Name `VAPID_PUBLIC_KEY` → Value: la clave **pública** → **Add variable**.

Ya puedes cerrar la página de las claves.

## 7. Publicar

```
git add .
git commit -m "Notificaciones push"
git push
```

Espera al ✓ verde en **Actions** (unos 3 minutos).

## 8. Probar

1. En el **móvil Android**, abre la app (instalada o en Chrome) y ciérrala y ábrela un par de veces para que coja la versión nueva.
2. Ve a **Más → Avisos y notificaciones** y pulsa **Activar notificaciones** → **Permitir**.
3. Sigue a algún equipo con ★ en **Equipos**.
4. **Cierra la app.**
5. Desde el ordenador, en el **Panel → Avisos**, publica un aviso «Para todo el mundo».
6. En unos segundos debería llegarte al móvil.

En **iPhone** es igual, pero abriendo la app **desde el icono de la pantalla de inicio**. Desde Safari, la app te dirá que primero la instales.

También funciona en Chrome del ordenador, incluso probando en `localhost:5000`.

## Si no llega

- **Supabase → Edge Functions → notificar → Logs.** Ahí se ve cada envío. Si pone *Faltan los secretos VAPID…*, revisa el paso 3.
- **SQL Editor:**
  ```sql
  select count(*) from suscripciones_push;              -- móviles con notificaciones activadas
  select * from cola_push order by id desc limit 10;    -- lo último que se ha mandado (enviado = cuándo)
  select * from config_push;                            -- debe tener tu dirección, no TU-PROYECTO
  ```
  - Si `cola_push` tiene filas con `enviado` vacío, la función no se está llamando: revisa el paso 4.6 (Verify JWT desactivado) y que en `config_push` está tu dirección.
  - Si `suscripciones_push` está a 0, el móvil no llegó a activarlas: mira el paso 8.
- **Android:** en Ajustes → Aplicaciones → Chrome (o Marbel Cup) → Notificaciones, comprueba que están permitidas.

Si cambias de móvil o borras los datos del navegador, hay que volver a pulsar «Activar notificaciones». Los móviles que desinstalan la app se borran solos de la lista.
