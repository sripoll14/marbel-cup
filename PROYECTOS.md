# Proyectos de torneo

Cada torneo de la web es un **proyecto**: un archivo `.json` con todo su contenido
(portada, información, horarios, precios, preguntas…). La web no tiene nada de
ningún torneo escrito en el código: enseña lo que diga el proyecto.

- **Panel → Torneos → «Nuevo torneo (subir proyecto)»**: sube un archivo y crea el
  torneo (en curso pero **oculto**, para revisarlo antes de publicarlo).
- **«Actualizar proyecto»**: cambia el contenido de un torneo que ya existe por el
  de otro archivo. Equipos, ligas, partidos, resultados y La Porra no se tocan.
- **«Descargar proyecto»**: da el archivo de un torneo. Sirve de copia de
  seguridad y para preparar otro a partir de él (por ejemplo, el del año que viene).

Lo «vivo» (equipos inscritos, ligas, calendario, resultados, clasificaciones,
La Porra, avisos) no va en el archivo: se gestiona en el panel como siempre.

En la carpeta `proyectos/` está el del IV Torneo Navideño (`iv-torneo-navideno.json`)
como ejemplo completo, y `ejemplo-minimo.json` con lo mínimo para empezar.

---

## Cómo se edita

Con cualquier editor de texto (el Bloc de notas vale; mejor Visual Studio Code,
que avisa si falta una coma). Reglas del formato JSON:

- Los textos van entre comillas dobles: `"Fútbol 8"`.
- Entre elementos, una coma; después del último, **ninguna**.
- Un salto de línea dentro de un texto se escribe `\n`.
- `null` = vacío (por ejemplo, un cabeza de serie aún por anunciar).

Si el archivo tiene un error, el panel lo dice al subirlo y no cambia nada.

---

## Datos generales

```json
{
  "formato": "marbel-cup-torneo",
  "version": 1,
  "nombre": "IV Torneo Navideño 26-27",
  "fechas": "26-27 dic · 2-3 ene",
  "inicio": "2026-12-26T09:00:00+01:00",
  "inscripcion_hasta": "2026-12-20",
  "jornadas": ["2026-12-26", "2026-12-27", "2027-01-02", "2027-01-03"],
  "horas": { "desde": "09:00", "hasta": "21:00" },
  "sedes": ["Albatera", "Granja de Rocamora", "Rafal", "Bigastro"],
  "portada": { ... },
  "inicio_bloques": [ ... ],
  "info_bloques": [ ... ]
}
```

| Campo | Qué es |
| --- | --- |
| `formato`, `version` | Siempre `"marbel-cup-torneo"` y `1`. **Obligatorio.** |
| `nombre` | Nombre del torneo. **Obligatorio.** |
| `fechas` | Fechas en texto, como se quieren ver. **Obligatorio.** |
| `inicio` | Primer partido (fecha y hora, para la cuenta atrás). **Obligatorio.** En invierno `+01:00`, en verano `+02:00`. |
| `inscripcion_hasta` | Último día de inscripción (opcional). |
| `jornadas` | Días de juego (cuenta atrás y calendario). Si no se ponen, salen de los partidos. |
| `horas` | De qué hora a qué hora se juega cada día (por defecto, de 9:00 a 21:00). |
| `sedes` | Sedes en orden, por su nombre. Si una no existe, se crea al subir el proyecto. Para darle todos sus datos: `{"nombre": "Cartagena", "nombre_oficial": "Campo EF Santa Ana", "maps_url": "https://maps.app.goo.gl/...", "servicios": ["Cantina", "Aparcamiento"], "foto_url": "https://..."}` |
| `equipos` | Normalmente no se pone: en «Equipos» salen los clubes inscritos en este torneo (apuntados en el panel, con liga o sin ella). `"todos"` = salen todos los clubes de la web. |

### `portada`

```json
"portada": {
  "etiqueta": "Fútbol base · F8 y F11 · Masculino y femenino",
  "lema": "Fútbol, diversión y competición en un torneo único…",
  "donde": "Vega Baja · 4 sedes",
  "titulo_info": ["IV Torneo", "Navideño"],
  "datos": [["Fechas", "26–27 dic · 2–3 ene"], ["Sedes", "4 en la Vega Baja"]],
  "inscripcion": "Inscripción hasta el 20 de diciembre · plazas limitadas",
  "inscripcion_url": "https://wa.me/34689355868"
}
```

- `etiqueta`: línea pequeña encima del nombre, en la portada.
- `lema`: frase de la portada (en ordenador).
- `donde`: «Dónde» en la portada y en la tarjeta de «Torneos actuales».
- `titulo_info`: título grande de la página de información, en líneas (la última sale en cian).
- `datos`: tarjetas de la página de información (título y valor).
- `inscripcion`: texto de la pantalla «Equipos».
- `inscripcion_url`: adónde lleva el botón «Inscribe tu equipo» de ese torneo (un enlace de WhatsApp, un formulario…). Si no se pone, al WhatsApp de Marbel.

---

## Bloques

`inicio_bloques` son los que salen en la **portada** del torneo (cuando es el único en marcha) e
`info_bloques` los de la **página de información** del torneo. Salen en el orden
en que estén. Para quitar uno sin borrarlo: `"oculto": true`.

Casi todos admiten `"etiqueta"` (texto pequeño encima), `"titulo"` y `"subtitulo"`.

### `niveles` — tarjetas de nivel y listas

```json
{"tipo": "niveles", "titulo": "Tú eliges el nivel",
 "niveles": [["iniciacion", "Para equipos que empiezan"], ["medio", "Competición equilibrada"],
             ["elite", "Máximo nivel competitivo"], ["femenino", "Sub 12 e Infantil F8"]],
 "listas": [{"titulo": "Masculino", "items": ["Prebenjamín 1º y 2º año", "Benjamín 1º y 2º año"]},
            {"titulo": "¿Quién puede participar?", "items": ["Escuelas", "Academias"], "prefijo": "→ "}]}
```
Niveles: `iniciacion`, `medio`, `elite`, `femenino`.

### `mapa_sedes` — mapa de la Vega Baja con las sedes

```json
{"tipo": "mapa_sedes", "etiqueta": "Vega Baja · Alicante", "titulo": "4 sedes, 10–15 min entre ellas"}
```
Si alguna sede no tiene coordenadas (está fuera del mapa), salen tarjetas en su lugar.

### `sedes` — tarjetas de las sedes (foto, servicios, cómo llegar)

```json
{"tipo": "sedes", "titulo": "Las sedes"}
```

### `horario` — qué se juega cada día en cada sede

```json
{"tipo": "horario", "titulo": "Qué se juega, cuándo y dónde", "nota": "Toca un nivel para resaltar…",
 "dias": [
   {"dia": "2026-12-26", "sedes": [
     [{"categoria": "Infantil F11", "niveles": ["iniciacion", "medio"], "franja": "todo"}],
     [],
     [{"categoria": "Benjamín 1º año", "niveles": ["medio"], "franja": "manana"},
      {"categoria": "Benjamín 2º año", "niveles": ["medio"], "franja": "tarde"}]
   ]}
 ]}
```
`sedes` va en el mismo orden que las `sedes` del proyecto (una lista por sede; `[]` = esa sede no
se usa ese día). `franja`: `manana`, `tarde` o `todo`. Este cuadro también sale en el
calendario y rellena solo los días y sedes al «Generar liguilla».

### `lista_iconos` — tarjetas con icono (qué incluye…)

```json
{"tipo": "lista_iconos", "titulo": "Qué incluye",
 "items": [["silbato", "Árbitros federados"], ["agua", "Fruta y agua"]],
 "destacados": [{"icono": "medalla", "texto": "Los 3 primeros: trofeo…", "estilo": "relleno"},
                {"icono": "fiesta", "texto": "Ceremonia final…", "estilo": "borde"}]}
```
Iconos: `calendario`, `silbato`, `balon`, `agua`, `musica`, `camara`, `micro`, `seguro`,
`pulsera`, `medalla`, `trofeo`, `estrella`, `fiesta`, `reloj`, `ubicacion`, `euro`,
`comida`, `parking`, `bus`, `info`, `grupo`, `regalo`, `corazon`.

### `equipos_destacados` — cabezas de serie

```json
{"tipo": "equipos_destacados", "titulo": "Categoría Élite", "equipos": ["F.C. Cartagena SAD", null, null]}
```
`null` = «Por anunciar». Si el nombre coincide con un equipo de la web, sale su escudo.

### `precios` — precios, pasos para inscribirse y aviso

```json
{"tipo": "precios", "titulo": "Precios y cómo participar", "pastilla": "Plazas limitadas",
 "precios": [["Fútbol 8", "200€", "por equipo"], ["Fútbol 11", "250€", "por equipo"]],
 "pasos": [["Reserva del equipo", "Con una cuota de 100€."]],
 "aviso": "El importe de la reserva no se devuelve.", "botones": true}
```
`botones: true` añade «Reservar por WhatsApp» y «Escribir un email».

### `preguntas` — preguntas frecuentes

```json
{"tipo": "preguntas", "titulo": "Preguntas frecuentes",
 "items": [["¿Puedo elegir el nivel?", "Sí. Al inscribiros…"]]}
```

### `texto`, `imagen`, `contacto`, `opinion`

```json
{"tipo": "texto", "titulo": "Normativa", "texto": "Primer párrafo.\n\nSegundo párrafo."}
{"tipo": "imagen", "titulo": "Cartel", "url": "https://…/cartel.jpg", "pie": "Cartel oficial"}
{"tipo": "contacto", "titulo": "¿Dudas?", "texto": "Escríbenos y te contamos."}
{"tipo": "opinion", "titulo": "Déjanos tu opinión"}
```
`imagen`: la dirección de una imagen de internet (por ejemplo, una foto subida a la galería o a un aviso).
`opinion`: el formulario «Déjanos tu opinión» (solo lo lee administración).

---

Si un proyecto no trae `info_bloques`, la página de información enseña sus sedes,
los botones de contacto y «Déjanos tu opinión». «Déjanos tu opinión» sale siempre al
final de la información del torneo (si el proyecto no lo pone, se añade solo).
