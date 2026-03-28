import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage.dart';

/// Result returned by AuthRepository auth operations.
class AuthResult {
  final bool success;
  final String? error;

  const AuthResult({required this.success, this.error});
}

/// Repository that wraps ApiClient auth calls with token persistence logic.
///
/// Responsibilities:
///   - Call ApiClient for register/login/logout/refresh
///   - Persist tokens and device info to SecureStorageService on success
///   - Clear storage on logout
///   - Provide checkAuth() for initial authentication check
class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;

  AuthRepository({
    required ApiClient apiClient,
    required SecureStorageService secureStorage,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage;

  /// Registers a new account and persists tokens on success.
  Future<AuthResult> register(
      String email, String password, String deviceName) async {
    final response = await _apiClient.register(
      email: email,
      password: password,
      deviceName: deviceName,
    );

    if (response.ok && response.data != null) {
      final data = response.data!;
      await _secureStorage.saveTokens(
        accessToken: data.accessToken,
        refreshToken: data.refreshToken,
      );
      await _secureStorage.saveDeviceInfo(
        deviceId: data.deviceId,
        userId: data.userId,
      );
      return const AuthResult(success: true);
    }

    return AuthResult(
      success: false,
      error: response.error ?? 'Registration failed',
    );
  }

  /// Authenticates with email/password and persists tokens on success.
  /// Sends existing device_id if available so server reuses it.
  Future<AuthResult> login(
      String email, String password, String deviceName) async {
    // Retrieve stored device_id to reuse on re-login
    final existingDeviceId = await _secureStorage.getDeviceId();

    final response = await _apiClient.login(
      email: email,
      password: password,
      deviceName: deviceName,
      deviceId: existingDeviceId,
    );

    if (response.ok && response.data != null) {
      final data = response.data!;
      await _secureStorage.saveTokens(
        accessToken: data.accessToken,
        refreshToken: data.refreshToken,
      );
      await _secureStorage.saveDeviceInfo(
        deviceId: data.deviceId,
        userId: data.userId,
      );
      return const AuthResult(success: true);
    }

    return AuthResult(
      success: false,
      error: response.error ?? 'Login failed',
    );
  }

  /// Logs out: calls API (ignores errors) then clears all local storage.
  Future<void> logout() async {
    try {
      await _apiClient.logout();
    } catch (_) {
      // Logout should always clear local state regardless of API errors
    }
    await _secureStorage.clearAll();
  }

  /// Checks if the user has a stored access token (does not validate it).
  Future<bool> checkAuth() async {
    return _secureStorage.isAuthenticated();
  }
}

/// Riverpod provider for AuthRepository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.read(apiClientProvider),
    secureStorage: ref.read(secureStorageProvider),
  );
});
