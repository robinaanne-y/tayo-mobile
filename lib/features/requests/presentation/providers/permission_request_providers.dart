import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/providers.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../data/permission_request_repository.dart';
import '../../domain/permission_request.dart';

final permissionRequestRepositoryProvider = Provider<PermissionRequestRepository>((ref) {
  return PermissionRequestRepository(ref.watch(apiClientProvider));
});

/// Every request in the current household, newest first — powers the full
/// Requests list screen (with client-side status filtering via chips).
final currentHouseholdRequestsProvider = FutureProvider<List<PermissionRequest>>((ref) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];

  return ref.read(permissionRequestRepositoryProvider).list(householdId: household.id);
});

/// Pending requests only — powers Home's "Needs Your Attention" section and
/// the header bell's badge count. Both filter this down further (client-
/// side) to "requests I can act on" using the viewer's role/member id.
final currentHouseholdPendingRequestsProvider = FutureProvider<List<PermissionRequest>>((ref) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];

  return ref
      .read(permissionRequestRepositoryProvider)
      .list(householdId: household.id, status: RequestStatus.pending);
});
