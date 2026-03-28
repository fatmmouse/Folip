import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

// ---------------------------------------------------------------------------
// Auth status enum
// ---------------------------------------------------------------------------

enum AuthStatus { unknown, authenticated, unauthenticated }

// ---------------------------------------------------------------------------
// Auth state class
// ---------------------------------------------------------------------------

class AuthState {
  final AuthStatus status;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// AuthNotifier
// ---------------------------------------------------------------------------

/// Manages the full auth lifecycle: initial check, login, register, logout.
///
/// On init (build): checks for a stored access token to determine initial auth status.
/// On login/register: delegates to AuthRepository, updates state accordingly.
/// On logout: clears tokens and resets to unauthenticated.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Schedule async init after sync build returns
    _init();
    return const AuthState(status: AuthStatus.unknown);
  }

  /// Checks stored token on startup to determine initial auth status.
  Future<void> _init() async {
    final repo = ref.read(authRepositoryProvider);
    final hasAuth = await repo.checkAuth();
    state = AuthState(
      status: hasAuth ? AuthStatus.authenticated : AuthStatus.unauthenticated,
    );
  }

  /// Authenticates with email/password and device name.
  /// Sets state to authenticated on success, or sets error on failure.
  Future<void> login(String email, String password, String deviceName) async {
    final repo = ref.read(authRepositoryProvider);
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await repo.login(email, password, deviceName);
      if (result.success) {
        state = const AuthState(status: AuthStatus.authenticated);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.error ?? 'Login failed',
        );
      }
    } catch (e) {
      String errorMsg = 'Login failed';
      if (e is DioException && e.response?.data is Map) {
        errorMsg =
            (e.response?.data as Map)['error'] as String? ?? errorMsg;
      }
      state = state.copyWith(isLoading: false, error: errorMsg);
    }
  }

  /// Registers a new account with email/password and device name.
  /// Sets state to authenticated on success, or sets error on failure.
  Future<void> register(
      String email, String password, String deviceName) async {
    final repo = ref.read(authRepositoryProvider);
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await repo.register(email, password, deviceName);
      if (result.success) {
        state = const AuthState(status: AuthStatus.authenticated);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.error ?? 'Registration failed',
        );
      }
    } catch (e) {
      String errorMsg = 'Registration failed';
      if (e is DioException && e.response?.data is Map) {
        errorMsg =
            (e.response?.data as Map)['error'] as String? ?? errorMsg;
      }
      state = state.copyWith(isLoading: false, error: errorMsg);
    }
  }

  /// Logs out: clears tokens and navigates back to unauthenticated state.
  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Force logout without calling API (used when tokens are already invalid,
  /// e.g., after AuthInterceptor token refresh failure).
  Future<void> forceLogout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// NotifierProvider for auth state management.
/// Used by the router redirect guard and all auth-aware screens.
final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
