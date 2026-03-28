import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Result of a successful transfer prepare call.
///
/// Contains the presigned PUT URL and metadata needed to complete the transfer.
class PrepareResult {
  final String transferId;
  final String uploadUrl;
  final String ossKey;

  const PrepareResult({
    required this.transferId,
    required this.uploadUrl,
    required this.ossKey,
  });
}

/// Repository for transfer API operations.
///
/// Wraps ApiClient for the two transfer calls in the send flow:
///   1. prepareTransfer — get presigned PUT URL from backend
///   2. confirmTransfer — notify backend that upload to OSS is complete
///
/// The actual file upload (PUT to OSS) is handled by UploadService, not here.
class TransferRepository {
  final ApiClient _apiClient;

  TransferRepository(this._apiClient);

  /// Calls POST /transfers/prepare and returns the presigned URL + transfer ID.
  ///
  /// Throws an Exception if the API returns an error (e.g., file too large).
  Future<PrepareResult> prepareTransfer(
    String targetDeviceId,
    String fileName,
    int fileSize,
  ) async {
    final response = await _apiClient.prepareTransfer(
      targetDeviceId: targetDeviceId,
      fileName: fileName,
      fileSize: fileSize,
    );

    if (!response.ok || response.data == null) {
      throw Exception(response.error ?? 'Failed to prepare transfer');
    }

    return PrepareResult(
      transferId: response.data!.transferId,
      uploadUrl: response.data!.uploadUrl,
      ossKey: response.data!.ossKey,
    );
  }

  /// Calls POST /transfers/:id/confirm to mark the upload as complete.
  ///
  /// Backend sets transfer status to "pending" so the recipient can see it.
  Future<void> confirmTransfer(
    String transferId,
    String targetDeviceId,
  ) async {
    final response = await _apiClient.confirmTransfer(
      transferId: transferId,
      targetDeviceId: targetDeviceId,
    );

    if (!response.ok) {
      throw Exception(response.error ?? 'Failed to confirm transfer');
    }
  }
}

/// Riverpod provider for TransferRepository.
final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return TransferRepository(ref.read(apiClientProvider));
});
