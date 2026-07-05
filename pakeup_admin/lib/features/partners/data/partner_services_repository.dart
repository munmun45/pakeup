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
    // Resize image to width 600, maintaining aspect ratio
    final resized = img.copyResize(decoded, width: 600);
    // Compress to JPEG with 82% quality to target 20-40KB
    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  }
}
