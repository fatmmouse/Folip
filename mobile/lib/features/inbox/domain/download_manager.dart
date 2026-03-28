import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

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

/// Manages all active and recently completed downloads using Dio.
class DownloadManager extends Notifier<Map<String, DownloadState>> {
  final Dio _downloadDio = Dio();

  @override
  Map<String, DownloadState> build() {
    return {};
  }

  /// Starts a download for the given transfer using Dio.
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

    try {
      // Save to public Downloads on Android, Documents on iOS
      Directory dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getApplicationDocumentsDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      final savePath = '${dir.path}/${transfer.fileName}';

      await _downloadDio.download(
        transfer.downloadUrl!,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            state = {
              ...state,
              transfer.transferId: DownloadState(
                transferId: transfer.transferId,
                progress: progress,
                status: DownloadStatus.downloading,
              ),
            };
          }
        },
      );

      // Best-effort: mark as downloaded on backend
      try {
        await ref
            .read(inboxRepositoryProvider)
            .markDownloaded(transfer.transferId);
      } catch (_) {}

      state = {
        ...state,
        transfer.transferId: DownloadState(
          transferId: transfer.transferId,
          progress: 1.0,
          status: DownloadStatus.complete,
        ),
      };

      // Auto-clear completed download after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        clearCompleted(transfer.transferId);
      });
    } catch (_) {
      state = {
        ...state,
        transfer.transferId: DownloadState(
          transferId: transfer.transferId,
          progress: 0,
          status: DownloadStatus.failed,
        ),
      };
    }
  }

  /// Retries a failed download.
  Future<void> retryDownload(Transfer transfer) async {
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
