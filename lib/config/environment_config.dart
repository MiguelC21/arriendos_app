import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppEnvironment { local, production }

class EnvironmentConfig {
  static const String _prefKey = 'selected_app_environment';

  // Configuración de Producción
  static const String prodUrl = 'https://npjpxjrrdxnplpxatxpb.supabase.co';
  static const String prodAnonKey =
      'sb_publishable_ty0m3nCqxpqx9hSiLTMNQg_l_2QCcwy';

  // Configuración de Supabase Local (Docker / CLI)
  // En Android Emulator 10.0.2.2 mapea a 127.0.0.1 del host.
  // En Web o Windows Desktop se usa 127.0.0.1 directamente.
  static String get localUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:54321';
    }
    return 'http://127.0.0.1:54321';
  }

  // Clave anon estándar de la instancia local de Supabase
  static const String localAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  // Entorno actual en memoria
  static AppEnvironment _currentEnvironment = AppEnvironment.production;

  static AppEnvironment get current => _currentEnvironment;

  static bool get isLocal => _currentEnvironment == AppEnvironment.local;
  static bool get isProduction =>
      _currentEnvironment == AppEnvironment.production;

  static String get currentUrl => isLocal ? localUrl : prodUrl;
  static String get currentAnonKey => isLocal ? localAnonKey : prodAnonKey;

  /// Inicializa el entorno leyendo SharedPreferences o variables de compilación (--dart-define=ENV=local)
  static Future<void> initialize() async {
    const definedEnv = String.fromEnvironment('ENV', defaultValue: '');

    if (definedEnv.toLowerCase() == 'local') {
      _currentEnvironment = AppEnvironment.local;
      return;
    } else if (definedEnv.toLowerCase() == 'prod' ||
        definedEnv.toLowerCase() == 'production') {
      _currentEnvironment = AppEnvironment.production;
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEnv = prefs.getString(_prefKey);
      if (savedEnv == 'local') {
        _currentEnvironment = AppEnvironment.local;
      } else {
        _currentEnvironment = AppEnvironment.production;
      }
    } catch (e) {
      debugPrint('Error al cargar entorno de SharedPreferences: $e');
      _currentEnvironment = AppEnvironment.production;
    }
  }

  /// Cambia el entorno y lo persiste para futuros reinicios
  static Future<void> setEnvironment(AppEnvironment env) async {
    _currentEnvironment = env;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        env == AppEnvironment.local ? 'local' : 'production',
      );
    } catch (e) {
      debugPrint('Error al guardar entorno en SharedPreferences: $e');
    }
  }
}
