# Marbel Cup · versión completa: cómo ponerla en marcha

Pasos para dejarlo todo funcionando: web pública, app instalable en Android e iPhone, La Porra y panel de gestión. Ya tienes hecho el Paso 1 (Supabase con 01, 02 y 03, GitHub y la web publicada), así que esto es lo que falta.

Tiempo aproximado: 30 minutos.

---

## 1. Copiar los archivos nuevos

1. Clic derecho en `marbel-cup-completo.zip` → **Extraer todo...**
2. Como destino pon `C:\proyectos\marbel_torneo\marbel-cup` → **Extraer**.
3. Cuando Windows pregunte, elige **Reemplazar los archivos en el destino**.

Tu `env.json` y la carpeta oculta `.git` no se tocan, porque no van en el zip. Puedes borrar `PASO_1.md`, que ya no sirve.

## 2. Base de datos: ejecutar el último SQL

1. Abre Supabase → tu proyecto → **SQL Editor** → **New query**.
2. Abre `supabase/04_completo.sql` con el Bloc de notas, copia **todo**, pégalo y pulsa **Run**.
3. Debe acabar en *Success. No rows returned*. Si lo ejecutas dos veces no pasa nada.
4. Haz lo mismo con `supabase/05_varios_roles.sql` (permite dar varios roles a una persona, por ejemplo Mesa de sede + Comunicación).

Esto añade:

- Clasificaciones y goleadores.
- La generación automática del calendario, de las semifinales, del partido por el 3er y 4º puesto y de la final.
- El ranking de La Porra.
- La galería y los escudos.
- Las carpetas para subir fotos.
- Los permisos de cada rol.

## 3. Supabase: direcciones para los emails

Sin esto, los enlaces de "confirma tu email" y "recuperar contraseña" no vuelven a la web.

1. Ve a Supabase → **Authentication** → **URL Configuration**.
2. En **Site URL** pon `https://sripoll14.github.io/marbel-cup/`.
3. En **Redirect URLs** pulsa **Add URL** y añade estas dos:
   - `https://sripoll14.github.io/marbel-cup/**`
   - `http://localhost:5000/**`
4. Pulsa **Save**.

Opcional: en **Authentication → Emails** puedes traducir al español los textos de los correos ("Confirm signup", "Reset password").

## 4. Probar en tu ordenador

En la terminal, dentro de `C:\proyectos\marbel_torneo\marbel-cup`:

```
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port 5000 --dart-define-from-file=env.json
```

Si `flutter analyze` saca algún **error** (los `info` y `warning` dan igual), cópiamelo tal cual y lo arreglo. El código no se ha podido compilar en mi entorno, así que es normal que salga alguno.

## 5. Hacerte administradora

1. Con la web abierta, ve a **Entrar → Crear cuenta** y regístrate con tu email.
2. Confirma el email con el enlace que te llega.
3. En Supabase → **SQL Editor** ejecuta esto, poniendo tu email:

```sql
update perfiles set rol = 'admin' where email = 'TU_EMAIL_AQUI';
```

4. Recarga la web. En el menú de tu cuenta (o en **Más**, en el móvil) aparece **Panel de gestión**. También puedes entrar directamente en `…/#/gestion`.

Desde **Panel → Personal y permisos** das acceso al resto: cada persona se crea su cuenta y tú le marcas uno o varios roles (Mesa de sede, Comunicación, Administración). A la mesa de sede, además, le asignas su sede.

## 6. Preparar el torneo desde el panel

Hazlo en este orden:

1. **Torneos**: comprueba que el IV Torneo Navideño está como *Actual* y *Publicado*.
2. **Equipos e inscripciones**: en cada equipo, **Inscribir en una liga** (categoría y nivel). Si falta algún equipo, **Nuevo equipo**. Los escudos ya vienen puestos y se pueden cambiar con **Subir escudo**.
3. **Calendario y sedes**: en cada liga, **Generar liguilla** (sede, hora del primer partido, minutos entre partidos y campos a la vez). Cuando acabe la liguilla, **Generar fase final**: crea las semifinales (1º–4º y 2º–3º), el partido por el 3er y 4º puesto y la final. Estos dos últimos se rellenan solos con los resultados.
4. **Partidos y resultados**: durante el torneo, el marcador se lleva con + y −, el estado con *Próximo / En juego / Final*, y también se cambian el campo y el retraso. Los goles con nombre se apuntan como "Hugo S." y el equipo.

## 7. Subirlo a GitHub (y se publica solo)

En la terminal:

```
git add .
git commit -m "Versión completa"
git push
```

En GitHub → pestaña **Actions** verás "Publicar web" en marcha. Cuando salga el ✓ verde (unos 3–4 minutos), la web nueva estará en https://sripoll14.github.io/marbel-cup/

Las variables `SUPABASE_URL` y `SUPABASE_ANON_KEY` ya las pusiste en el Paso 1, así que no hay que tocarlas.

## 8. Probar en el móvil (como app)

**Android (Chrome)**

1. Abre https://sripoll14.github.io/marbel-cup/
2. A los pocos segundos sale **"Instala Marbel Cup"** → **Instalar**.
3. Si no sale, usa el menú ⋮ → **Instalar aplicación** (o **Añadir a pantalla de inicio**).

**iPhone (Safari)**

1. Abre el mismo enlace en **Safari**. En Chrome para iPhone no se puede instalar.
2. Sale una ventana con los 3 pasos: **Compartir** → **Añadir a pantalla de inicio** → **Añadir**.
3. Ábrela siempre desde el icono.

Cada aviso de instalación sale una sola vez. Para volver a verlo, borra los datos del sitio en el navegador.

## 9. Qué comprobar

- [ ] Inicio: cuenta atrás, avisos, carrusel de fotos y mapa de sedes.
- [ ] Partidos: filtros por día y sede; un partido "En juego" aparece en Inicio al momento.
- [ ] Equipos: seguir un equipo (☆), y su ficha con partidos y racha.
- [ ] Estadísticas: goleadores como "Nombre I. · Equipo".
- [ ] La Porra: crear cuenta, predecir, ver el ranking. **Autorrelleno de contraseñas:** al crear cuenta, el móvil debe ofrecer una contraseña segura y guardarla; al entrar, debe rellenarla sola; al cambiarla en "¿Has olvidado tu contraseña?", debe actualizar la guardada.
- [ ] "Mantener sesión iniciada": si lo desmarcas, al cerrar y volver a abrir te pide entrar otra vez.
- [ ] Recuperar contraseña: llega el email y el enlace abre "Elige una contraseña nueva".
- [ ] Panel: cambiar un resultado en el ordenador y verlo cambiar en el móvil sin recargar.
- [ ] Pie: los enlaces de Privacidad, Aviso legal y Cookies abren sus páginas.

## Lo que queda para más adelante

- **Notificaciones push con la app cerrada.** Necesitan conectar Firebase. Mientras tanto, los avisos de tus equipos salen dentro de la app, en Inicio y en "Para ti".
- **Textos legales.** Están publicados con los huecos [entre corchetes] marcados. Rellénalos en `web/legal/*.html` (titular, NIF, domicilio, email de privacidad, plazos) y que los revise una persona experta antes del torneo.
