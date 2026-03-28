import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../domain/devices_notifier.dart';

/// Horizontal scrollable chip row for selecting the target device.
///
/// Per UI-SPEC Send Screen — Device Selector zone:
///   - Section label "Send to" at top
///   - Chips: unselected = secondary bg, selected = accent bg/white text
///   - Loading: shimmer placeholder chips
///   - Empty: "No other devices found" text
///   - Excludes current device (filtered in devicesProvider)
///   - Pre-selects last-used device (via initSelectedDeviceProvider)
class DeviceSelectorWidget extends ConsumerWidget {
  const DeviceSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);
    final selectedDeviceId = ref.watch(selectedDeviceProvider);

    // Trigger last-used device pre-selection (no-op if already done)
    ref.watch(initSelectedDeviceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
          ),
          child: Text(
            'Send to',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Device chip row
        devicesAsync.when(
          loading: () => _buildShimmerChips(),
          error: (e, _) => _buildEmptyState(),
          data: (devices) {
            if (devices.isEmpty) {
              return _buildEmptyState();
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: devices.map((device) {
                  final isSelected = device.deviceId == selectedDeviceId;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () {
                        ref
                            .read(selectedDeviceProvider.notifier)
                            .select(device.deviceId);
                      },
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.secondary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          device.deviceName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Three shimmer placeholder chips for loading state.
  Widget _buildShimmerChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Container(
              height: 36,
              width: 80 + (i * 16.0),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Empty state when no other devices are registered.
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Text(
        'No other devices found',
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}
