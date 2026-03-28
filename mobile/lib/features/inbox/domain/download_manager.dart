import 'dart:io' show Platform;

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/transfer.dart';
import '../data/inbox_repository.dart';

/// Status of a single file download.
enum DownloadStatus { downloading, complete, failed }

/// Immutable state for a single in-progress or completed download.
class DownloadState {
  final String transferId;
  final double progress; // 0.0 to 1.0
  final DownloadStatus status;

  const DownloadState({
    required this.transferId,
    required this.progress,
    required this.status,
  });

  DownloadState copyWith({
    double? progress,
    DownloadStatus? status,
  }) {
    return DownloadState(
      transferId: transferId,
      progress: progress ?? this.progress,
      status: status ?? this.status,
    );
  }
}

/// Manages all active and recently completed downloads.
///
/// State: Map<transferId, DownloadState> for all active/recent downloads.
/// Uses background_downloader (FileDownloader) for foreground downloads
/// with allowPause: true to handle large files (up to 500MB, Android 9-min
/// timeout avoidance — RESEARCH.md Pitfall 6).
class DownloadManager extends Notifier<Map<String, DownloadState>> {
  @override
  Map<String, DownloadState> build() {
    return {};
  }

  /// Starts a download for the given transfer.
  ///
  /// Uses presigned GET URL from transfer.downloadUrl.
  /// On Android: saves to applicationDocuments.
  /// On iOS: saves to applicationDocuments (accessible via Files app, D-07).
  Future<void> startDownload(Transfer transfer) async {
    if (transfer.downloadUrl == null) {
      state = {
        ...state,
        transfer.transferId: DownloadState(
          transferId: transfer.transferId,
          progress: 0,
          status: DownloadStatus.failed,
        ),
      };
      return;
    }

    // Set initial downloading state
    state = {
      ...state,
      transfer.transferId: DownloadState(
        transferId: transfer.transferId,
        progress: 0,
        status: DownloadStatus.downloading,
      ),
    };

    // Use applicationDocuments on both platforms.
    // On iOS this is accessible via the Files app (D-07).
    // Platform.isIOS check kept for future platform-specific directory logic.
    final baseDirectory = Platform.isIOS
        ? BaseDirectory.applicationDocuments
        : BaseDirectory.applicationDocuments;

    final task = DownloadTask(
      url: transfer.downloadUrl!,
      filename: transfer.fileName,
      baseDirectory: baseDirectory,
      updates: Updates.statusAndProgress,
      allowPause: true, // Required for 500MB files: prevents Android 9-min timeout (Pitfall 6)
    );

    await FileDownloader().download(
      task,
      onProgress: (progress) {
        state = {
          ...state,
          transfer.transferId: DownloadState(
            transferId: transfer.transferId,
            progress: progress,
            status: DownloadStatus.downloading,
          ),
        };
      },
      onStatus: (status) async {
        if (status == TaskStatus.complete) {
          // Best-effort: mark as downloaded on backend
          try {
            await ref
                .read(inboxRepositoryProvider)
                .markDownloaded(transfer.transferId);
          } catch (_) {
            // Ignore backend errors — file is already saved locally
          }
          state = {
            ...state,
            transfer.transferId: DownloadState(
              transferId: transfer.transferId,
              progress: 1.0,
              status: DownloadStatus.complete,
            ),
          };
        } else if (status == TaskStatus.failed ||
            status == TaskStatus.notFound) {
          state = {
            ...state,
            transfer.transferId: DownloadState(
              transferId: transfer.transferId,
              progress: 0,
              status: DownloadStatus.failed,
            ),
          };
        }
      },
    );
  }

  /// Retries a failed download.
  Future<void> retryDownload(Transfer transfer) async {
    // Remove the failed state then restart
    final newState = Map<String, DownloadState>.from(state);
    newState.remove(transfer.transferId);
    state = newState;
    await startDownload(transfer);
  }

  /// Removes a completed download from tracking state.
  void clearCompleted(String transferId) {
    final newState = Map<String, DownloadState>.from(state);
    newState.remove(transferId);
    state = newState;
  }
}

/// Provider for DownloadManager.
final downloadManagerProvider =
    NotifierProvider<DownloadManager, Map<String, DownloadState>>(
  DownloadManager.new,
);
