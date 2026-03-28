import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/device.dart';

/// FutureProvider that fetches the device list and filters out the current device.
///
/// The Send screen shows only OTHER devices as potential targets — you cannot
/// send a file to yourself. This provider returns the filtered list.
final devicesProvider = FutureProvider<List<Device>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final storage = ref.read(secureStorageProvider);

  final currentDeviceId = await storage.getDeviceId();
  final response = await apiClient.listDevices();

  if (!response.ok) {
    throw Exception(response.error ?? 'Failed to fetch devices');
  }

  final devices = (response.data ?? [])
      .where((d) => d.deviceId != currentDeviceId) // exclude self
      .toList();

  return devices;
});

// ---------------------------------------------------------------------------
// Selected device provider (mutable — replaced by user chip tap)
// ---------------------------------------------------------------------------

/// Notifier for the currently selected target device ID.
///
/// Null means no device is selected. Updated by DeviceSelectorWidget on chip tap.
class SelectedDeviceNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? deviceId) {
    state = deviceId;
  }
}

/// Provider for the selected target device ID.
final selectedDeviceProvider =
    NotifierProvider<SelectedDeviceNotifier, String?>(
        SelectedDeviceNotifier.new);

// ---------------------------------------------------------------------------
// Pre-selection initializer
// ---------------------------------------------------------------------------

/// FutureProvider that pre-selects the last-used target device on first load.
///
/// Verifies the pre-selected device still exists in the current device list
/// (avoids pre-selecting a device that was removed since last session).
final initSelectedDeviceProvider = FutureProvider<void>((ref) async {
  final storage = ref.read(secureStorageProvider);
  final lastTarget = await storage.getLastTargetDevice();

  if (lastTarget != null) {
    // Only pre-select if the device still exists in the list
    final devices = await ref.watch(devicesProvider.future);
    final stillExists = devices.any((d) => d.deviceId == lastTarget);
    if (stillExists) {
      ref.read(selectedDeviceProvider.notifier).select(lastTarget);
    }
  }
});
