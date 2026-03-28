/// API endpoint constants matching the backend route definitions.
///
/// Base URL is configurable via --dart-define=API_BASE_URL=https://your-api.com
/// Defaults to localhost:3000 for development.
class ApiConstants {
  // Base URL — override at build time with --dart-define=API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  // ---------------------------------------------------------------------------
  // Auth endpoints
  // ---------------------------------------------------------------------------
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  // ---------------------------------------------------------------------------
  // Device endpoints
  // ---------------------------------------------------------------------------
  static const String devicesList = '/devices';
  static const String devicesRegister = '/devices';
  static String deviceRemove(String id) => '/devices/$id';

  // ---------------------------------------------------------------------------
  // Transfer endpoints
  // ---------------------------------------------------------------------------
  static const String transferPrepare = '/transfers/prepare';
  static String transferConfirm(String id) => '/transfers/$id/confirm';
  static const String transferInbox = '/transfers/inbox';
  static String transferDownloaded(String id) => '/transfers/$id/downloaded';

  // ---------------------------------------------------------------------------
  // Unauthenticated endpoints (skip Bearer injection in AuthInterceptor)
  // ---------------------------------------------------------------------------
  static const List<String> publicPaths = [
    register,
    login,
    refresh,
  ];
}
