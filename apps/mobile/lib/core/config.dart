/// Configuration injectée à la compilation, jamais écrite dans le code :
/// flutter run --dart-define-from-file=env/dev.json
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const termsVersion = String.fromEnvironment('TERMS_VERSION', defaultValue: '2026-11');
  static const defaultCountryCode = '+224';

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
