import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../inbox/domain/inbox_notifier.dart';

/// Bottom tab bar shell for authenticated screens.
///
/// Tab 0: Inbox (with badge showing pending file count)
/// Tab 1: Send
///
/// Per UI-SPEC Navigation Structure: tab bar background #E8E6DC,
/// active color #D97757, inactive #B0AEA5.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(pendingCountProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.secondary,
        selectedIndex: navigationShell.currentIndex,
        indicatorColor: AppColors.secondary, // No indicator pill, just icon color change
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text(
                '$pendingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.inbox, color: AppColors.textSecondary),
            ),
            selectedIcon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text(
                '$pendingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.inbox, color: AppColors.accent),
            ),
            label: 'Inbox',
          ),
          const NavigationDestination(
            icon: Icon(Icons.upload, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.upload, color: AppColors.accent),
            label: 'Send',
          ),
        ],
      ),
    );
  }
}
