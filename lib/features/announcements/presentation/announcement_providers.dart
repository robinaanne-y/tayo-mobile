import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/providers.dart';
import '../../households/presentation/providers/household_providers.dart';
import '../data/announcement_repository.dart';
import '../domain/announcement.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository(ref.watch(apiClientProvider));
});

/// Announcements for [currentHouseholdProvider]. Re-fetches automatically
/// when the active household changes.
final currentHouseholdAnnouncementsProvider =
    FutureProvider<List<Announcement>>((ref) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];
  return ref.read(announcementRepositoryProvider).forHousehold(household.id);
});
