import 'environment_config.dart';

class SupabaseConfig {
  static String get url => EnvironmentConfig.currentUrl;
  static String get anonKey => EnvironmentConfig.currentAnonKey;
}
