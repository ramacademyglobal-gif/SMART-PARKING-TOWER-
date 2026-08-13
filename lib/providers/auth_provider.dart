import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/core/providers/core_providers.dart';
import 'package:multiparking_tower/models/auth_session_model.dart';
import 'package:multiparking_tower/models/user_model.dart';
import 'package:multiparking_tower/providers/onboarding_provider.dart';
import 'package:multiparking_tower/repositories/auth_repository.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';

enum AuthStatus { unknown, unauthenticated, authenticated, loading, error }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.session,
    this.phone,
    this.errorMessage,
    this.otpSent = false,
  });

  final AuthStatus status;
  final UserModel? user;
  final AuthSession? session;
  final String? phone;
  final String? errorMessage;
  final bool otpSent;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    AuthSession? session,
    String? phone,
    String? errorMessage,
    bool? otpSent,
    bool clearUser = false,
    bool clearSession = false,
    bool clearPhone = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      session: clearSession ? null : (session ?? this.session),
      phone: clearPhone ? null : (phone ?? this.phone),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      otpSent: otpSent ?? this.otpSent,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref, this._repository) : super(const AuthState());

  final Ref _ref;
  final AuthRepository _repository;

  Future<void> restoreSession() async {
    if (state.status == AuthStatus.loading) return;
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final secureStorage = _ref.read(secureStorageProvider);
      final hasSession = await secureStorage.hasSession();
      if (!hasSession) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      final user = await _repository.getCurrentUser();
      if (user == null) {
        await secureStorage.clearTokens();
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      final accessToken = await secureStorage.getAccessToken() ?? '';
      final refreshToken = await secureStorage.getRefreshToken() ?? '';
      final session = AuthSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
        isNewUser: false,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        session: session,
        phone: user.phone,
      );
    } catch (error, stackTrace) {
      _ref.read(loggerProvider).e(
            'Failed to restore authentication session',
            error: error,
            stackTrace: stackTrace,
          );
      await _ref.read(secureStorageProvider).clearTokens();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> sendOtp(String phone) async {
    // Keep the user on login/OTP while sending — do not use a status that
    // the router treats as "session restoring".
    state = state.copyWith(
      status: AuthStatus.loading,
      phone: phone,
      otpSent: false,
      clearError: true,
    );
    try {
      await _repository.sendOtp(phone);
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        phone: phone,
        otpSent: true,
        clearError: true,
      );
      return true;
    } catch (error, stackTrace) {
      _handleError('Unable to send OTP', error, stackTrace);
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    final phone = state.phone;
    if (phone == null || phone.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please enter your phone number again.',
      );
      return false;
    }

    // Preserve phone while verifying; avoid clearing auth route eligibility.
    final previous = state;
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final session = await _repository.verifyOtp(phone, otp);
      return await _persistSession(session, phone: phone);
    } catch (error, stackTrace) {
      _handleError('Unable to verify OTP', error, stackTrace);
      // Restore phone so the user can retry without returning to login.
      if (state.phone == null) {
        state = state.copyWith(phone: previous.phone);
      }
      return false;
    }
  }

  Future<bool> staffLogin(String username, String password) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final session = await _repository.staffLogin(username, password);
      return await _persistSession(session);
    } catch (error, stackTrace) {
      _handleError('Unable to sign in', error, stackTrace);
      return false;
    }
  }

  Future<bool> _persistSession(AuthSession session, {String? phone}) async {
    try {
      await _ref.read(secureStorageProvider).saveTokens(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            userId: session.user.id,
          );
    } catch (storageError, storageStack) {
      // Web/desktop may lack secure storage; session still works in-memory.
      _ref.read(loggerProvider).w(
            'Secure token persist skipped',
            error: storageError,
            stackTrace: storageStack,
          );
    }
    state = AuthState(
      status: AuthStatus.authenticated,
      user: session.user,
      session: session,
      phone: phone ?? session.user.phone,
      otpSent: phone != null,
    );
    return true;
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _repository.logout();
    } catch (error, stackTrace) {
      _ref.read(loggerProvider).w(
            'Remote logout failed; clearing local session',
            error: error,
            stackTrace: stackTrace,
          );
    } finally {
      await _ref.read(secureStorageProvider).clearTokens();
      // Force vehicle re-confirmation after the next sign-in.
      _ref.read(vehicleSessionConfirmedProvider.notifier).state = false;
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  void _handleError(
    String fallback,
    Object error,
    StackTrace stackTrace,
  ) {
    _ref.read(loggerProvider).e(
          fallback,
          error: error,
          stackTrace: stackTrace,
        );
    state = state.copyWith(
      status: AuthStatus.error,
      errorMessage: error is AppException ? error.message : fallback,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(ref, ref.watch(authRepositoryProvider));
  Future<void>.microtask(notifier.restoreSession);
  return notifier;
});
