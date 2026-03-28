/// Transfer model matching the backend Transfer type exactly.
///
/// Backend type (functions/src/types/index.ts):
///   transfer_id, file_name, file_size (bytes), sender_device_id,
///   target_device_id, oss_key, status, created_at (Unix ms),
///   downloaded_at? (Unix ms)
///
/// Inbox response also includes:
///   download_url (presigned GET URL, only in inbox response)
class Transfer {
  final String transferId; // maps from 'transfer_id'
  final String fileName; // maps from 'file_name'
  final int fileSize; // maps from 'file_size' (bytes)
  final String senderDeviceId; // maps from 'sender_device_id'
  final String? targetDeviceId; // maps from 'target_device_id'
  final String? ossKey; // maps from 'oss_key'
  final int createdAt; // maps from 'created_at' (Unix ms)
  final String status; // 'uploading' | 'pending' | 'downloaded'
  final String? downloadUrl; // maps from 'download_url' (presigned GET, inbox only)
  final int? downloadedAt; // maps from 'downloaded_at'

  const Transfer({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.senderDeviceId,
    this.targetDeviceId,
    this.ossKey,
    required this.createdAt,
    required this.status,
    this.downloadUrl,
    this.downloadedAt,
  });

  factory Transfer.fromJson(Map<String, dynamic> json) {
    return Transfer(
      transferId: json['transfer_id'] as String,
      fileName: json['file_name'] as String,
      fileSize: json['file_size'] as int,
      senderDeviceId: json['sender_device_id'] as String,
      targetDeviceId: json['target_device_id'] as String?,
      ossKey: json['oss_key'] as String?,
      createdAt: json['created_at'] as int,
      status: json['status'] as String,
      downloadUrl: json['download_url'] as String?,
      downloadedAt: json['downloaded_at'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transfer_id': transferId,
      'file_name': fileName,
      'file_size': fileSize,
      'sender_device_id': senderDeviceId,
      if (targetDeviceId != null) 'target_device_id': targetDeviceId,
      if (ossKey != null) 'oss_key': ossKey,
      'created_at': createdAt,
      'status': status,
      if (downloadUrl != null) 'download_url': downloadUrl,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
    };
  }

  bool get isPending => status == 'pending';
  bool get isDownloaded => status == 'downloaded';
  bool get isUploading => status == 'uploading';

  Transfer copyWith({
    String? transferId,
    String? fileName,
    int? fileSize,
    String? senderDeviceId,
    String? targetDeviceId,
    String? ossKey,
    int? createdAt,
    String? status,
    String? downloadUrl,
    int? downloadedAt,
  }) {
    return Transfer(
      transferId: transferId ?? this.transferId,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      senderDeviceId: senderDeviceId ?? this.senderDeviceId,
      targetDeviceId: targetDeviceId ?? this.targetDeviceId,
      ossKey: ossKey ?? this.ossKey,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }

  @override
  String toString() =>
      'Transfer(id: $transferId, name: $fileName, status: $status)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transfer && other.transferId == transferId;
  }

  @override
  int get hashCode => transferId.hashCode;
}
