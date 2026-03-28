import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../auth/domain/auth_state.dart';
import '../domain/settings_notifier.dart';

/// Settings screen matching Mac app's SettingsView design.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.dominant,
      appBar: AppBar(
        backgroundColor: AppColors.dominant,
        elevation: 0,
      ),
      body: settingsState.isLoading && settingsState.devices.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : settingsState.error != null && settingsState.devices.isEmpty
              ? _buildError(context, ref, settingsState.error!)
              : _buildContent(context, ref, settingsState),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error,
              style: const TextStyle(fontSize: 14, color: AppColors.destructive),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () =>
                ref.read(settingsNotifierProvider.notifier).loadDevices(),
            child: const Text('Retry',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, SettingsState settingsState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title — matches Mac "Account"
          Text(
            'Account',
            style: GoogleFonts.sourceSerif4(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

          // Error banner
          if (settingsState.error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(settingsState.error!,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.destructive)),
            ),
            const SizedBox(height: 16),
          ],

          // "Devices" section header
          Text(
            'Devices',
            style: GoogleFonts.sourceSerif4(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Device list
          Expanded(
            child: ListView(
              children: [
                ...settingsState.devices.map((device) {
                  final isCurrent =
                      device.deviceId == settingsState.currentDeviceId;
                  return _DeviceRow(
                    deviceName: device.deviceName,
                    registeredAt: device.registeredAt,
                    isCurrent: isCurrent,
                    onRemove: isCurrent
                        ? null
                        : () => _confirmRemove(
                            context, ref, device.deviceId, device.deviceName),
                    onRename: () => _renameDevice(
                        context, ref, device.deviceId, device.deviceName),
                  );
                }),
                if (settingsState.devices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('No other devices',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.textPrimary)),
                        SizedBox(height: 2),
                        Text(
                            'Log in on another device to start sending files.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Log Out button at bottom
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(authStateProvider.notifier).logout(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.destructive),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.destructive,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(
      BuildContext context, WidgetRef ref, String deviceId, String deviceName) {
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
            Text('Remove $deviceName?',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('This device will need to log in again.',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.destructive,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  ref
                      .read(settingsNotifierProvider.notifier)
                      .removeDevice(deviceId);
                },
                child: const Text('Remove Device',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.secondary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _renameDevice(
      BuildContext context, WidgetRef ref, String deviceId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dominant,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Rename Device',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.secondary.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final newName = controller.text.trim();
                  if (newName.isNotEmpty && newName != currentName) {
                    Navigator.of(context).pop();
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .renameDevice(deviceId, newName);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Save',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Device row — name + registered date + trash icon for removal
class _DeviceRow extends StatelessWidget {
  final String deviceName;
  final int? registeredAt;
  final bool isCurrent;
  final VoidCallback? onRemove;
  final VoidCallback? onRename;

  const _DeviceRow({
    required this.deviceName,
    this.registeredAt,
    required this.isCurrent,
    this.onRemove,
    this.onRename,
  });

  String _formatDate(int? epochMs) {
    if (epochMs == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(epochMs);
    return 'Registered ${DateFormat.yMMMd().format(date)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.secondary, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deviceName,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary)),
                if (registeredAt != null)
                  Text(_formatDate(registeredAt),
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4)),
              ],
            ),
          ),
          if (onRename != null)
            IconButton(
              onPressed: onRename,
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.textSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: 'Rename device',
            ),
          if (!isCurrent && onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.textSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: 'Remove device',
            ),
        ],
      ),
    );
  }
}
