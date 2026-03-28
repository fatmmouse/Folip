import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service that handles direct-to-OSS file uploads via presigned PUT URLs.
///
/// KEY DESIGN POINTS (per plan spec):
///
/// 1. Separate Dio instance — NO auth interceptor. The presigned URL is
///    self-authenticating. Adding a Bearer token header causes OSS to reject
///    the request with a signature mismatch error.
///
/// 2. Content-Type: application/octet-stream — must match what the backend
///    used when generating the presigned URL signature.
///
/// 3. Android foreground service (D-03) — wraps the upload so the OS cannot
///    kill it when the app is backgrounded. Shows a notification with progress.
///
/// 4. iOS limitation — iOS background URLSession for PUT uploads requires
///    native platform channel work. For v1, uploads work in foreground and
///    survive brief backgrounding (~30 seconds). Full background URLSession
///    upload is a known v1 limitation (see SUMMARY Known Stubs).
class UploadService {
  /// Separate Dio instance for OSS uploads — no auth interceptor.
  final Dio _uploadDio = Dio();

  /// Uploads a file to OSS via a presigned PUT URL.
  ///
  /// Wraps with Android foreground service (D-03) to survive backgrounding.
  /// Always stops the foreground service in a finally block (success or error).
  Future<void> uploadToPresignedUrl({
    required String presignedUrl,
    required String filePath,
    required int fileSize,
    required String fileName,
    required void Function(int sent, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    // Start Android foreground service (D-03) — prevents OS kill during upload
    if (Platform.isAndroid) {
      await FlutterForegroundTask.startService(
        serviceId: 1001,
        notificationTitle: 'Uploading file',
        notificationText: 'Preparing $fileName...',
      );
    }

    try {
      final file = File(filePath);
      final stream = file.openRead();

      await _uploadDio.put(
        presignedUrl,
        data: stream,
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': fileSize,
          },
          // Disable Dio's default content-type header injection
          contentType: 'application/octet-stream',
        ),
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          onProgress(sent, total);

          // Update foreground service notification with upload progress
          if (Platform.isAndroid) {
            final percent = total > 0 ? (sent / total * 100).toInt() : 0;
            FlutterForegroundTask.updateService(
              notificationText: '$percent% uploaded — $fileName',
            );
          }
        },
      );
    } finally {
      // Always stop foreground service — even on error or cancellation
      if (Platform.isAndroid) {
        await FlutterForegroundTask.stopService();
      }
    }
  }
}

/// Riverpod provider for UploadService.
final uploadServiceProvider = Provider<UploadService>((ref) => UploadService());
