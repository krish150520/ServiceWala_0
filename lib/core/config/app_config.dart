/// General Application Configuration & Environment Settings
class AppConfig {
  static const String appName = 'ServiceWala Partner';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';

  /// Environment mode (development, staging, production)
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static bool get isProduction => environment.toLowerCase() == 'production';
  static bool get isDevelopment => environment.toLowerCase() == 'development';
}
