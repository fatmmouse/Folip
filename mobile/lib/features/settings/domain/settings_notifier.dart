import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/device.dart';
import '../../auth/domain/auth_state.dart';
import '../../send/domain/devices_notifier.dart';

// ---------------------------------------------------------------------------
// Settings state
// ---------------------------------------------------------------------------

class SettingsState {
  final List<Device> devices;
  final String? currentDeviceId;
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.devices = const [],
    this.currentDeviceId,
    this.isLoading = false,
    this.error,
  });

  SettingsState copyWith({
    List<Device>? devices,
    String? currentDeviceId,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      devices: devices ?? this.devices,
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// SettingsNotifier
// ---------------------------------------------------------------------------

/// Manages the device list and current device identification for Settings screen.
///
/// On build: immediately loads device list.
/// removeDevice: calls API, reloads list, triggers logout if removing current device.
class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    // Schedule async load after sync build returns — must catch errors
    Future.microtask(() => _loadDevices());
    return const SettingsState(isLoading: true);
  }

  /// Fetches device list and current device ID from API + secure storage.
  Future<void> loadDevices() async {
    await _loadDevices();
  }

  Future<void> _loadDevices() async {
    final apiClient = ref.read(apiClientProvider);
    final storage = ref.read(secureStorageProvider);

    state = state.copyWith(isLoading: true, error: null);

    try {
      final currentDeviceId = await storage.getDeviceId();
      final response = await apiClient.listDevices();

      if (response.ok && response.data != null) {
        state = SettingsState(
          devices: response.data!,
          currentDeviceId: currentDeviceId,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Failed to load devices',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Removes a device from the account.
  ///
  /// Renames a device and reloads the device list.
  Future<void> renameDevice(String deviceId, String newName) async {
    final apiClient = ref.read(apiClientProvider);
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiClient.renameDevice(deviceId, newName);
      if (response.ok) {
        await _loadDevices();
        ref.invalidate(devicesProvider);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Failed to rename device',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// If the removed device is the current device, triggers logout to force
  /// re-authentication on this device.
  Future<void> removeDevice(String deviceId) async {
    final apiClient = ref.read(apiClientProvider);

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await apiClient.removeDevice(deviceId);

      if (response.ok) {
        if (deviceId == state.currentDeviceId) {
          // Removing current device — trigger logout
          await ref.read(authStateProvider.notifier).logout();
        } else {
          // Reload device list after successful removal
          await _loadDevices();
          ref.invalidate(devicesProvider);
        }
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Failed to remove device',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final settingsNotifierProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
