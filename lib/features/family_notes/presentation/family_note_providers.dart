import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/providers.dart';
import '../../households/presentation/providers/household_providers.dart';
import '../data/family_note_repository.dart';
import '../domain/family_note.dart';

final familyNoteRepositoryProvider = Provider<FamilyNoteRepository>((ref) {
  return FamilyNoteRepository(ref.watch(apiClientProvider));
});

/// Active (non-expired) family notes for [currentHouseholdProvider].
/// Re-fetches automatically when the active household changes.
final currentHouseholdNotesProvider = FutureProvider<List<FamilyNote>>((ref) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];
  return ref.read(familyNoteRepositoryProvider).forHousehold(household.id);
});
