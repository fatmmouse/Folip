import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../auth/domain/auth_state.dart';
import '../domain/settings_notifier.dart';

/// Settings screen — pushed onto navigation stack via gear icon.
///
/// Sections:
///   1. "THIS DEVICE" — current device name
///   2. "MY DEVICES" — all registered devices with remove button
///   3. "ACCOUNT" — logout
///
/// Per UI-SPEC Settings Screen and D-14.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.dominant,
      appBar: AppBar(
        backgroundColor: AppColors.dominant,
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.sourceSerif4(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: settingsState.isLoading && settingsState.devices.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : settingsState.error != null && settingsState.devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        settingsState.error!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.destructive,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref
                            .read(settingsNotifierProvider.notifier)
                            .loadDevices(),
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : _buildContent(context, settingsState),
    );
  }

  Widget _buildContent(BuildContext context, SettingsState settingsState) {
    final currentDevice = settingsState.devices
        .where((d) => d.deviceId == settingsState.currentDeviceId)
        .toList();

    return ListView(
      children: [
        // ----------------------------------------------------------------
        // Section 1: This device
        // ----------------------------------------------------------------
        _SectionHeader(label: 'THIS DEVICE'),
        ...currentDevice.map((device) => _DeviceRow(
              deviceName: device.deviceName,
              isCurrentDevice: true,
              onRemove: null,
            )),
        if (currentDevice.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Unknown device',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        const _Divider(),

        // ----------------------------------------------------------------
        // Section 2: My devices
        // ----------------------------------------------------------------
        _SectionHeader(label: 'MY DEVICES', topPadding: 24),
        ...settingsState.devices.map((device) {
          final isCurrent = device.deviceId == settingsState.currentDeviceId;
          return Column(
            children: [
              _DeviceRow(
                deviceName: device.deviceName,
                isCurrentDevice: isCurrent,
                onRemove: isCurrent
                    ? null
                    : () => _confirmRemove(context, device.deviceId,
                        device.deviceName, settingsState),
              ),
              const _Divider(),
            ],
          );
        }),

        // ----------------------------------------------------------------
        // Section 3: Account
        // ----------------------------------------------------------------
        _SectionHeader(label: 'ACCOUNT', topPadding: 24),
        InkWell(
          onTap: () {
            ref.read(authStateProvider.notifier).logout();
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Log Out',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.destructive,
              ),
            ),
          ),
        ),
        const _Divider(),
      ],
    );
  }

  void _confirmRemove(
    BuildContext context,
    String deviceId,
    String deviceName,
    SettingsState settingsState,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dominant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Remove $deviceName?',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This device will be signed out.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.destructive,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  ref
                      .read(settingsNotifierProvider.notifier)
                      .removeDevice(deviceId);
                },
                child: const Text(
                  'Remove',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: TextButton(
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helper widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  final double topPadding;

  const _SectionHeader({required this.label, this.topPadding = 8});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final String deviceName;
  final bool isCurrentDevice;
  final VoidCallback? onRemove;

  const _DeviceRow({
    required this.deviceName,
    required this.isCurrentDevice,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  deviceName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (isCurrentDevice) ...[
                  const SizedBox(width: 6),
                  const Text(
                    '(this device)',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isCurrentDevice && onRemove != null)
            TextButton(
              onPressed: onRemove,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Remove',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.destructive,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.secondary,
    );
  }
}
