import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage.dart';
import '../data/transfer_repository.dart';
import '../data/upload_service.dart';

// ---------------------------------------------------------------------------
// Send state
// ---------------------------------------------------------------------------

/// Represents the current state of the send flow.
enum SendStatus { idle, uploading, success, error }

/// Immutable state for the SendNotifier.
class SendState {
  final SendStatus status;
  final double progress; // 0.0 to 1.0
  final String? fileName;
  final String? error;

  const SendState({
    required this.status,
    required this.progress,
    this.fileName,
    this.error,
  });

  SendState copyWith({
    SendStatus? status,
    double? progress,
    String? fileName,
    String? error,
  }) {
    return SendState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      fileName: fileName ?? this.fileName,
      error: error ?? this.error,
    );
  }
}

// ---------------------------------------------------------------------------
// Send notifier
// ---------------------------------------------------------------------------

/// Notifier that manages the complete send flow lifecycle:
///   idle → uploading (prepare + PUT upload + confirm) → success → idle
///   idle → uploading → error (with retry support via reset())
///
/// Flow per plan spec (D-02, D-03):
///   1. prepareTransfer(targetDeviceId, fileName, fileSize) → presigned URL
///   2. uploadToPresignedUrl(presignedUrl, ...) with Android foreground service
///   3. confirmTransfer(transferId, targetDeviceId) → backend marks pending
///   4. saveLastTargetDevice(targetDeviceId) → D-02 pre-selection on next open
///   5. Success state shown for 2 seconds, then resets to idle
class SendNotifier extends Notifier<SendState> {
  @override
  SendState build() => const SendState(status: SendStatus.idle, progress: 0);

  TransferRepository get _transferRepo =>
      ref.read(transferRepositoryProvider);
  UploadService get _uploadService => ref.read(uploadServiceProvider);
  SecureStorageService get _storage => ref.read(secureStorageProvider);

  /// Executes the full send flow for a single file.
  ///
  /// Assumes file size validation (500MB check) has already been done by caller.
  Future<void> sendFile({
    required String targetDeviceId,
    required String filePath,
    required String fileName,
    required int fileSize,
  }) async {
    state = SendState(
      status: SendStatus.uploading,
      progress: 0,
      fileName: fileName,
    );

    try {
      // Step 1: Prepare transfer — get presigned PUT URL from backend
      final prepared = await _transferRepo.prepareTransfer(
        targetDeviceId,
        fileName,
        fileSize,
      );

      // Step 2: Upload file directly to OSS via presigned PUT URL
      // Wrapped with Android foreground service per D-03
      await _uploadService.uploadToPresignedUrl(
        presignedUrl: prepared.uploadUrl,
        filePath: filePath,
        fileSize: fileSize,
        fileName: fileName,
        onProgress: (sent, total) {
          state = state.copyWith(
            progress: total > 0 ? sent / total : 0,
          );
        },
      );

      // Step 3: Confirm transfer — tells backend upload is complete
      await _transferRepo.confirmTransfer(
        prepared.transferId,
        targetDeviceId,
      );

      // Step 4: Remember last-used device for D-02 pre-selection
      await _storage.saveLastTargetDevice(targetDeviceId);

      // Step 5: Show success state
      state = SendState(
        status: SendStatus.success,
        progress: 1.0,
        fileName: fileName,
      );

      // Auto-reset to idle after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      if (state.status == SendStatus.success) {
        state = const SendState(status: SendStatus.idle, progress: 0);
      }
    } catch (e) {
      String errorMsg = 'Upload failed. Check your connection.';

      if (e is DioException && e.response?.data is Map) {
        final data = e.response?.data as Map;
        errorMsg = (data['error'] as String?) ?? errorMsg;
      } else if (e is Exception) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        if (msg.isNotEmpty) errorMsg = msg;
      }

      state = SendState(
        status: SendStatus.error,
        progress: 0,
        error: errorMsg,
        fileName: fileName,
      );
    }
  }

  /// Resets back to idle state (used by Retry button and after file picker close).
  void reset() {
    state = const SendState(status: SendStatus.idle, progress: 0);
  }
}

/// NotifierProvider for send state management.
final sendNotifierProvider = NotifierProvider<SendNotifier, SendState>(
  SendNotifier.new,
);
