import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../domain/download_manager.dart';
import '../domain/inbox_notifier.dart';

/// Paints a mini envelope (~32x24dp) with a letter emerging from the top.
///
/// [letterProgress] 0.0 = letter fully inside, 1.0 = letter fully extracted.
class _MiniEnvelopePainter extends CustomPainter {
  final double letterProgress; // 0.0 to 1.0
  final Color envelopeColor;

  const _MiniEnvelopePainter({
    required this.letterProgress,
    required this.envelopeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final envelopePaint = Paint()
      ..color = envelopeColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppColors.textSecondary.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final letterPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final letterBorderPaint = Paint()
      ..color = AppColors.textSecondary.withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final linePaint = Paint()
      ..color = AppColors.textSecondary.withAlpha(80)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;

    // Envelope body
    final envelopeRect =
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height),
            const Radius.circular(2));
    canvas.drawRRect(envelopeRect, envelopePaint);
    canvas.drawRRect(envelopeRect, borderPaint);

    // Letter paper — rises from envelope top
    // At progress=0: fully inside (top of letter at envelope top edge)
    // At progress=1: fully above envelope
    final letterHeight = size.height * 0.85;
    final letterWidth = size.width * 0.70;
    final letterX = (size.width - letterWidth) / 2;
    // Letter top Y: at 0 = envelope top, at 1 = -letterHeight (fully above)
    final letterTopY = (1.0 - letterProgress) * size.height - letterHeight;

    canvas.save();
    // Clip to envelope area so letter appears to emerge from inside
    canvas.clipRect(Rect.fromLTWH(
        letterX - 1, -letterHeight, letterWidth + 2, size.height + letterHeight));

    final letterRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(letterX, letterTopY, letterWidth, letterHeight),
      const Radius.circular(1),
    );
    canvas.drawRRect(letterRect, letterPaint);
    canvas.drawRRect(letterRect, letterBorderPaint);

    // 2 thin lines on letter (simulating text)
    if (letterProgress > 0.2) {
      final lineY1 = letterTopY + letterHeight * 0.35;
      final lineY2 = letterTopY + letterHeight * 0.60;
      canvas.drawLine(Offset(letterX + 2, lineY1),
          Offset(letterX + letterWidth - 2, lineY1), linePaint);
      canvas.drawLine(Offset(letterX + 2, lineY2),
          Offset(letterX + letterWidth - 2, lineY2), linePaint);
    }

    canvas.restore();

    // Envelope flap (triangle) — drawn on top to cover letter inside envelope
    final flapPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height * 0.45)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(flapPath, envelopePaint);
    canvas.drawPath(flapPath,
        Paint()
          ..color = AppColors.textSecondary.withAlpha(80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);
  }

  @override
  bool shouldRepaint(covariant _MiniEnvelopePainter oldDelegate) {
    return oldDelegate.letterProgress != letterProgress ||
        oldDelegate.envelopeColor != envelopeColor;
  }
}

/// A single mini envelope icon showing download progress via letter emergence.
///
/// Displayed on the right edge of the Inbox screen during active downloads.
/// On complete: triggers arc-flight animation toward top-left AppBar icon.
/// On failure: tints red and shows tap-to-retry.
class _MiniEnvelopeItem extends ConsumerStatefulWidget {
  final String transferId;
  final DownloadState downloadState;

  const _MiniEnvelopeItem({
    required this.transferId,
    required this.downloadState,
  });

  @override
  ConsumerState<_MiniEnvelopeItem> createState() => _MiniEnvelopeItemState();
}

class _MiniEnvelopeItemState extends ConsumerState<_MiniEnvelopeItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _flyController;
  late Animation<Offset> _flyAnimation;
  bool _flying = false;

  @override
  void initState() {
    super.initState();
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Arc flight: fly toward top-left (approximate — actual position varies
    // by screen size but a fixed offset of (-200, -400) works for most phones)
    _flyAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-6, -16), // relative to size
    ).animate(
      CurvedAnimation(parent: _flyController, curve: Curves.easeIn),
    );
  }

  @override
  void didUpdateWidget(covariant _MiniEnvelopeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_flying &&
        widget.downloadState.status == DownloadStatus.complete &&
        oldWidget.downloadState.status != DownloadStatus.complete) {
      _startFlyAnimation();
    }
  }

  void _startFlyAnimation() {
    setState(() => _flying = true);
    _flyController.forward().then((_) {
      if (mounted) {
        // Mark as downloaded in inbox notifier (optimistic update)
        ref
            .read(inboxNotifierProvider.notifier)
            .markAsDownloaded(widget.transferId);
        // Remove from download manager
        ref
            .read(downloadManagerProvider.notifier)
            .clearCompleted(widget.transferId);
      }
    });
  }

  @override
  void dispose() {
    _flyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.downloadState;
    final bool isFailed = state.status == DownloadStatus.failed;
    final Color envelopeColor =
        isFailed ? AppColors.destructive.withAlpha(200) : AppColors.secondary;

    Widget icon = CustomPaint(
      size: const Size(32, 24),
      painter: _MiniEnvelopePainter(
        letterProgress: state.progress,
        envelopeColor: envelopeColor,
      ),
    );

    if (isFailed) {
      // Tap to retry — need transfer data; we just remove and let InboxScreen re-trigger
      icon = GestureDetector(
        onTap: () {
          // Remove failed state; user can swipe again from inbox
          ref
              .read(downloadManagerProvider.notifier)
              .clearCompleted(widget.transferId);
        },
        child: icon,
      );
    }

    if (_flying) {
      return SlideTransition(
        position: _flyAnimation,
        child: icon,
      );
    }

    return icon;
  }
}

/// Column of mini envelope icons on the right edge of the inbox screen.
///
/// Each active download gets one mini icon showing letter-emergence progress.
/// Multiple concurrent downloads stack vertically with 8dp gap.
class MiniDownloadWidget extends ConsumerWidget {
  const MiniDownloadWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadManagerProvider);

    if (downloads.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: downloads.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _MiniEnvelopeItem(
            transferId: entry.key,
            downloadState: entry.value,
          ),
        );
      }).toList(),
    );
  }
}
