/// Base class for all application exceptions.
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Authentication related errors (login, OTP, session expiration)
class AppAuthException extends AppException {
  const AppAuthException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Database / PostgREST / RLS permission errors
class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Entity or resource not found error
class NotFoundException extends AppException {
  const NotFoundException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Network connectivity failure or timeout
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Missing Supabase / API configuration error
class ConfigurationException extends AppException {
  const ConfigurationException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Input validation error
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Authorization or permission denied error
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    required super.message,
    super.code,
    super.originalError,
  });
}

