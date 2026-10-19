/// API & Third-party integration configurations and placeholders.
///
/// Keys should be provided via dart-define environment flags at build/run time:
/// --dart-define=GOOGLE_MAPS_API_KEY=...
/// --dart-define=AGORA_APP_ID=...
/// --dart-define=FCM_SERVER_KEY=...
class ApiConfig {
  /// Base API timeout duration in seconds
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Google Maps API Configuration
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );
  static bool get isGoogleMapsConfigured => googleMapsApiKey.isNotEmpty;

  /// Agora Voice Calling Configuration Placeholder
  static const String agoraAppId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: '',
  );
  static bool get isAgoraConfigured => agoraAppId.isNotEmpty;

  /// Firebase Cloud Messaging Configuration Placeholder
  static const String fcmSenderId = String.fromEnvironment(
    'FCM_SENDER_ID',
    defaultValue: '',
  );
  static bool get isFcmConfigured => fcmSenderId.isNotEmpty;

  /// Razorpay Configuration Placeholder (Public Key ID only - never secret key in client)
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: '',
  );
  static bool get isRazorpayConfigured => razorpayKeyId.isNotEmpty;
}
