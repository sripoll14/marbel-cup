import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'data/datos.dart';
import 'data/favoritos.dart';
import 'data/notificaciones.dart';
import 'data/sesion.dart';
import 'router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Env.configurado) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }
  await favoritos.iniciar();
  await sesion.iniciar();
  datos.iniciar(); // carga en segundo plano; las pantallas muestran "cargando"
  if (Env.configurado) notificaciones.iniciar(); // notificaciones push (si estaban activadas)
  runApp(const MarbelCupApp());
}

class MarbelCupApp extends StatelessWidget {
  const MarbelCupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Marbel Cup',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.oscuro,
      routerConfig: appRouter,
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
