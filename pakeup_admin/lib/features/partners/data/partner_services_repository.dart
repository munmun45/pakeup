import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/partner_service_models.dart';

class PartnerServicesRepository {
  PartnerServicesRepository(this._client);

  final SupabaseClient _client;

  Future<List<PartnerServiceRecord>> listServices(String callerId) async {
    final result = await _client.rpc<dynamic>(
      'list_partner_services',
      params: {'caller_id': callerId},
    );
    if (result == null) return [];
    return (result as List<dynamic>)
        .map(
          (e) => PartnerServiceRecord.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> createService({
    required String callerId,
    required PartnerServiceFormData data,
  }) async {
    await _client.rpc(
      'create_partner_service',
      params: {'caller_id': callerId, ...data.toCreateParams()},
    );
  }

  Future<void> updateService({
    required String callerId,
    required String serviceId,
    required PartnerServiceFormData data,
  }) async {
    await _client.rpc(
      'update_partner_service',
      params: {
        'caller_id': callerId,
        ...data.toUpdateParams(serviceId),
      },
    );
  }

  Future<void> deleteService({
    required String callerId,
    required String serviceId,
  }) async {
    await _client.rpc(
      'delete_partner_service',
      params: {
        'caller_id': callerId,
        'service_id': serviceId,
      },
    );
  }
}
