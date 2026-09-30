import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/providers.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../data/permission_request_repository.dart';
import '../../domain/permission_request.dart';

final permissionRequestRepositoryProvider = Provider<PermissionRequestRepository>((ref) {
  return PermissionRequestRepository(ref.watch(apiClientProvider));
});

/// Every request in the current household, newest first — powers the full
/// Requests list screen (with client-side status filtering via chips) and
/// Home's "Needs Your Attention" section / header bell badge, both of
/// which need more than just pending ones (a resolved request the viewer
/// hasn't acknowledged yet is also attention-worthy — see
/// PermissionRequest.needsRequesterAttention).
final currentHouseholdRequestsProvider = FutureProvider<List<PermissionRequest>>((ref) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];

  return ref.read(permissionRequestRepositoryProvider).list(householdId: household.id);
});
