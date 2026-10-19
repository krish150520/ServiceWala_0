/// Supabase Configuration for ServiceWala Agent App.
///
/// Uses environment-based configuration values (SUPABASE_URL, SUPABASE_ANON_KEY).
/// Never expose or store the service-role key in the client application.
class SupabaseConfig {
  /// Supabase project URL (e.g. 'https://your-project.supabase.co')
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ubcckqrrvjhidotoewgl.supabase.co',
  );

  /// Supabase public anonymous key (safe for client use)
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InViY2NrcXJydmpoaWRvdG9ld2dsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgzNjUwNjgsImV4cCI6MjEwMzk0MTA2OH0.pgYLmBvY7iaQVoW6wvonERuYvAeRi1Jb-IBdJC1o_XQ',
  );


  /// Returns true if both URL and anonKey are non-empty
  static bool get isConfigured =>
      url.trim().isNotEmpty && anonKey.trim().isNotEmpty;
}
