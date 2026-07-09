import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
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

    final list = result is List<dynamic> ? result : const <dynamic>[];
    final services = list
        .map(
          (e) => PartnerServiceRecord.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    try {
      final enrichResults = await Future.wait<dynamic>([
        _client.rpc<dynamic>(
          'list_partners',
          params: {'caller_id': callerId},
        ),
        _client.rpc<dynamic>(
          'list_partner_accounts',
          params: {'caller_id': callerId},
        ),
      ]);

      final partners = enrichResults[0] is List<dynamic>
          ? (enrichResults[0] as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : const <Map<String, dynamic>>[];
      final accounts = enrichResults[1] is List<dynamic>
          ? (enrichResults[1] as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : const <Map<String, dynamic>>[];

      final profileByAccountId = <String, String>{
        for (final account in accounts)
          if (account['id'] is String &&
              (account['profile_id'] as String?)?.trim().isNotEmpty == true)
            account['id'] as String: (account['profile_id'] as String).trim(),
      };

      final profileByPartnerId = <String, String>{};
      for (final partner in partners) {
        final partnerId = partner['id'] as String?;
        if (partnerId == null) continue;

        final direct = (partner['profile_id'] as String?)?.trim();
        if (direct != null && direct.isNotEmpty) {
          profileByPartnerId[partnerId] = direct;
          continue;
        }

        final accountId = partner['account_id'] as String?;
        if (accountId == null) continue;

        final profileId = profileByAccountId[accountId];
        if (profileId != null) {
          profileByPartnerId[partnerId] = profileId;
        }
      }

      return services.map((service) {
        final existing = service.profileId?.trim();
        if (existing != null && existing.isNotEmpty) return service;

        final profileId = profileByPartnerId[service.partnerId];
        if (profileId == null) return service;

        return service.copyWith(profileId: profileId);
      }).toList();
    } catch (_) {
      return services;
    }
  }

  Future<PartnerServiceRecord> createService({
    required String callerId,
    required PartnerServiceFormData data,
  }) async {
    final result = await _client.rpc(
      'create_partner_service',
      params: {'caller_id': callerId, ...data.toCreateParams()},
    );
    return PartnerServiceRecord.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<PartnerServiceRecord> updateService({
    required String callerId,
    required String serviceId,
    required PartnerServiceFormData data,
  }) async {
    final result = await _client.rpc(
      'update_partner_service',
      params: {
        'caller_id': callerId,
        ...data.toUpdateParams(serviceId),
      },
    );
    return PartnerServiceRecord.fromJson(
      Map<String, dynamic>.from(result as Map),
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

  Future<void> updateServiceImages({
    required String callerId,
    required String serviceId,
    required List<String> images,
    required String? primaryImage,
  }) async {
    await _client.rpc(
      'update_partner_service_images',
      params: {
        'caller_id': callerId,
        'service_id': serviceId,
        'images': images,
        'primary_image': primaryImage,
      },
    );
  }

  Future<String> uploadServiceImage({
    required String partnerId,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('File not found');
    }

    // Optimize image bytes first to target 20-40KB
    final bytes = await _optimizeImage(file);

    // Save as .jpg for compressed images under services/ directory
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'services/$partnerId/image_$timestamp.jpg';

    await _client.storage.from('partner-images').uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    return _client.storage.from('partner-images').getPublicUrl(storagePath);
  }

  Future<Uint8List> _optimizeImage(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return bytes;
    }

    // Resize image if it exceeds 800px in either dimension
    img.Image resized = decoded;
    const maxDimension = 800;
    if (decoded.width > maxDimension || decoded.height > maxDimension) {
      if (decoded.width > decoded.height) {
        resized = img.copyResize(decoded, width: maxDimension);
      } else {
        resized = img.copyResize(decoded, height: maxDimension);
      }
    }

    // Compress iteratively to target 20KB - 40KB in JPEG format
    int quality = 75;
    List<int> compressed = img.encodeJpg(resized, quality: quality);
    
    while (compressed.length > 45 * 1024 && quality > 15) {
      quality -= 10;
      compressed = img.encodeJpg(resized, quality: quality);
    }
    
    return Uint8List.fromList(compressed);
  }
}
