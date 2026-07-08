import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/store_models.dart';
import '../models/store_schedule_models.dart';

class StoresRepository {
  StoresRepository(this._client);

  final SupabaseClient _client;
  static const _rpcTimeout = Duration(seconds: 20);

  Future<List<StoreRecord>> getMyStores({
    required String accountId,
    required String loginPass,
  }) async {
    final dynamic result;
    try {
      result = await _client
          .rpc<dynamic>(
            'list_partner_stores',
            params: {
              'p_account_id': accountId,
              'p_login_pass': loginPass,
            },
          )
          .timeout(_rpcTimeout);
    } on TimeoutException {
      throw StateError('Request timed out. Please check internet and retry.');
    }

    if (result == null) return const [];

    return (result as List<dynamic>)
        .map((e) => StoreRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<StoreRecord> getStore({
    required String accountId,
    required String loginPass,
    required String storeId,
  }) async {
    final dynamic result;
    try {
      result = await _client
          .rpc<dynamic>(
            'get_partner_store',
            params: {
              'p_account_id': accountId,
              'p_login_pass': loginPass,
              'p_store_id': storeId,
            },
          )
          .timeout(_rpcTimeout);
    } on TimeoutException {
      throw StateError('Request timed out. Please check internet and retry.');
    }

    return StoreRecord.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<StoreRecord> addStore({
    required String accountId,
    required String loginPass,
    required String ownerName,
    required AddStoreData data,
  }) async {
    final inserted = await _client.rpc<dynamic>(
      'create_partner_store',
      params: {
        'p_account_id': accountId,
        'p_login_pass': loginPass,
        'p_business_name': data.businessName,
        'p_owner_name': ownerName,
        'p_phone': data.phone,
        'p_whatsapp': data.whatsapp,
        'p_email': data.email,
        'p_description': data.description,
        'p_address_line': data.address,
        'p_city': data.city,
        'p_state': data.state,
        'p_pincode': data.pincode,
        'p_latitude': data.latitude,
        'p_longitude': data.longitude,
        'p_category': data.category,
        'p_schedules': schedulesToRpc(data.schedules),
      },
    );

    return StoreRecord.fromJson(Map<String, dynamic>.from(inserted as Map));
  }

  Future<StoreRecord> updateStore({
    required String accountId,
    required String loginPass,
    required String storeId,
    required AddStoreData data,
  }) async {
    final updated = await _client.rpc<dynamic>(
      'update_partner_store',
      params: {
        'p_account_id': accountId,
        'p_login_pass': loginPass,
        'p_store_id': storeId,
        'p_business_name': data.businessName,
        'p_phone': data.phone,
        'p_whatsapp': data.whatsapp,
        'p_email': data.email,
        'p_description': data.description,
        'p_address_line': data.address,
        'p_city': data.city,
        'p_state': data.state,
        'p_pincode': data.pincode,
        'p_latitude': data.latitude,
        'p_longitude': data.longitude,
        'p_category': data.category,
        'p_schedules': schedulesToRpc(data.schedules),
      },
    );

    return StoreRecord.fromJson(Map<String, dynamic>.from(updated as Map));
  }

  Future<StoreRecord> setStoreActive({
    required String accountId,
    required String loginPass,
    required String storeId,
    required bool active,
  }) async {
    final updated = await _client.rpc<dynamic>(
      'set_partner_store_active',
      params: {
        'p_account_id': accountId,
        'p_login_pass': loginPass,
        'p_store_id': storeId,
        'p_active': active,
      },
    );

    return StoreRecord.fromJson(Map<String, dynamic>.from(updated as Map));
  }

  Future<String> uploadStoreImage({
    required String storeId,
    required List<int> bytes,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$storeId/image_$timestamp.jpg';

    await _client.storage.from('partner-images').uploadBinary(
          storagePath,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    return _client.storage.from('partner-images').getPublicUrl(storagePath);
  }

  Future<void> updateStoreImages({
    required String accountId,
    required String loginPass,
    required String storeId,
    required List<String> images,
    required String? primaryImage,
  }) async {
    await _client.rpc<dynamic>(
      'update_partner_store_images',
      params: {
        'p_account_id': accountId,
        'p_login_pass': loginPass,
        'p_store_id': storeId,
        'p_images': images,
        'p_primary_image': primaryImage,
      },
    );
  }

  Future<void> uploadKycDocument({
    required String partnerId,
    required String docType,
    required String fileUrl,
  }) async {
    await _client.rpc<dynamic>(
      'upload_kyc_document',
      params: {
        'partner_id': partnerId,
        'doc_type': docType,
        'file_url': fileUrl,
      },
    );
  }

  Future<void> saveBankDetails({
    required String accountId,
    required String loginPass,
    required String accountName,
    required String accountNumber,
    required String ifsc,
    required String bankName,
    String? accountType,
    String? upiId,
  }) async {
    final params = {
      'partner_id': accountId,
      'p_login_pass': loginPass,
      'account_name': accountName,
      'account_number': accountNumber,
      'ifsc': ifsc,
      'bank_name': bankName,
      'account_type': accountType ?? 'savings',
      'upi_id': upiId,
    };

    await _saveBankExtras(
      accountId: accountId,
      loginPass: loginPass,
      accountType: accountType,
      upiId: upiId,
    );

    try {
      await _client.rpc<dynamic>(
        'save_partner_bank_details',
        params: params,
      );
    } catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      await _client.rpc<dynamic>(
        'save_partner_store_bank_legacy',
        params: params,
      );
    }

    await _saveBankExtras(
      accountId: accountId,
      loginPass: loginPass,
      accountType: accountType,
      upiId: upiId,
    );
  }

  Future<void> _saveBankExtras({
    required String accountId,
    required String loginPass,
    String? accountType,
    String? upiId,
  }) async {
    Object? lastError;

    for (final rpc in ['patch_partner_bank_extras', 'save_partner_bank_meta']) {
      try {
        await _client.rpc<dynamic>(
          rpc,
          params: {
            'partner_id': accountId,
            'p_login_pass': loginPass,
            'account_type': accountType ?? 'savings',
            'upi_id': upiId,
          },
        );
        return;
      } catch (e) {
        if (!_isMissingRpc(e)) {
          lastError = e;
        }
      }
    }

    if (lastError != null) throw lastError;
  }

  Future<Map<String, dynamic>?> getBankDetails({
    required String accountId,
    required String loginPass,
  }) async {
    try {
      final result = await _client.rpc<dynamic>(
        'get_partner_bank_details',
        params: {
          'p_account_id': accountId,
          'p_login_pass': loginPass,
        },
      );
      if (result == null) return null;
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      final result = await _client.rpc<dynamic>(
        'get_partner_store_bank_legacy',
        params: {
          'p_account_id': accountId,
          'p_login_pass': loginPass,
        },
      );
      if (result == null) return null;
      return Map<String, dynamic>.from(result as Map);
    }
  }

  bool _isMissingRpc(Object error) {
    if (error is! PostgrestException) return false;
    final message = error.message.toLowerCase();
    return error.code == 'PGRST202' ||
        message.contains('could not find the function') ||
        message.contains('schema cache');
  }
}
