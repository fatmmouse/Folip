import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_response.dart';
import '../../shared/models/device.dart';
import '../../shared/models/transfer.dart';
import '../storage/secure_storage.dart';
import 'api_constants.dart';
import 'auth_interceptor.dart';

/// Data class for login/register response data.
class AuthResponseData {
  final String userId;
  final String email;
  final String deviceId;
  final String deviceName;
  final String accessToken;
  final String refreshToken;

  const AuthResponseData({
    required this.userId,
    required this.email,
    required this.deviceId,
    required this.deviceName,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponseData.fromJson(Map<String, dynamic> json) {
    return AuthResponseData(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      deviceId: json['device_id'] as String,
      deviceName: json['device_name'] as String,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }
}

/// Data class for the transfer prepare response.
class PrepareTransferData {
  final String transferId;
  final String uploadUrl;
  final String ossKey;
  final int expiresIn;

  const PrepareTransferData({
    required this.transferId,
    required this.uploadUrl,
    required this.ossKey,
    required this.expiresIn,
  });

  factory PrepareTransferData.fromJson(Map<String, dynamic> json) {
    return PrepareTransferData(
      transferId: json['transfer_id'] as String,
      uploadUrl: json['upload_url'] as String,
      ossKey: json['oss_key'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }
}

/// Data class for inbox response — wraps a list of transfers.
class InboxData {
  final List<Transfer> transfers;

  const InboxData({required this.transfers});

  factory InboxData.fromJson(Map<String, dynamic> json) {
    final transfersList = json['transfers'] as List<dynamic>? ?? [];
    return InboxData(
      transfers: transfersList
          .map((t) => Transfer.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Dio-based HTTP client for the Folip backend API.
///
/// Covers all 10 backend endpoints from the Phase 1 API:
///   Auth: register, login, refreshTokens, logout
///   Devices: listDevices, removeDevice
///   Transfers: prepareTransfer, confirmTransfer, getInbox, markDownloaded
///
/// Auth interceptor is attached automatically — Bearer token injection
/// and 401 refresh are transparent to callers.
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  // ---------------------------------------------------------------------------
  // Auth endpoints
  // ---------------------------------------------------------------------------

  /// POST /auth/register — creates a new account and returns auth tokens + device info.
  Future<ApiResponse<AuthResponseData>> register({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.register,
        data: {
          'email': email,
          'password': password,
          'device_name': deviceName,
        },
      );
      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        AuthResponseData.fromJson,
      );
    } on DioException catch (e) {
      return _handleDioError<AuthResponseData>(e);
    }
  }

  /// POST /auth/login — authenticates and returns auth tokens + device info.
  Future<ApiResponse<AuthResponseData>> login({
    required String email,
    required String password,
    required String deviceName,
    String? deviceId,
  }) async {
    try {
      final body = <String, dynamic>{
        'email': email,
        'password': password,
        'device_name': deviceName,
      };
      if (deviceId != null && deviceId.isNotEmpty) {
        body['device_id'] = deviceId;
      }
      final response = await _dio.post(
        ApiConstants.login,
        data: body,
      );
      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        AuthResponseData.fromJson,
      );
    } on DioException catch (e) {
      return _handleDioError<AuthResponseData>(e);
    }
  }

  /// POST /auth/refresh — exchanges a refresh token for new tokens.
  /// NOTE: This endpoint bypasses auth header injection (handled by ApiConstants.publicPaths).
  Future<ApiResponse<AuthResponseData>> refreshTokens(
      String refreshToken) async {
    try {
      final response = await _dio.post(
        ApiConstants.refresh,
        data: {'refreshToken': refreshToken},
      );
      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        AuthResponseData.fromJson,
      );
    } on DioException catch (e) {
      return _handleDioError<AuthResponseData>(e);
    }
  }

  /// POST /auth/logout — revokes the current device's refresh token.
  Future<ApiResponse<Map<String, dynamic>>> logout() async {
    try {
      final response = await _dio.post(ApiConstants.logout);
      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => json,
      );
    } on DioException catch (e) {
      return _handleDioError<Map<String, dynamic>>(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Device endpoints
  // ---------------------------------------------------------------------------

  /// GET /devices — returns all devices registered to the current user.
  Future<ApiResponse<List<Device>>> listDevices() async {
    try {
      final response = await _dio.get(ApiConstants.devicesList);
      final json = response.data as Map<String, dynamic>;
      if (json['ok'] == true) {
        final data = json['data'] as Map<String, dynamic>;
        final devicesList = data['devices'] as List<dynamic>? ?? [];
        final devices = devicesList
            .map((d) => Device.fromJson(d as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(devices);
      } else {
        return ApiResponse.error(
          json['error'] as String? ?? 'Unknown error',
          code: json['code'] as String?,
        );
      }
    } on DioException catch (e) {
      return _handleDioError<List<Device>>(e);
    }
  }

  /// PUT /devices/:id — renames a device.
  Future<ApiResponse<Map<String, dynamic>>> renameDevice(
      String deviceId, String deviceName) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.devicesList}/$deviceId',
        data: {'device_name': deviceName},
      );
      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => json,
      );
    } on DioException catch (e) {
      return _handleDioError<Map<String, dynamic>>(e);
    }
  }

  /// DELETE /devices/:id — removes a device from the current user's account.
  Future<ApiResponse<Map<String, dynamic>>> removeDevice(
      String deviceId) async {
    try {
      final response =
          await _dio.delete(ApiConstants.deviceRemove(deviceId));
      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => json,
      );
    } on DioException catch (e) {
      return _handleDioError<Map<String, dynamic>>(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Transfer endpoints
  // ---------------------------------------------------------------------------

  /// POST /transfers/prepare — initiates a transfer and returns a presigned PUT URL.
  Future<ApiResponse<PrepareTransferData>> prepareTransfer({
    required String targetDeviceId,
    required String fileName,
    required int fileSize,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.transferPrepare,
        data: {
          'target_device_id': targetDeviceId,
          'file_name': fileName,
          'file_size': fileSize,
        },
      );
      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        PrepareTransferData.fromJson,
      );
    } on DioException catch (e) {
      return _handleDioError<PrepareTransferData>(e);
    }
  }

  /// POST /transfers/:id/confirm — marks an upload as complete (status: pending).
  Future<ApiResponse<Map<String, dynamic>>> confirmTransfer({
    required String transferId,
    required String targetDeviceId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.transferConfirm(transferId),
        data: {'target_device_id': targetDeviceId},
      );
      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => json,
      );
    } on DioException catch (e) {
      return _handleDioError<Map<String, dynamic>>(e);
    }
  }

  /// GET /transfers/inbox — returns pending and downloaded transfers for this device.
  Future<ApiResponse<InboxData>> getInbox() async {
    try {
      final response = await _dio.get(ApiConstants.transferInbox);
      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        InboxData.fromJson,
      );
    } on DioException catch (e) {
      return _handleDioError<InboxData>(e);
    }
  }

  /// POST /transfers/:id/downloaded — marks a transfer as downloaded.
  Future<ApiResponse<Map<String, dynamic>>> markDownloaded(
      String transferId) async {
    try {
      final response = await _dio.post(
        ApiConstants.transferDownloaded(transferId),
      );
      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => json,
      );
    } on DioException catch (e) {
      return _handleDioError<Map<String, dynamic>>(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Error handling
  // ---------------------------------------------------------------------------

  ApiResponse<T> _handleDioError<T>(DioException e) {
    if (e.response?.data is Map<String, dynamic>) {
      final json = e.response!.data as Map<String, dynamic>;
      return ApiResponse.error(
        json['error'] as String? ?? 'Request failed',
        code: json['code'] as String?,
      );
    }
    return ApiResponse.error(
      e.message ?? 'Network error',
      code: 'NETWORK_ERROR',
    );
  }
}

/// Riverpod provider for ApiClient.
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.read(secureStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(AuthInterceptor(storage: storage, dio: dio));

  return ApiClient(dio);
});
