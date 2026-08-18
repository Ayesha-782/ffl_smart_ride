/// Supabase configuration holding project URL and anon/publishable key.
/// Values can be injected via compile-time environment variables:
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yjgdmrgjamlmnzwgeptq.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_r2CSYF6vG3a56NYoq5euLw_AvkhwW0f',
  );
}
