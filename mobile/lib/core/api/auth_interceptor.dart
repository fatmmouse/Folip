import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';
import 'api_constants.dart';

/// Dio interceptor that:
///   1. Injects `Authorization: Bearer {access_token}` on every request
///      (except login, register, and refresh endpoints)
///   2. On 401 response, refreshes the token via POST /auth/refresh
///      - Success: saves new tokens, retries the original request
///      - Failure: clears all tokens (forces re-login)
///
/// Handles concurrent 401s using a Completer lock to prevent multiple
/// simultaneous refresh requests.
class AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;
  final Dio _dio;

  /// Lock to prevent concurrent refresh attempts.
  Completer<bool>? _refreshCompleter;

  AuthInterceptor({
    required SecureStorageService storage,
    required Dio dio,
  })  : _storage = storage,
        _dio = dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header for public endpoints (login, register, refresh)
    final path = options.path;
    final isPublic = ApiConstants.publicPaths.any((p) => path.endsWith(p));

    if (!isPublic) {
      final accessToken = await _storage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only attempt refresh on 401 Unauthorized
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Don't attempt refresh for the refresh endpoint itself (avoid infinite loop)
    final path = err.requestOptions.path;
    if (path.endsWith(ApiConstants.refresh)) {
      await _storage.clearAll();
      handler.next(err);
      return;
    }

    // If a refresh is already in progress, wait for it to complete
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      final refreshed = await _refreshCompleter!.future;
      if (refreshed) {
        // Retry with new token
        try {
          final response = await _retryRequest(err.requestOptions);
          handler.resolve(response);
        } catch (retryError) {
          handler.next(err);
        }
      } else {
        handler.next(err);
      }
      return;
    }

    // Start a new refresh
    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _storage.clearAll();
        _refreshCompleter!.complete(false);
        handler.next(err);
        return;
      }

      // Call refresh endpoint directly (bypass interceptor to avoid loop)
      final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final response = await refreshDio.post(
        ApiConstants.refresh,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data['ok'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        final newAccessToken = data['accessToken'] as String;
        final newRefreshToken = data['refreshToken'] as String;

        await _storage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );

        _refreshCompleter!.complete(true);

        // Retry the original request with new token
        try {
          final retryResponse = await _retryRequest(err.requestOptions);
          handler.resolve(retryResponse);
        } catch (retryError) {
          handler.next(err);
        }
      } else {
        await _storage.clearAll();
        _refreshCompleter!.complete(false);
        handler.next(err);
      }
    } catch (e) {
      await _storage.clearAll();
      _refreshCompleter!.complete(false);
      handler.next(err);
    } finally {
      // Reset the completer after a short delay to allow waiters to complete
      Future.delayed(const Duration(milliseconds: 100), () {
        _refreshCompleter = null;
      });
    }
  }

  /// Retries the original request after a successful token refresh.
  Future<Response<dynamic>> _retryRequest(RequestOptions options) async {
    final newAccessToken = await _storage.getAccessToken();
    final retryOptions = options.copyWith(
      headers: {
        ...options.headers,
        'Authorization': 'Bearer $newAccessToken',
      },
    );
    return _dio.fetch(retryOptions);
  }
}
