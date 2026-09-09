import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/households/presentation/screens/create_household_screen.dart';
import '../../features/households/presentation/screens/join_household_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/members/presentation/screens/activate_member_screen.dart';
import '../../features/members/presentation/screens/family_screen.dart';
import '../../features/members/presentation/screens/invite_member_screen.dart';
import '../../shared/screens/coming_soon_screen.dart';
import 'app_shell.dart';
import 'deep_link_listener.dart';

/// The most recent unhandled `tayo://invite/<token>` or
/// `tayo://activate/<token>` link, set by [deepLinkListenerProvider]. The
/// router redirects to it regardless of auth state; the screen that handles
/// it clears this back to null once done.
final pendingDeepLinkProvider = StateProvider<Uri?>((ref) => null);

final routerProvider = Provider<GoRouter>((ref) {
  ref.watch(deepLinkListenerProvider);

  final refreshNotifier = _AuthChangeNotifier();
  ref.listen(authControllerProvider, (previous, next) => refreshNotifier.notify());
  ref.listen(pendingDeepLinkProvider, (previous, next) => refreshNotifier.notify());

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      // /invite/:token and /activate/:token are always reachable directly —
      // a URL typed into a browser, or a native tayo:// tap — regardless of
      // auth state. Routing them through the auth-state gates below (which
      // bounce to /splash, /welcome, or /create-household) would discard
      // the token before the screen ever gets to resolve it. The screens
      // resolve auth themselves (calling checkAuthStatus() if needed) and
      // navigate away explicitly (e.g. to /home) once the invite is
      // accepted or the account claimed.
      if (location.startsWith('/invite/') || location.startsWith('/activate/')) {
        return null;
      }

      if (authState.status == AuthStatus.unknown) {
        return location == '/splash' ? null : '/splash';
      }

      final pendingLink = ref.read(pendingDeepLinkProvider);
      if (pendingLink != null && pendingLink.pathSegments.isNotEmpty) {
        final token = pendingLink.pathSegments.first;
        final target = pendingLink.host == 'activate' ? '/activate/$token' : '/invite/$token';
        if (location != target) return target;
      }

      final loggedOutRoutes = {'/welcome', '/login'};

      if (authState.status == AuthStatus.unauthenticated) {
        return loggedOutRoutes.contains(location) ? null : '/welcome';
      }

      // Authenticated from here on.
      if (!authState.hasHousehold) {
        final onboardingRoutes = {'/create-household', '/invite-members'};
        return onboardingRoutes.contains(location) ? null : '/create-household';
      }

      final shouldLeaveAuthRoutes = location == '/splash' ||
          loggedOutRoutes.contains(location) ||
          location == '/create-household';

      return shouldLeaveAuthRoutes ? '/home' : null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/create-household',
        builder: (context, state) => const CreateHouseholdScreen(),
      ),
      GoRoute(
        path: '/invite-members',
        builder: (context, state) => InviteMemberScreen(
          preview: state.extra as HouseholdVisualPreview?,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Calendar',
                icon: Icons.calendar_month_rounded,
                message: 'Shared household scheduling is on its way.',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/meals',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Meals',
                icon: Icons.restaurant_rounded,
                message: 'Weekly meal planning is on its way.',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/groceries',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Groceries',
                icon: Icons.shopping_basket_rounded,
                message: 'A shared grocery list is on its way.',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/family', builder: (context, state) => const FamilyScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (context, state) =>
            JoinHouseholdScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/activate/:token',
        builder: (context, state) =>
            ActivateMemberScreen(token: state.pathParameters['token']!),
      ),
    ],
  );
});

/// Bridges Riverpod state changes to GoRouter's [Listenable]-based refresh.
class _AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
