import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys for secure storage entries.
class _StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String deviceId = 'device_id';
  static const String userId = 'user_id';
  static const String lastTargetDevice = 'last_device_target';
}

/// Wrapper around FlutterSecureStorage providing typed access to all
/// app credentials and preferences.
///
/// Stores:
///   - JWT access and refresh tokens (Android Keystore / iOS Keychain)
///   - Device ID and User ID for API calls
///   - Last-used target device ID (D-02: pre-select last used device on Send screen)
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          // Use default Android options — flutter_secure_storage v10 automatically
          // uses RSA_ECB_OAEPwithSHA_256andMGF1Padding (Jetpack Crypto is deprecated).
          aOptions: AndroidOptions.defaultOptions,
        );

  // ---------------------------------------------------------------------------
  // Auth tokens
  // ---------------------------------------------------------------------------

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _StorageKeys.accessToken, value: accessToken),
      _storage.write(key: _StorageKeys.refreshToken, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: _StorageKeys.accessToken);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: _StorageKeys.refreshToken);
  }

  // ---------------------------------------------------------------------------
  // Device / user info
  // ---------------------------------------------------------------------------

  Future<void> saveDeviceInfo({
    required String deviceId,
    required String userId,
  }) async {
    await Future.wait([
      _storage.write(key: _StorageKeys.deviceId, value: deviceId),
      _storage.write(key: _StorageKeys.userId, value: userId),
    ]);
  }

  Future<String?> getDeviceId() async {
    return _storage.read(key: _StorageKeys.deviceId);
  }

  Future<String?> getUserId() async {
    return _storage.read(key: _StorageKeys.userId);
  }

  // ---------------------------------------------------------------------------
  // Last-used target device (D-02: pre-select on Send screen)
  // ---------------------------------------------------------------------------

  Future<void> saveLastTargetDevice(String deviceId) async {
    await _storage.write(key: _StorageKeys.lastTargetDevice, value: deviceId);
  }

  Future<String?> getLastTargetDevice() async {
    return _storage.read(key: _StorageKeys.lastTargetDevice);
  }

  // ---------------------------------------------------------------------------
  // Auth state check
  // ---------------------------------------------------------------------------

  /// Returns true if the user is likely authenticated (has an access token).
  /// Does not verify token validity — use the API interceptor for that.
  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Clear all (logout)
  // ---------------------------------------------------------------------------

  Future<void> clearAll() async {
    // Keep device_id so the next login reuses the same device identity
    await Future.wait([
      _storage.delete(key: _StorageKeys.accessToken),
      _storage.delete(key: _StorageKeys.refreshToken),
      _storage.delete(key: _StorageKeys.userId),
      _storage.delete(key: _StorageKeys.lastTargetDevice),
    ]);
  }
}

/// Riverpod provider for SecureStorageService.
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
