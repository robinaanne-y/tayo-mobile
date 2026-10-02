import '../../../core/networking/api_client.dart';
import '../domain/grocery_item.dart';

class GroceryItemRepository {
  GroceryItemRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<GroceryItem>> list({required int householdId, bool? purchased}) async {
    final response = await _apiClient.get(
      '/households/$householdId/grocery-items',
      queryParameters: purchased != null ? {'purchased': purchased ? '1' : '0'} : null,
    );
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data.map((e) => GroceryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<GroceryItem> create({
    required int householdId,
    required String name,
    String? quantity,
    String? unit,
    String? category,
  }) async {
    final response = await _apiClient.post(
      '/households/$householdId/grocery-items',
      data: {'name': name, 'quantity': quantity, 'unit': unit, 'category': category},
    );
    return GroceryItem.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<GroceryItem> update({
    required int householdId,
    required int itemId,
    required String name,
    String? quantity,
    String? unit,
    String? category,
  }) async {
    final response = await _apiClient.put(
      '/households/$householdId/grocery-items/$itemId',
      data: {'name': name, 'quantity': quantity, 'unit': unit, 'category': category},
    );
    return GroceryItem.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<GroceryItem> purchase({required int householdId, required int itemId}) async {
    final response = await _apiClient.post('/households/$householdId/grocery-items/$itemId/purchase');
    return GroceryItem.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<GroceryItem> unpurchase({required int householdId, required int itemId}) async {
    final response = await _apiClient.post('/households/$householdId/grocery-items/$itemId/unpurchase');
    return GroceryItem.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> delete({required int householdId, required int itemId}) async {
    await _apiClient.delete('/households/$householdId/grocery-items/$itemId');
  }

  Future<void> clearPurchased({required int householdId}) async {
    await _apiClient.post('/households/$householdId/grocery-items/clear-purchased');
  }
}
