class PartnerServiceRecord {
  const PartnerServiceRecord({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.name,
    this.description,
    required this.price,
    required this.durationMinutes,
    required this.category,
    required this.targetGender,
    this.discountPrice,
    required this.serviceLocation,
    this.serviceImage,
    this.isFeatured = false,
    this.prepInstructions,
    this.primaryImage,
    this.images = const [],
    this.ownerName,
    this.phone,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String partnerId;
  final String partnerName;
  final String? ownerName;
  final String? phone;
  final String? primaryImage;
  final List<String> images;
  final String name;
  final String? description;
  final double price;
  final int durationMinutes;
  final String category;
  final String targetGender;
  final double? discountPrice;
  final String serviceLocation;
  final String? serviceImage;
  final bool isFeatured;
  final String? prepInstructions;
  final bool isActive;
  final DateTime? createdAt;

  factory PartnerServiceRecord.fromJson(Map<String, dynamic> json) {
    return PartnerServiceRecord(
      id: json['id'] as String,
      partnerId: json['partner_id'] as String,
      partnerName: json['partner_name'] as String? ?? '',
      ownerName: json['owner_name'] as String?,
      phone: json['phone'] as String?,
      primaryImage: json['primary_image'] as String?,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      name: json['name'] as String,
      description: json['description'] as String?,
      price: _toDouble(json['price']),
      discountPrice: json['discount_price'] != null ? _toDouble(json['discount_price']) : null,
      durationMinutes: json['duration_minutes'] as int? ?? 30,
      category: json['category'] as String? ?? 'Others',
      targetGender: json['target_gender'] as String? ?? 'Unisex',
      serviceLocation: json['service_location'] as String? ?? 'At Salon Only',
      serviceImage: json['service_image'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      prepInstructions: json['prep_instructions'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class PartnerServiceFormData {
  const PartnerServiceFormData({
    required this.partnerId,
    required this.name,
    this.description,
    required this.price,
    required this.durationMinutes,
    required this.category,
    required this.targetGender,
    this.discountPrice,
    required this.serviceLocation,
    this.serviceImage,
    this.isFeatured = false,
    this.prepInstructions,
    this.isActive = true,
  });

  final String partnerId;
  final String name;
  final String? description;
  final double price;
  final int durationMinutes;
  final String category;
  final String targetGender;
  final double? discountPrice;
  final String serviceLocation;
  final String? serviceImage;
  final bool isFeatured;
  final String? prepInstructions;
  final bool isActive;

  Map<String, dynamic> toCreateParams() => {
        'partner_id': partnerId,
        'service_name': name,
        'description': description,
        'price': price,
        'duration_minutes': durationMinutes,
        'category': category,
        'target_gender': targetGender,
        'discount_price': discountPrice,
        'service_location': serviceLocation,
        'service_image': serviceImage,
        'is_featured': isFeatured,
        'prep_instructions': prepInstructions,
      };

  Map<String, dynamic> toUpdateParams(String serviceId) => {
        'service_id': serviceId,
        'partner_id': partnerId,
        'service_name': name,
        'description': description,
        'price': price,
        'duration_minutes': durationMinutes,
        'active': isActive,
        'category': category,
        'target_gender': targetGender,
        'discount_price': discountPrice,
        'service_location': serviceLocation,
        'service_image': serviceImage,
        'is_featured': isFeatured,
        'prep_instructions': prepInstructions,
      };
}
