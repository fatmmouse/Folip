import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Connectivity-aware offline banner (D-21).
///
/// Shows a 40dp red-tinted bar at the top of the screen when the device
/// loses network connectivity. Auto-dismisses with a slide-up animation
/// when connectivity is restored.
///
/// Place ABOVE the body content but BELOW the AppBar:
///   Column([OfflineBanner(), Expanded(child: body)])
class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key});

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.contains(ConnectivityResult.none) &&
          results.length == 1;
      if (offline && !_isOffline) {
        setState(() => _isOffline = true);
        _controller.forward();
      } else if (!offline && _isOffline) {
        _controller.reverse().then((_) {
          if (mounted) {
            setState(() => _isOffline = false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: 40,
        width: double.infinity,
        color: const Color(0xFFC53030).withValues(alpha: 0.12),
        child: const Center(
          child: Text(
            'No network connection',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFFC53030),
            ),
          ),
        ),
      ),
    );
  }
}
