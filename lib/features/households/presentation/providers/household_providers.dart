import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/household_repository.dart';
import '../../data/invitation_repository.dart';
import '../../domain/household.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return HouseholdRepository(ref.watch(apiClientProvider));
});

final invitationRepositoryProvider = Provider<InvitationRepository>((ref) {
  return InvitationRepository(ref.watch(apiClientProvider));
});

/// The household id the user last picked in the switcher. Null means "no
/// explicit pick yet" — [currentHouseholdProvider] then falls back to the
/// first household. Deliberately in-memory only; it resets to that default
/// on a fresh app launch rather than persisting across sessions.
final selectedHouseholdIdProvider = StateProvider<int?>((ref) => null);

/// The household every screen should treat as "active" — the user's
/// switcher pick if it's still one of their households, else the first one.
final currentHouseholdProvider = Provider<Household?>((ref) {
  final households = ref.watch(authControllerProvider).user?.households ?? const [];
  if (households.isEmpty) return null;

  final selectedId = ref.watch(selectedHouseholdIdProvider);
  return households.where((h) => h.id == selectedId).firstOrNull ?? households.first;
});
