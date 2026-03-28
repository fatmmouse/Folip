import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Reusable error + retry widget (D-20).
///
/// Shows a centered column with an error message and a "Retry" button.
/// Used by screens that need full-screen error state with manual retry.
class ErrorRetryWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRetryWidget({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.destructive,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Auto-retry utility
// ---------------------------------------------------------------------------

/// Retries [action] up to [maxRetries] times with exponential backoff.
///
/// Backoff schedule: 2s, 4s, 6s (linear backoff, capped at maxRetries × 2s).
/// If all retries fail, the last exception is rethrown.
///
/// Use this for network calls that may have transient failures before
/// falling back to showing an [ErrorRetryWidget] to the user.
Future<T> withAutoRetry<T>(
  Future<T> Function() action, {
  int maxRetries = 3,
}) async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      return await action();
    } catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(Duration(seconds: (i + 1) * 2)); // 2s, 4s, 6s
    }
  }
  throw StateError('Unreachable');
}
