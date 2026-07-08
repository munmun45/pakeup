import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/kyc_models.dart';

class KycRepository {
  KycRepository(this._client);

  final SupabaseClient _client;
  static const _bucket = 'partner-kyc';

  Future<StoreKycRecord?> getStoreKyc({
    required String accountId,
    required String loginPass,
    required String storeId,
  }) async {
    final result = await _client.rpc<dynamic>(
      'get_partner_store_kyc',
      params: {
        'p_account_id': accountId,
        'p_login_pass': loginPass,
        'p_store_id': storeId,
      },
    );
    if (result == null) return null;
    return StoreKycRecord.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<StoreKycRecord> saveStoreKyc({
    required String accountId,
    required String loginPass,
    required String storeId,
    required StoreKycSubmitData data,
    bool markSubmitted = true,
  }) async {
    final result = await _client.rpc<dynamic>(
      'upsert_partner_store_kyc',
      params: {
        'p_account_id': accountId,
        'p_login_pass': loginPass,
        'p_store_id': storeId,
        ...data.toRpcParams(markSubmitted: markSubmitted),
      },
    );
    return StoreKycRecord.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<String> uploadDocument({
    required String storeId,
    required KycDocType docType,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('File not found');
    }

    final ext = _extension(localPath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$storeId/${docType.key}_$timestamp$ext';
    final bytes = await file.readAsBytes();

    await _client.storage.from(_bucket).uploadBinary(
          storagePath,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: _mimeType(ext),
            upsert: true,
          ),
        );

    return _client.storage.from(_bucket).getPublicUrl(storagePath);
  }

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) return '.jpg';
    return path.substring(dot).toLowerCase();
  }

  String _mimeType(String ext) => switch (ext) {
        '.pdf' => 'application/pdf',
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        _ => 'image/jpeg',
      };
}
