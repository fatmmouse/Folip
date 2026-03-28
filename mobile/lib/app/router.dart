import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/inbox/presentation/history_screen.dart';
import '../features/inbox/presentation/inbox_screen.dart';
import '../features/send/presentation/send_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shell/app_shell.dart';

// ---------------------------------------------------------------------------
// Route paths
// ---------------------------------------------------------------------------

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String deviceSetup = '/setup/device-name';
  static const String inbox = '/inbox';
  static const String history = '/history';
  static const String send = '/send';
  static const String settings = '/settings';
}

// ---------------------------------------------------------------------------
// Placeholder screens (replaced in later plans)
// ---------------------------------------------------------------------------

class _DeviceSetupPlaceholder extends StatelessWidget {
  const _DeviceSetupPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Device Setup — coming in Plan 02')),
    );
  }
}

// ---------------------------------------------------------------------------
// Auth state ChangeNotifier for router refreshListenable
// ---------------------------------------------------------------------------

/// ChangeNotifier that listens to authStateProvider and notifies
/// GoRouter to re-evaluate redirect when auth status changes.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(this._ref) {
    _ref.listen<AuthState>(
      authStateProvider,
      (previous, next) {
        if (previous?.status != next.status) {
          notifyListeners();
        }
      },
    );
  }

  final Ref _ref;
}

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

/// GoRouter provider with auth redirect and StatefulShellRoute for bottom tabs.
///
/// Route structure:
///   /login              — unauthenticated users land here
///   /register           — new account creation
///   /setup/device-name  — first-login device naming
///   StatefulShellRoute  — authenticated users (redirects to /login if not authed)
///     Branch 0: /inbox  — default tab (D-18)
///       /history        — pushed from inbox via opened-mail icon
///     Branch 1: /send   — second tab
///       /settings       — pushed from any screen via gear icon
final routerProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = _AuthChangeNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.inbox,
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);

      // Still initializing — don't redirect yet
      if (authState.status == AuthStatus.unknown) {
        return null;
      }

      final isAuthenticated = authState.status == AuthStatus.authenticated;
      final isOnAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.deviceSetup;

      if (!isAuthenticated && !isOnAuthRoute) {
        return AppRoutes.login;
      }

      if (isAuthenticated && isOnAuthRoute) {
        return AppRoutes.inbox;
      }

      return null;
    },
    routes: [
      // Unauthenticated routes
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.deviceSetup,
        builder: (context, state) => const _DeviceSetupPlaceholder(),
      ),

      // Settings — accessible from any authenticated screen via gear icon
      // Declared at top level so it can be navigated to from any branch
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),

      // Authenticated: bottom tab shell with two branches
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Inbox (default tab — D-18)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.inbox,
                builder: (context, state) => const InboxScreen(),
                routes: [
                  // /history is pushed from inbox AppBar
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => const HistoryScreen(),
                  ),
                  // /settings accessible from inbox AppBar gear icon
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),

          // Branch 1: Send
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.send,
                builder: (context, state) => const SendScreen(),
                routes: [
                  // /settings accessible from send AppBar gear icon
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

