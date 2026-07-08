import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'partner_kyc_repository.dart';
import '../models/partner_schedule_models.dart';

class PartnerRecord {
  const PartnerRecord({
    required this.id,
    this.accountId,
    required this.businessName,
    required this.ownerName,
    this.phone,
    this.email,
    this.whatsapp,
    this.alternatePhone,
    this.city,
    this.state,
    this.pincode,
    this.category = 'salon',
    this.categoryName,
    this.addressLine,
    this.description,
    this.gstNumber,
    this.website,
    this.googleMapEmbed,
    this.latitude,
    this.longitude,
    this.notes,
    this.isActive = true,
    this.kycStatus = 'pending',
    this.loginId,
    this.hasPassword = false,
    this.storeCount = 1,
    this.accountPhone,
    this.accountWhatsapp,
    this.createdAt,
    this.images = const [],
    this.primaryImage,
    this.schedules = const [],
  });

  final String id;
  final String? accountId;
  final String businessName;
  final String ownerName;
  final String? phone;
  final String? email;
  final String? whatsapp;
  final String? alternatePhone;
  final String? city;
  final String? state;
  final String? pincode;
  final String category;
  final String? categoryName;
  final String? addressLine;
  final String? description;
  final String? gstNumber;
  final String? website;
  final String? googleMapEmbed;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final bool isActive;
  final String kycStatus;
  final String? loginId;
  final bool hasPassword;
  final int storeCount;
  final String? accountPhone;
  final String? accountWhatsapp;
  final DateTime? createdAt;
  final List<String> images;
  final String? primaryImage;
  final List<DaySchedule> schedules;

  String get displayCategory => categoryName ?? category;

  factory PartnerRecord.fromJson(Map<String, dynamic> json) {
    return PartnerRecord(
      id: json['id'] as String,
      accountId: json['account_id'] as String?,
      businessName: json['business_name'] as String,
      ownerName: json['owner_name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      whatsapp: json['whatsapp'] as String?,
      alternatePhone: json['alternate_phone'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      category: json['category'] as String? ?? 'salon',
      categoryName: json['category_name'] as String?,
      addressLine: json['address_line'] as String?,
      description: json['description'] as String?,
      gstNumber: json['gst_number'] as String?,
      website: json['website'] as String?,
      googleMapEmbed: json['google_map_embed'] as String?,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      kycStatus: json['kyc_status'] as String? ?? 'pending',
      loginId: json['login_id'] as String?,
      hasPassword: json['has_password'] as bool? ?? false,
      storeCount: json['store_count'] as int? ?? 1,
      accountPhone: json['account_phone'] as String?,
      accountWhatsapp: json['account_whatsapp'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      primaryImage: json['primary_image'] as String?,
      schedules: DaySchedule.parseList(json['schedules']),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class PartnerOwnerAccount {
  const PartnerOwnerAccount({
    required this.id,
    required this.ownerName,
    this.phone,
    this.email,
    this.whatsapp,
    this.alternatePhone,
    this.loginId,
    this.hasPassword = false,
    this.isActive = true,
    this.storeCount = 0,
    this.createdAt,
  });

  final String id;
  final String ownerName;
  final String? phone;
  final String? email;
  final String? whatsapp;
  final String? alternatePhone;
  final String? loginId;
  final bool hasPassword;
  final bool isActive;
  final int storeCount;
  final DateTime? createdAt;

  String get displayLabel {
    final phonePart = phone?.trim().isNotEmpty == true ? phone!.trim() : 'No phone';
    return '$ownerName · $phonePart · $storeCount store(s)';
  }

  factory PartnerOwnerAccount.fromJson(Map<String, dynamic> json) {
    return PartnerOwnerAccount(
      id: json['id'] as String,
      ownerName: json['owner_name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      whatsapp: json['whatsapp'] as String?,
      alternatePhone: json['alternate_phone'] as String?,
      loginId: json['login_id'] as String?,
      hasPassword: json['has_password'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      storeCount: json['store_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class PartnerFormData {
  const PartnerFormData({
    required this.businessName,
    required this.ownerName,
    this.accountId,
    this.phone,
    this.email,
    this.whatsapp,
    this.alternatePhone,
    this.city,
    this.state,
    this.pincode,
    this.category = 'salon',
    this.addressLine,
    this.description,
    this.gstNumber,
    this.website,
    this.googleMapEmbed,
    this.latitude,
    this.longitude,
    this.notes,
    this.schedules = const [],
  });

  final String businessName;
  final String ownerName;
  final String? accountId;
  final String? phone;
  final String? email;
  final String? whatsapp;
  final String? alternatePhone;
  final String? city;
  final String? state;
  final String? pincode;
  final String category;
  final String? addressLine;
  final String? description;
  final String? gstNumber;
  final String? website;
  final String? googleMapEmbed;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final List<DaySchedule> schedules;

  Map<String, dynamic> toRpcParams({bool includeAccountId = true}) => {
        'business_name': businessName,
        'owner_name': ownerName,
        if (includeAccountId && accountId != null) 'account_id': accountId,
        'phone': phone,
        'email': email,
        'whatsapp': whatsapp,
        'alternate_phone': alternatePhone,
        'city': city,
        'state': state,
        'pincode': pincode,
        'category': category,
        'address_line': addressLine,
        'description': description,
        'gst_number': gstNumber,
        'website': website,
        'google_map_embed': googleMapEmbed,
        'latitude': latitude,
        'longitude': longitude,
        'notes': notes,
        'schedules': schedulesToRpc(schedules),
      };
}

class PartnerAccountFormData {
  const PartnerAccountFormData({
    required this.ownerName,
    required this.phone,
    this.email,
    this.whatsapp,
    this.alternatePhone,
    this.password,
    this.phoneVerificationToken,
    this.whatsappVerificationToken,
  });

  final String ownerName;
  final String phone;
  final String? email;
  final String? whatsapp;
  final String? alternatePhone;
  final String? password;
  final String? phoneVerificationToken;
  final String? whatsappVerificationToken;

  Map<String, dynamic> toRpcParams() => {
        'owner_name': ownerName,
        'phone': phone,
        'email': email,
        'whatsapp': whatsapp,
        'alternate_phone': alternatePhone,
        'login_pass': password,
        if (phoneVerificationToken != null)
          'phone_verification_token': phoneVerificationToken,
        if (whatsappVerificationToken != null)
          'whatsapp_verification_token': whatsappVerificationToken,
      };
}

class PartnersRepository {
  PartnersRepository(this._client, this._kycRepository);

  final SupabaseClient _client;
  final PartnerKycRepository _kycRepository;

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

  Future<List<PartnerRecord>> listPartners(String callerId) async {
    final result = await _client.rpc<dynamic>(
      'list_partners',
      params: {'caller_id': callerId},
    );
    return _parseList(result, PartnerRecord.fromJson);
  }

  Future<List<PartnerOwnerAccount>> listPartnerAccounts(
    String callerId,
  ) async {
    final result = await _client.rpc<dynamic>(
      'list_partner_accounts',
      params: {'caller_id': callerId},
    );
    return _parseList(result, PartnerOwnerAccount.fromJson);
  }

  Future<void> createPartner({
    required String callerId,
    required PartnerFormData data,
  }) async {
    await _client.rpc(
      'create_partner',
      params: {'caller_id': callerId, ...data.toRpcParams()},
    );
  }

  Future<void> createPartnerAccount({
    required String callerId,
    required PartnerAccountFormData data,
  }) async {
    await _client.rpc(
      'create_partner_account',
      params: {'caller_id': callerId, ...data.toRpcParams()},
    );
  }

  Future<void> updatePartnerAccount({
    required String callerId,
    required String accountId,
    required PartnerAccountFormData data,
  }) async {
    await _client.rpc(
      'update_partner_account',
      params: {
        'caller_id': callerId,
        'account_id': accountId,
        ...data.toRpcParams(),
      },
    );
  }

  Future<void> deletePartnerAccount({
    required String callerId,
    required String accountId,
  }) async {
    final stores = await listPartners(callerId);
    for (final store in stores) {
      if (store.accountId == accountId) {
        await _kycRepository.deletePartnerDocuments(store.id);
      }
    }

    await _client.rpc(
      'delete_partner_account',
      params: {
        'caller_id': callerId,
        'account_id': accountId,
      },
    );
  }

  Future<void> setPartnerAccountActive({
    required String callerId,
    required String accountId,
    required bool active,
  }) async {
    await _client.rpc(
      'set_partner_account_active',
      params: {
        'caller_id': callerId,
        'account_id': accountId,
        'active': active,
      },
    );
  }

  Future<void> updatePartner({
    required String callerId,
    required String partnerId,
    required PartnerFormData data,
  }) async {
    await _client.rpc(
      'update_partner',
      params: {
        'caller_id': callerId,
        'partner_id': partnerId,
        ...data.toRpcParams(),
      },
    );
  }

  Future<void> deletePartner({
    required String callerId,
    required String partnerId,
  }) async {
    await _kycRepository.deletePartnerDocuments(partnerId);

    await _client.rpc(
      'delete_partner',
      params: {
        'caller_id': callerId,
        'partner_id': partnerId,
      },
    );
  }

  Future<void> setPartnerActive({
    required String callerId,
    required String partnerId,
    required bool active,
  }) async {
    await _client.rpc(
      'set_partner_active',
      params: {
        'caller_id': callerId,
        'partner_id': partnerId,
        'active': active,
      },
    );
  }

  Future<void> setPartnerKyc({
    required String callerId,
    required String partnerId,
    required String status,
  }) async {
    await _client.rpc(
      'set_partner_kyc',
      params: {
        'caller_id': callerId,
        'partner_id': partnerId,
        'new_status': status,
      },
    );
  }

  Future<void> setPartnerPassword({
    required String callerId,
    required String partnerId,
    required String loginId,
    required String password,
  }) async {
    await _client.rpc(
      'set_partner_password',
      params: {
        'caller_id': callerId,
        'partner_id': partnerId,
        'login_id': loginId,
        'new_pass': password,
      },
    );
  }

  Future<String> uploadStoreImage({
    required String partnerId,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('File not found');
    }

    // Optimize image bytes first to target 20-40KB
    final bytes = await _optimizeImage(file);

    // Save as .jpg for compressed images
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$partnerId/image_$timestamp.jpg';

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

  Future<void> updatePartnerImages({
    required String callerId,
    required String partnerId,
    required List<String> images,
    required String? primaryImage,
  }) async {
    await _client.rpc(
      'update_partner_images',
      params: {
        'caller_id': callerId,
        'partner_id': partnerId,
        'images': images,
        'primary_image': primaryImage,
      },
    );
  }
}
