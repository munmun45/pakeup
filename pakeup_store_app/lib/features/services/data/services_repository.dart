import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_models.dart';

class AddServiceData {
  const AddServiceData({
    required this.name,
    this.description,
    this.category = 'Others',
    this.serviceImageUrl,
    this.primaryImageUrl,
    this.images = const [],
  });

  final String name;
  final String? description;
  final String category;
  final String? serviceImageUrl;
  final String? primaryImageUrl;
  final List<String> images;

  Map<String, dynamic> toParams({
    required String accountId,
    required String loginPass,
    required String storeId,
  }) =>
      {
        'p_account_id': accountId,
        'p_login_pass': loginPass,
        'p_store_id': storeId,
        'p_service_name': name,
        'p_description': description,
        'p_category': category,
        'p_service_image': serviceImageUrl ?? primaryImageUrl,
        'p_primary_image': primaryImageUrl ?? serviceImageUrl,
        'p_images': images,
      };
}

class UpdateServiceData {
  const UpdateServiceData({
    required this.name,
    this.description,
    this.category = 'Others',
    this.serviceImageUrl,
    this.primaryImageUrl,
    this.images = const [],
  });

  final String name;
  final String? description;
  final String category;
  final String? serviceImageUrl;
  final String? primaryImageUrl;
  final List<String> images;

  Map<String, dynamic> toParams({
    required String accountId,
    required String loginPass,
    required String storeId,
    required String serviceId,
  }) =>
      {
        'p_account_id': accountId,
        'p_login_pass': loginPass,
        'p_store_id': storeId,
        'p_service_id': serviceId,
        'p_service_name': name,
        'p_description': description,
        'p_category': category,
        'p_service_image': serviceImageUrl ?? primaryImageUrl,
        'p_primary_image': primaryImageUrl ?? serviceImageUrl,
        'p_images': images,
      };
}

class ServicesRepository {
  ServicesRepository(this._client);

  final SupabaseClient _client;

  Future<List<ServiceRecord>> getMyServices({
    required String accountId,
    required String loginPass,
  }) async {
    final result = await _client.rpc<dynamic>(
      'list_partner_store_services',
      params: {
        'p_account_id': accountId,
        'p_login_pass': loginPass,
      },
    );
    if (result == null) return const [];
    return (result as List<dynamic>)
        .map((e) => ServiceRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ServiceRecord>> getStoreServices({
    required String accountId,
    required String loginPass,
    required String storeId,
  }) async {
    final result = await _client.rpc<dynamic>(
      'list_partner_store_services',
      params: {
        'p_account_id': accountId,
        'p_login_pass': loginPass,
        'p_store_id': storeId,
      },
    );
    if (result == null) return const [];
    return (result as List<dynamic>)
        .map((e) => ServiceRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ServiceRecord> createService({
    required String accountId,
    required String loginPass,
    required String storeId,
    required AddServiceData data,
  }) async {
    final result = await _client.rpc<dynamic>(
      'create_partner_store_service',
      params: data.toParams(
        accountId: accountId,
        loginPass: loginPass,
        storeId: storeId,
      ),
    );
    return ServiceRecord.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<ServiceRecord> toggleServiceActive({
    required String accountId,
    required String loginPass,
    required String storeId,
    required String serviceId,
    required bool active,
  }) async {
    final result = await _client.rpc<dynamic>(
      'toggle_partner_store_service_active',
      params: {
        'p_account_id': accountId,
        'p_login_pass': loginPass,
        'p_store_id': storeId,
        'p_service_id': serviceId,
        'p_active': active,
      },
    );
    return ServiceRecord.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<ServiceRecord> updateService({
    required String accountId,
    required String loginPass,
    required String storeId,
    required String serviceId,
    required UpdateServiceData data,
  }) async {
    final result = await _client.rpc<dynamic>(
      'update_partner_store_service',
      params: data.toParams(
        accountId: accountId,
        loginPass: loginPass,
        storeId: storeId,
        serviceId: serviceId,
      ),
    );
    return ServiceRecord.fromJson(Map<String, dynamic>.from(result as Map));
  }
}
