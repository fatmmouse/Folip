import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/models/transfer.dart';
import '../domain/download_manager.dart';
import '../domain/inbox_notifier.dart';

/// Download history screen — shows all previously downloaded files.
///
/// Accessed via the opened-mail icon in the Inbox AppBar.
/// Per UI-SPEC: AppBar with back + "History" title, compact list rows,
/// re-download button on each row.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(inboxNotifierProvider);
    final downloads = ref.watch(downloadManagerProvider);

    return Scaffold(
      appBar: AppBar(
        // back button is provided automatically by GoRouter
        title: const Text('History'),
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle,
        backgroundColor: AppColors.dominant,
        elevation: 0,
      ),
      backgroundColor: AppColors.dominant,
      body: inboxAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (error, _) => Center(
          child: Text(
            'Couldn\'t load history.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.destructive),
          ),
        ),
        data: (transfers) {
          final downloaded =
              transfers.where((t) => t.status == 'downloaded').toList();

          if (downloaded.isEmpty) {
            return Center(
              child: Text(
                'No downloaded files yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            );
          }

          return ListView.separated(
            itemCount: downloaded.length,
            separatorBuilder: (context, index) => const Divider(
              color: AppColors.secondary,
              height: 1,
              thickness: 1,
            ),
            itemBuilder: (context, index) {
              final transfer = downloaded[index];
              return _HistoryRow(
                transfer: transfer,
                isDownloading: downloads.containsKey(transfer.transferId),
                onRedownload: () => _redownload(ref, transfer),
              );
            },
          );
        },
      ),
    );
  }

  void _redownload(WidgetRef ref, Transfer transfer) {
    // Refresh inbox first to get fresh presigned URL, then trigger download.
    // The notifier refresh updates download_url on the transfer objects.
    ref.read(inboxNotifierProvider.notifier).refresh().then((_) {
      // Get the refreshed transfer with fresh download_url
      final inboxState = ref.read(inboxNotifierProvider);
      final refreshedTransfer = inboxState.value?.firstWhere(
        (t) => t.transferId == transfer.transferId,
        orElse: () => transfer,
      );
      if (refreshedTransfer != null) {
        ref
            .read(downloadManagerProvider.notifier)
            .startDownload(refreshedTransfer);
      }
    });
  }
}

/// A single row in the history list.
class _HistoryRow extends StatelessWidget {
  final Transfer transfer;
  final bool isDownloading;
  final VoidCallback onRedownload;

  const _HistoryRow({
    required this.transfer,
    required this.isDownloading,
    required this.onRedownload,
  });

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Leading: opened envelope icon
            const Icon(
              Icons.drafts,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 12),

            // File info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transfer.fileName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatFileSize(transfer.fileSize),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),

            // Re-download button
            isDownloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.download),
                    iconSize: 24,
                    color: AppColors.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: onRedownload,
                  ),
          ],
        ),
      ),
    );
  }
}
