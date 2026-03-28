import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/transfer.dart';
import '../data/inbox_repository.dart';

/// Manages the inbox state: a list of transfers (pending + downloaded).
///
/// Automatically fetches on build. Supports manual refresh.
/// Provides convenience accessors for pending and downloaded transfers.
class InboxNotifier extends Notifier<AsyncValue<List<Transfer>>> {
  @override
  AsyncValue<List<Transfer>> build() {
    // Kick off fetch after first build
    Future.microtask(() => _fetch());
    return const AsyncLoading();
  }

  Future<void> _fetch() async {
    try {
      final transfers = await ref.read(inboxRepositoryProvider).fetchInbox();
      state = AsyncData(transfers);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Refreshes the inbox from the backend.
  Future<void> refresh() async {
    state = const AsyncLoading();
    await _fetch();
  }

  /// Returns all pending transfers (awaiting download).
  List<Transfer> get pendingTransfers =>
      state.value?.where((t) => t.status == 'pending').toList() ?? [];

  /// Returns all downloaded transfers (already received).
  List<Transfer> get downloadedTransfers =>
      state.value?.where((t) => t.status == 'downloaded').toList() ?? [];

  /// Returns the count of pending transfers.
  int get pendingCount => pendingTransfers.length;

  /// Optimistically moves a transfer from pending to downloaded in local state.
  /// Call after a download completes to immediately update the UI.
  void markAsDownloaded(String transferId) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.map((t) {
        if (t.transferId == transferId) {
          return t.copyWith(
            status: 'downloaded',
            downloadedAt: DateTime.now().millisecondsSinceEpoch,
          );
        }
        return t;
      }).toList());
    }
  }
}

/// Provider for InboxNotifier.
final inboxNotifierProvider =
    NotifierProvider<InboxNotifier, AsyncValue<List<Transfer>>>(
  InboxNotifier.new,
);

/// Convenience provider: current pending file count (for badge display).
final pendingCountProvider = Provider<int>((ref) {
  return ref
          .watch(inboxNotifierProvider)
          .value
          ?.where((t) => t.status == 'pending')
          .length ??
      0;
});
