import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../shared/models/transfer.dart';

/// Repository for inbox operations.
///
/// Wraps ApiClient to fetch and sort transfers, and to mark them as downloaded.
class InboxRepository {
  final ApiClient _apiClient;

  InboxRepository(this._apiClient);

  /// Fetches the inbox and returns transfers sorted:
  /// pending first (newest first), then downloaded (newest first).
  Future<List<Transfer>> fetchInbox() async {
    final response = await _apiClient.getInbox();

    if (!response.ok) {
      throw Exception(response.error ?? 'Failed to fetch inbox');
    }

    final transfers = List<Transfer>.from(response.data!.transfers);

    // Sort: pending first (newest first), then downloaded (newest first)
    transfers.sort((a, b) {
      if (a.status == 'pending' && b.status != 'pending') return -1;
      if (a.status != 'pending' && b.status == 'pending') return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    return transfers;
  }

  /// Marks a transfer as downloaded on the backend.
  Future<void> markDownloaded(String transferId) async {
    final response = await _apiClient.markDownloaded(transferId);
    if (!response.ok) {
      throw Exception(response.error ?? 'Failed to mark as downloaded');
    }
  }
}

/// Riverpod provider for InboxRepository.
final inboxRepositoryProvider = Provider<InboxRepository>((ref) {
  return InboxRepository(ref.read(apiClientProvider));
});
