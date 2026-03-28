import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../domain/send_notifier.dart';

/// Upload progress display widget.
///
/// Per UI-SPEC Send Screen — upload progress zone:
///   - Uploading: file name, animated progress bar (accent fill), percentage label
///   - Success:   progress bar turns success green, label changes to "Sent"
///   - Error:     destructive error message + accent "Retry" text button
///
/// Shown in place of the file picker zone when status is uploading/success/error.
class UploadProgressWidget extends StatelessWidget {
  final SendState sendState;
  final VoidCallback onRetry;

  const UploadProgressWidget({
    super.key,
    required this.sendState,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    switch (sendState.status) {
      case SendStatus.uploading:
        return _buildUploadingState(context);
      case SendStatus.success:
        return _buildSuccessState(context);
      case SendStatus.error:
        return _buildErrorState(context);
      case SendStatus.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _buildUploadingState(BuildContext context) {
    final percent = (sendState.progress * 100).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File name
          Text(
            sendState.fileName ?? '',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Progress bar + percentage
          Row(
            children: [
              Expanded(
                child: _buildProgressBar(
                  sendState.progress,
                  AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // "Uploading..." label
          const Text(
            'Uploading...',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File name
          Text(
            sendState.fileName ?? '',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Full progress bar in success color
          Row(
            children: [
              Expanded(
                child: _buildProgressBar(1.0, AppColors.success),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                '100%',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // "Sent" label
          const Text(
            'Sent',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.success,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error message
          Text(
            sendState.error ?? 'Upload failed. Check your connection.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.destructive,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Retry button
          GestureDetector(
            onTap: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Full-width progress bar with animated fill.
  Widget _buildProgressBar(double progress, Color fillColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        return ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            children: [
              // Track
              Container(
                height: 6,
                width: totalWidth,
                color: AppColors.secondary,
              ),
              // Fill
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                height: 6,
                width: (progress * totalWidth).clamp(0, totalWidth),
                color: fillColor,
              ),
            ],
          ),
        );
      },
    );
  }
}
