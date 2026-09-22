import '../../../core/networking/api_client.dart';
import '../domain/household.dart';

class HouseholdRepository {
  HouseholdRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Household>> myHouseholds() async {
    final response = await _apiClient.get('/households');
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data
        .map((h) => Household.fromJson(h as Map<String, dynamic>))
        .toList();
  }

  Future<Household> create(String name, {String? color, String? emoji}) async {
    final response = await _apiClient.post('/households', data: {
      'name': name,
      if (color != null) 'color': color,
      if (emoji != null) 'emoji': emoji,
    });
    return Household.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<Household> show(int householdId) async {
    final response = await _apiClient.get('/households/$householdId');
    return Household.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<Household> update({
    required int householdId,
    String? name,
    String? color,
    String? emoji,
  }) async {
    final response = await _apiClient.patch('/households/$householdId', data: {
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (emoji != null) 'emoji': emoji,
    });
    return Household.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }
}
