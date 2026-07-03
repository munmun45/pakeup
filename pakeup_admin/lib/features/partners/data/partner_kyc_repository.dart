import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/partner_kyc_models.dart';

class PartnerKycRepository {
  PartnerKycRepository(this._client);

  final SupabaseClient _client;
  static const _bucket = 'partner-kyc';

  Future<PartnerKycRecord?> getKyc({
    required String callerId,
    required String partnerId,
  }) async {
    final result = await _client.rpc<dynamic>(
      'get_partner_kyc',
      params: {
        'caller_id': callerId,
        'partner_id': partnerId,
      },
    );
    if (result == null) return null;
    return PartnerKycRecord.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<PartnerKycRecord> saveKyc({
    required String callerId,
    required String partnerId,
    required PartnerKycFormData data,
    bool markSubmitted = true,
  }) async {
    final result = await _client.rpc<dynamic>(
      'upsert_partner_kyc',
      params: {
        'caller_id': callerId,
        'partner_id': partnerId,
        ...data.toRpcParams(markSubmitted: markSubmitted),
      },
    );
    return PartnerKycRecord.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<String> uploadDocument({
    required String partnerId,
    required KycDocType docType,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('File not found');
    }

    final ext = _extension(localPath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$partnerId/${docType.key}_$timestamp$ext';
    final bytes = await file.readAsBytes();

    await _client.storage.from(_bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: _mimeType(ext),
            upsert: true,
          ),
        );

    return _client.storage.from(_bucket).getPublicUrl(storagePath);
  }

  Future<List<PartnerAccountRecord>> listAccounts(String callerId) async {
    final result = await _client.rpc<dynamic>(
      'list_partner_accounts',
      params: {'caller_id': callerId},
    );
    if (result == null) return [];
    final list = result as List<dynamic>;
    return list
        .map(
          (e) => PartnerAccountRecord.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> setAccountStatus({
    required String callerId,
    required String partnerId,
    required String status,
  }) async {
    await _client.rpc(
      'set_partner_account_status',
      params: {
        'caller_id': callerId,
        'partner_id': partnerId,
        'new_status': status,
      },
    );
  }

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) return '';
    return path.substring(dot).toLowerCase();
  }

  String _mimeType(String ext) {
    return switch (ext) {
      '.pdf' => 'application/pdf',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
