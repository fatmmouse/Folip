import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/models/transfer.dart';

/// Paints the triangular envelope flap at the top of the card.
class _EnvelopeFlapPainter extends CustomPainter {
  const _EnvelopeFlapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height * 0.6)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints the "letter" peeking out of the envelope during extraction.
///
/// Shows 2-3 thin gray horizontal lines simulating written content.
class _LetterContentPainter extends CustomPainter {
  const _LetterContentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.textSecondary.withAlpha(100)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final rectPaint = Paint()
      ..color = AppColors.textSecondary.withAlpha(60)
      ..style = PaintingStyle.fill;

    // Small rectangle (like a heading block)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.2, size.height * 0.15,
            size.width * 0.3, size.height * 0.08),
        const Radius.circular(2),
      ),
      rectPaint,
    );

    // Three horizontal lines simulating text
    final lineY = [0.35, 0.50, 0.65];
    for (final y in lineY) {
      canvas.drawLine(
        Offset(size.width * 0.15, size.height * y),
        Offset(size.width * 0.85, size.height * y),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A single envelope card showing file info and swipe affordance.
///
/// Used as both the full-size front card and (scaled) the depth layers.
/// The [letterOffset] controls how far the letter has risen above the
/// envelope top (0.0 = fully inside, 1.0 = fully extracted — used during
/// swipe animation in EnvelopeStackWidget).
class EnvelopeCardWidget extends StatelessWidget {
  final Transfer transfer;

  /// How far the letter has risen (0.0 = inside envelope, 1.0 = fully out).
  final double letterOffset;

  const EnvelopeCardWidget({
    super.key,
    required this.transfer,
    this.letterOffset = 0.0,
  });

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  @override
  Widget build(BuildContext context) {
    const cardWidth = 300.0;
    const cardHeight = 200.0; // ~3:2 landscape envelope shape
    const flapHeight = 60.0;
    const letterWidth = cardWidth * 0.85;
    const letterHeight = cardHeight * 0.70;

    // Letter rises from the envelope: at letterOffset=0 fully hidden,
    // at letterOffset=1 the full letter is visible above the card top.
    final letterYOffset = -letterHeight * letterOffset;

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The envelope card body
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondary, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),

          // Envelope flap at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: CustomPaint(
                size: const Size(cardWidth, flapHeight),
                painter: const _EnvelopeFlapPainter(),
              ),
            ),
          ),

          // Letter (emerges from envelope during swipe — clipped at card top)
          if (letterOffset > 0)
            Positioned(
              top: letterYOffset,
              left: (cardWidth - letterWidth) / 2,
              child: Container(
                width: letterWidth,
                height: letterHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: AppColors.textSecondary.withAlpha(80), width: 0.5),
                ),
                child: const CustomPaint(
                  painter: _LetterContentPainter(),
                ),
              ),
            ),

          // Card content: file name + sender info
          Positioned(
            left: 16,
            right: 16,
            top: flapHeight + 8,
            child: Column(
              children: [
                Text(
                  transfer.fileName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'from ${transfer.senderDeviceId} · ${_formatFileSize(transfer.fileSize)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Swipe affordance at bottom
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Icon(
                  Icons.keyboard_arrow_up,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                Text(
                  'swipe up',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
