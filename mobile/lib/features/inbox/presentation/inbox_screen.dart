import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../domain/download_manager.dart';
import '../domain/inbox_notifier.dart';
import 'envelope_stack_widget.dart';
import 'mini_download_widget.dart';

/// Inbox home screen — shows pending files as envelope stack.
///
/// Per UI-SPEC Inbox Screen:
/// - AppBar: opened-mail icon (left) → history, title "Folip", gear icon (right) → settings
/// - Pull-to-refresh via RefreshIndicator
/// - AsyncLoading: centered spinner
/// - AsyncError: centered error + Retry button
/// - Empty pending: empty state ("No files waiting")
/// - Pending files: EnvelopeStackWidget + right-edge MiniDownloadWidget
///
/// RECV-05: auto-refresh on AppLifecycleState.resumed via WidgetsBindingObserver.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// RECV-05: auto-refresh inbox when app comes back to foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(inboxNotifierProvider.notifier).refresh();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(inboxNotifierProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final inboxAsync = ref.watch(inboxNotifierProvider);
    final downloads = ref.watch(downloadManagerProvider);

    return Scaffold(
      backgroundColor: AppColors.dominant,
      appBar: AppBar(
        backgroundColor: AppColors.dominant,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.mark_email_read,
            size: 24,
            color: AppColors.textSecondary,
          ),
          onPressed: () => context.push('/inbox/history'),
          tooltip: 'Download history',
        ),
        title: const Text('Folip'),
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.settings,
              size: 24,
              color: AppColors.textPrimary,
            ),
            onPressed: () => context.push('/inbox/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _onRefresh,
        child: _buildBody(context, inboxAsync, downloads),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue inboxAsync,
    Map<String, DownloadState> downloads,
  ) {
    return inboxAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (error, _) => _buildErrorState(context),
      data: (transfers) {
        final pendingTransfers =
            transfers.where((t) => t.status == 'pending').toList();

        if (pendingTransfers.isEmpty && downloads.isEmpty) {
          return _buildEmptyState(context);
        }

        return _buildInboxContent(context, pendingTransfers, downloads);
      },
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Couldn\'t load inbox. Check your connection and try again.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.destructive,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  ref.read(inboxNotifierProvider.notifier).refresh(),
              child: Text(
                'Retry',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.accent,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'No files waiting',
                style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Files sent to this device will appear here.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInboxContent(
    BuildContext context,
    List pendingTransfers,
    Map<String, DownloadState> downloads,
  ) {
    return Stack(
      children: [
        // Make full area scrollable for pull-to-refresh to work
        SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: EnvelopeStackWidget(
                pendingTransfers: List.from(pendingTransfers),
              ),
            ),
          ),
        ),

        // Right-edge mini download progress icons
        Positioned(
          right: 8,
          top: 0,
          bottom: 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              MiniDownloadWidget(),
            ],
          ),
        ),
      ],
    );
  }
}
