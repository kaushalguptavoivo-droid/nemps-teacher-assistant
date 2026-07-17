class AppConfig {
  AppConfig._();
  // Pass values using --dart-define; do not commit credentials.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
