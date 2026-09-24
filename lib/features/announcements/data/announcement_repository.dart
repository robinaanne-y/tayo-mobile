import '../../../core/networking/api_client.dart';
import '../domain/announcement.dart';

class AnnouncementRepository {
  AnnouncementRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Announcement>> forHousehold(int householdId) async {
    final response = await _apiClient.get('/households/$householdId/announcements');
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data
        .map((a) => Announcement.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<Announcement> create({required int householdId, required String content}) async {
    final response = await _apiClient.post(
      '/households/$householdId/announcements',
      data: {'content': content},
    );
    return Announcement.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> delete({required int householdId, required int announcementId}) async {
    await _apiClient.delete('/households/$householdId/announcements/$announcementId');
  }
}
