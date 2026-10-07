import '../../../core/networking/api_client.dart';
import '../domain/notification_preference.dart';
import '../domain/reminder.dart';

class ReminderRepository {
  ReminderRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Reminder>> list({required int householdId}) async {
    final response = await _apiClient.get('/households/$householdId/reminders');
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data.map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<NotificationPreference>> getPreferences() async {
    final response = await _apiClient.get('/auth/notification-preferences');
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data.map((e) => NotificationPreference.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<NotificationPreference>> updatePreference({
    required String category,
    required bool enabled,
  }) async {
    final response = await _apiClient.patch(
      '/auth/notification-preferences',
      data: {'category': category, 'enabled': enabled},
    );
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data.map((e) => NotificationPreference.fromJson(e as Map<String, dynamic>)).toList();
  }
}
