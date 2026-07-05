import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.slug,
    required this.name,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
  });

  final String id;
  final String slug;
  final String name;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class ServiceCategoriesRepository {
  ServiceCategoriesRepository(this._client);

  final SupabaseClient _client;

  List<T> _parseList<T>(
    dynamic result,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (result == null) return [];
    final list = result as List<dynamic>;
    return list
        .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ServiceCategory>> listCategories(String callerId) async {
    final result = await _client.rpc<dynamic>(
      'list_service_categories',
      params: {'caller_id': callerId},
    );
    return _parseList(result, ServiceCategory.fromJson);
  }

  Future<void> createCategory({
    required String callerId,
    required String name,
    String? slug,
  }) async {
    await _client.rpc(
      'create_service_category',
      params: {
        'caller_id': callerId,
        'cat_name': name,
        'cat_slug': slug,
      },
    );
  }

  Future<void> updateCategory({
    required String callerId,
    required String categoryId,
    required String name,
    String? slug,
  }) async {
    await _client.rpc(
      'update_service_category',
      params: {
        'caller_id': callerId,
        'category_id': categoryId,
        'cat_name': name,
        'cat_slug': slug,
      },
    );
  }

  Future<void> deleteCategory({
    required String callerId,
    required String categoryId,
  }) async {
    await _client.rpc(
      'delete_service_category',
      params: {
        'caller_id': callerId,
        'category_id': categoryId,
      },
    );
  }

  Future<void> setCategoryActive({
    required String callerId,
    required String categoryId,
    required bool active,
  }) async {
    await _client.rpc(
      'set_service_category_active',
      params: {
        'caller_id': callerId,
        'category_id': categoryId,
        'active': active,
      },
    );
  }
}
