/// Device model matching the backend Device type.
///
/// Backend type (functions/src/types/index.ts):
///   user_id, device_id, device_name, registered_at (Unix ms)
class Device {
  final String deviceId; // maps from 'device_id'
  final String deviceName; // maps from 'device_name'
  final String? userId; // maps from 'user_id'
  final int? registeredAt; // maps from 'registered_at' (Unix ms)

  const Device({
    required this.deviceId,
    required this.deviceName,
    this.userId,
    this.registeredAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceId: json['device_id'] as String,
      deviceName: json['device_name'] as String,
      userId: json['user_id'] as String?,
      registeredAt: json['registered_at'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      if (userId != null) 'user_id': userId,
      if (registeredAt != null) 'registered_at': registeredAt,
    };
  }

  @override
  String toString() => 'Device(id: $deviceId, name: $deviceName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Device && other.deviceId == deviceId;
  }

  @override
  int get hashCode => deviceId.hashCode;
}
