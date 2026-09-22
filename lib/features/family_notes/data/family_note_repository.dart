import '../../../core/networking/api_client.dart';
import '../domain/family_note.dart';

class FamilyNoteRepository {
  FamilyNoteRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<FamilyNote>> forHousehold(int householdId) async {
    final response = await _apiClient.get('/households/$householdId/notes');
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data
        .map((n) => FamilyNote.fromJson(n as Map<String, dynamic>))
        .toList();
  }

  Future<FamilyNote> create({required int householdId, required String content}) async {
    final response = await _apiClient.post(
      '/households/$householdId/notes',
      data: {'content': content},
    );
    return FamilyNote.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> delete({required int householdId, required int noteId}) async {
    await _apiClient.delete('/households/$householdId/notes/$noteId');
  }
}
