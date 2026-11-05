# Marbel Cup

Web y app de **Marbel Football Cup**, torneos de fútbol base en la Vega Baja (Alicante).

- **Flutter**: un solo código para web, Android e iPhone.
- **Supabase**: base de datos, cuentas y tiempo real.
- **GitHub Pages**: la web se publica sola al subir cambios a `main`.

Web publicada: https://sripoll14.github.io/marbel-cup/

## Arrancar en tu ordenador

```
flutter pub get
flutter run -d chrome --dart-define-from-file=env.json
```

`env.json` (no se sube a GitHub) lleva la URL y la clave pública de Supabase.
Hay un ejemplo en `env.example.json`.

## Carpetas

| Carpeta | Qué hay |
| --- | --- |
| `lib/` | Código de la app |
| `lib/theme/` | Colores y tipografías de Marbel |
| `lib/screens/` | Pantallas |
| `lib/widgets/` | Piezas reutilizables (marco, logo...) |
| `assets/` | Logo y tipografías Barlow (licencia OFL) |
| `supabase/` | SQL de la base de datos, en orden |
| `.github/workflows/` | Publicación automática de la web |

## Privacidad

No se publican plantillas ni datos personales de jugadores. En estadísticas solo
aparece "Nombre I." junto al equipo. Las reglas de acceso están en
`supabase/01_esquema.sql` (RLS).
