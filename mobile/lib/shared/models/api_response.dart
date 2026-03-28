/// Generic API response wrapper matching the backend ApiResponse type.
///
/// Backend shape:
///   Success: `{ "data": T, "ok": true }`
///   Error:   `{ "error": string, "code": string, "ok": false }`
class ApiResponse<T> {
  final T? data;
  final String? error;
  final String? code;
  final bool ok;

  const ApiResponse({
    this.data,
    this.error,
    this.code,
    required this.ok,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final ok = json['ok'] as bool;
    if (ok) {
      final rawData = json['data'];
      T? data;
      if (rawData != null && rawData is Map<String, dynamic>) {
        data = fromJsonT(rawData);
      }
      return ApiResponse<T>(ok: true, data: data);
    } else {
      return ApiResponse<T>(
        ok: false,
        error: json['error'] as String?,
        code: json['code'] as String?,
      );
    }
  }

  factory ApiResponse.success(T data) {
    return ApiResponse<T>(ok: true, data: data);
  }

  factory ApiResponse.error(String error, {String? code}) {
    return ApiResponse<T>(ok: false, error: error, code: code);
  }

  bool get isSuccess => ok && data != null;

  @override
  String toString() => 'ApiResponse(ok: $ok, data: $data, error: $error)';
}
