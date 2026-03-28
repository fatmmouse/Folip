import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/transfer.dart';
import '../domain/download_manager.dart';
import 'envelope_card_widget.dart';

/// Perspective-depth stack of envelope cards.
///
/// Layer 1 (front): full size, 100% opacity, swipe-interactive
/// Layer 2 (middle): 92% scale, +6dp right, 85% opacity
/// Layer 3 (back): 84% scale, +12dp right, 70% opacity
///
/// Swipe-to-extract: swipe up >= 60dp distance OR >= 250dp/s velocity
/// Below threshold: spring-back with elastic animation (200ms)
/// Above threshold: extraction animation (400ms ease-out) then download starts
class EnvelopeStackWidget extends ConsumerStatefulWidget {
  final List<Transfer> pendingTransfers;

  const EnvelopeStackWidget({
    super.key,
    required this.pendingTransfers,
  });

  @override
  ConsumerState<EnvelopeStackWidget> createState() =>
      _EnvelopeStackWidgetState();
}

class _EnvelopeStackWidgetState extends ConsumerState<EnvelopeStackWidget>
    with TickerProviderStateMixin {
  // Current vertical drag offset for the front envelope (negative = upward)
  double _dragOffset = 0;

  // Whether an extraction animation is running
  bool _isExtracting = false;

  // Spring-back animation controller
  late AnimationController _springBackController;
  late Animation<double> _springBackAnimation;

  // Extraction animation controller
  late AnimationController _extractController;
  late Animation<double> _extractAnimation;

  // Stack advance animation (next card scales up)
  late AnimationController _advanceController;
  late Animation<double> _advanceAnimation;

  // The transfer being extracted (for letter offset during animation)
  double _letterOffsetDuringExtraction = 0;

  @override
  void initState() {
    super.initState();

    _springBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _extractController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _advanceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _springBackAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _springBackController, curve: Curves.elasticOut),
    );

    _extractAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _extractController, curve: Curves.easeOut),
    );

    _advanceAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _advanceController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _springBackController.dispose();
    _extractController.dispose();
    _advanceController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isExtracting) return;
    setState(() {
      _dragOffset += details.delta.dy;
      // Only allow upward drag (negative values)
      if (_dragOffset > 0) _dragOffset = 0;
      // Update letter offset proportional to drag (max rise at 120dp drag)
      _letterOffsetDuringExtraction =
          (-_dragOffset / 120).clamp(0.0, 0.8);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_isExtracting) return;

    final velocity = details.velocity.pixelsPerSecond.dy;

    // Threshold: 60dp distance OR 250dp/s upward velocity
    if (_dragOffset <= -60 || velocity <= -250) {
      _extractEnvelope();
    } else {
      _springBack();
    }
  }

  void _springBack() {
    final startOffset = _dragOffset;
    _springBackAnimation = Tween<double>(begin: startOffset, end: 0).animate(
      CurvedAnimation(parent: _springBackController, curve: Curves.elasticOut),
    );

    _springBackController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _dragOffset = 0;
          _letterOffsetDuringExtraction = 0;
        });
      }
    });

    _springBackController.addListener(() {
      if (mounted) {
        setState(() {
          _dragOffset = _springBackAnimation.value;
          _letterOffsetDuringExtraction =
              (-_dragOffset / 120).clamp(0.0, 0.8);
        });
      }
    });
  }

  void _extractEnvelope() {
    if (widget.pendingTransfers.isEmpty) return;
    _isExtracting = true;

    final transfer = widget.pendingTransfers.first;

    // Animate letter fully out, then shrink card to right edge
    _extractController.forward(from: 0).then((_) {
      if (!mounted) return;

      // Start download
      ref.read(downloadManagerProvider.notifier).startDownload(transfer);

      // Animate next card advancing
      _advanceController.forward(from: 0);

      setState(() {
        _isExtracting = false;
        _dragOffset = 0;
        _letterOffsetDuringExtraction = 0;
      });
      _extractController.reset();
      _advanceController.reset();
    });

    // Drive letter offset during extraction animation
    _extractController.addListener(() {
      if (mounted) {
        setState(() {
          _letterOffsetDuringExtraction =
              (_extractAnimation.value).clamp(0.0, 1.0);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final transfers = widget.pendingTransfers;
    if (transfers.isEmpty) return const SizedBox.shrink();

    // Determine layers to render (max 3)
    final layerCount = transfers.length.clamp(1, 3);

    return SizedBox(
      width: 320,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back layers (rendered first, behind front)
          for (int i = layerCount - 1; i >= 1; i--)
            _buildBackLayer(i, transfers[i < transfers.length ? i : 0]),

          // Front envelope (interactive)
          _buildFrontEnvelope(transfers.first),
        ],
      ),
    );
  }

  Widget _buildBackLayer(int layerIndex, Transfer transfer) {
    // Layer 2: scale 0.92, offset +6dp, opacity 0.85
    // Layer 3+: scale 0.84, offset +12dp, opacity 0.70
    final double scale = layerIndex == 1 ? 0.92 : 0.84;
    final double offsetX = layerIndex == 1 ? 6.0 : 12.0;
    final double opacity = layerIndex == 1 ? 0.85 : 0.70;

    // Animate advance: when front is extracted, layer 2 advances to front size
    double effectiveScale = scale;
    double effectiveOffsetX = offsetX;
    double effectiveOpacity = opacity;

    if (_isExtracting && layerIndex == 1) {
      effectiveScale = scale + (1.0 - scale) * _advanceAnimation.value;
      effectiveOffsetX = offsetX * (1.0 - _advanceAnimation.value);
      effectiveOpacity = opacity + (1.0 - opacity) * _advanceAnimation.value;
    }

    return Transform.translate(
      offset: Offset(effectiveOffsetX, 0),
      child: Transform.scale(
        scale: effectiveScale,
        child: Opacity(
          opacity: effectiveOpacity,
          child: EnvelopeCardWidget(transfer: transfer),
        ),
      ),
    );
  }

  Widget _buildFrontEnvelope(Transfer transfer) {
    // During extraction: animate card shrinking and moving to right edge
    // During normal drag: translate upward by drag offset
    double translateY = _dragOffset;
    double translateX = 0;
    double scale = 1.0;
    double opacity = 1.0;

    if (_isExtracting) {
      // Card flies to right edge: scale down to ~0.1 and move right
      translateX = _extractAnimation.value * 180;
      translateY = _extractAnimation.value * -30;
      scale = 1.0 - _extractAnimation.value * 0.9;
      opacity = 1.0 - _extractAnimation.value * 0.3;
    }

    return Transform.translate(
      offset: Offset(translateX, translateY),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: GestureDetector(
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: EnvelopeCardWidget(
              transfer: transfer,
              letterOffset: _letterOffsetDuringExtraction,
            ),
          ),
        ),
      ),
    );
  }
}
