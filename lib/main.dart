import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/environment_config.dart';
import 'config/supabase_config.dart';
import 'config/theme_config.dart';
import 'providers/theme_provider.dart';
import 'services/local_storage_service.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializar configuración de entornos (Local vs Producción)
  await EnvironmentConfig.initialize();

  // 2. Inicializar base de datos local Hive CE para Local-First
  await LocalStorageService.initialize();

  // 3. Inicializar conexión Supabase con fallback seguro
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    debugPrint('Aviso: No se pudo conectar a Supabase al arrancar: $e');
  }

  // 4. Inicializar localización en español
  await initializeDateFormatting('es_ES', null);

  runApp(const ProviderScope(child: ArriendosApp()));
}

class ArriendosApp extends ConsumerWidget {
  const ArriendosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Arriendos Premium',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES')],
      locale: const Locale('es', 'ES'),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const AuthGate(),
    );
  }
}
