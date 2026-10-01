import '../../../core/networking/api_client.dart';
import '../domain/meal_plan_item.dart';

class MealPlanRepository {
  MealPlanRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<MealPlanItem>> list({
    required int householdId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _apiClient.get(
      '/households/$householdId/meal-plan-items',
      queryParameters: {
        'from': _dateString(from),
        'to': _dateString(to),
      },
    );
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data.map((e) => MealPlanItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Upserts the meal for a given date/slot -- there's no separate update
  /// call, since setting and changing a slot's meal are the same action.
  Future<MealPlanItem> set({
    required int householdId,
    required DateTime date,
    required MealSlot slot,
    required String title,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/meal-plan-items',
      data: {
        'date': _dateString(date),
        'slot': slot.value,
        'title': title,
      },
    );
    return MealPlanItem.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> delete({required int householdId, required int itemId}) async {
    await _apiClient.delete('/households/$householdId/meal-plan-items/$itemId');
  }

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
