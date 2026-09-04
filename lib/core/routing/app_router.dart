import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/households/presentation/screens/create_household_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/members/presentation/screens/household_members_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthChangeNotifier();
  ref.listen(authControllerProvider, (previous, next) => refreshNotifier.notify());

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      if (authState.status == AuthStatus.unknown) {
        return location == '/splash' ? null : '/splash';
      }

      final loggedOutRoutes = {'/login', '/register'};

      if (authState.status == AuthStatus.unauthenticated) {
        return loggedOutRoutes.contains(location) ? null : '/login';
      }

      // Authenticated from here on.
      if (!authState.hasHousehold) {
        return location == '/create-household' ? null : '/create-household';
      }

      final shouldLeaveAuthRoutes = location == '/splash' ||
          loggedOutRoutes.contains(location) ||
          location == '/create-household';

      return shouldLeaveAuthRoutes ? '/home' : null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/create-household',
        builder: (context, state) => const CreateHouseholdScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/home/members',
        builder: (context, state) => HouseholdMembersScreen(
          householdId: state.extra as int,
        ),
      ),
    ],
  );
});

/// Bridges Riverpod state changes to GoRouter's [Listenable]-based refresh.
class _AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
