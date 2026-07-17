class AppConfig {
  AppConfig._();
  // This is the school's public client configuration. RLS—not key secrecy—protects data.
  // A Vercel environment variable can override either value for another environment.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://fdvfmoxcbkdisgnhplaa.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_2G6kz4aS1GPHOJU0MeNtrg_j2psSWoS',
  );
}
