import 'package:supabase_flutter/supabase_flutter.dart';

class PartnerRecord {
  const PartnerRecord({
    required this.id,
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
    this.createdAt,
  });

  final String id;
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
  final DateTime? createdAt;

  String get displayCategory => categoryName ?? category;

  factory PartnerRecord.fromJson(Map<String, dynamic> json) {
    return PartnerRecord(
      id: json['id'] as String,
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
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class PartnerFormData {
  const PartnerFormData({
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
    this.addressLine,
    this.description,
    this.gstNumber,
    this.website,
    this.googleMapEmbed,
    this.latitude,
    this.longitude,
    this.notes,
  });

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
  final String? addressLine;
  final String? description;
  final String? gstNumber;
  final String? website;
  final String? googleMapEmbed;
  final double? latitude;
  final double? longitude;
  final String? notes;

  Map<String, dynamic> toRpcParams() => {
        'business_name': businessName,
        'owner_name': ownerName,
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
      };
}

class PartnersRepository {
  PartnersRepository(this._client);

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

  Future<List<PartnerRecord>> listPartners(String callerId) async {
    final result = await _client.rpc<dynamic>(
      'list_partners',
      params: {'caller_id': callerId},
    );
    return _parseList(result, PartnerRecord.fromJson);
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
}
