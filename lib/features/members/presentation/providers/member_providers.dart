import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/providers.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../data/activation_repository.dart';
import '../../data/member_repository.dart';
import '../../domain/member.dart';

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(ref.watch(apiClientProvider));
});

final activationRepositoryProvider = Provider<ActivationRepository>((ref) {
  return ActivationRepository(ref.watch(apiClientProvider));
});

/// Members of [currentHouseholdProvider]. Re-fetches automatically when the
/// active household changes (e.g. via the household switcher).
final currentHouseholdMembersProvider = FutureProvider<List<Member>>((ref) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];
  return ref.read(memberRepositoryProvider).forHousehold(household.id);
});
