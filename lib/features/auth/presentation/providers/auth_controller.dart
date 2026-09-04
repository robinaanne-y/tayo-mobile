import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/networking/providers.dart';
import '../../data/auth_repository.dart';
import '../../domain/app_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.user});

  final AuthStatus status;
  final AppUser? user;

  bool get hasHousehold => (user?.households.isNotEmpty ?? false);

  AuthState copyWith({AuthStatus? status, AppUser? user}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureTokenStorageProvider),
  );
});

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Centralize 401 handling: any API call that comes back unauthorized
    // drops the session, regardless of which screen triggered it.
    ref.read(apiClientProvider).onUnauthorized = () {
      state = const AuthState(status: AuthStatus.unauthenticated);
    };
    return const AuthState();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> checkAuthStatus() async {
    final token = await ref.read(secureTokenStorageProvider).readToken();
    if (token == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final user = await _repo.me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on ApiException {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final user = await _repo.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> login({required String email, required String password}) async {
    final user = await _repo.login(email: email, password: password);
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Re-fetches the current user, e.g. after creating a household so the
  /// router picks up the new membership.
  Future<void> refreshUser() async {
    final user = await _repo.me();
    state = state.copyWith(status: AuthStatus.authenticated, user: user);
  }
}
