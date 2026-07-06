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
    this.freeRadiusKm = 0,
    this.perKmCharge = 0.0,
    this.isParlourAvailable = true,
    this.parlourPrice,
    this.parlourDurationMinutes,
    this.parlourTargetGender,
    this.parlourPriceMen,
    this.parlourDurationMen,
    this.parlourPriceWomen,
    this.parlourDurationWomen,
    this.parlourPrepMen,
    this.parlourPrepWomen,
    this.isHomeAvailable = false,
    this.homePrice,
    this.homeDurationMinutes,
    this.homeTargetGender,
    this.homePriceMen,
    this.homeDurationMen,
    this.homePriceWomen,
    this.homeDurationWomen,
    this.homePrepMen,
    this.homePrepWomen,
    this.serviceImage,
    this.isFeatured = false,
    this.prepInstructions,
    this.primaryImage,
    this.images = const [],
    this.partnerPrimaryImage,
    this.partnerImages = const [],
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
  final String? partnerPrimaryImage;
  final List<String> partnerImages;
  final String name;
  final String? description;
  final double price;
  final int durationMinutes;
  final String category;
  final String targetGender;
  final double? discountPrice;
  final String serviceLocation;
  final int freeRadiusKm;
  final double perKmCharge;
  final bool isParlourAvailable;
  final double? parlourPrice;
  final int? parlourDurationMinutes;
  final String? parlourTargetGender;
  final double? parlourPriceMen;
  final int? parlourDurationMen;
  final double? parlourPriceWomen;
  final int? parlourDurationWomen;
  final String? parlourPrepMen;
  final String? parlourPrepWomen;
  final bool isHomeAvailable;
  final double? homePrice;
  final int? homeDurationMinutes;
  final String? homeTargetGender;
  final double? homePriceMen;
  final int? homeDurationMen;
  final double? homePriceWomen;
  final int? homeDurationWomen;
  final String? homePrepMen;
  final String? homePrepWomen;
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
      partnerPrimaryImage: json['partner_primary_image'] as String?,
      partnerImages: (json['partner_images'] as List<dynamic>?)
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
      freeRadiusKm: json['free_radius_km'] as int? ?? 0,
      perKmCharge: _toDouble(json['per_km_charge']),
      isParlourAvailable: json['is_parlour_available'] as bool? ?? true,
      parlourPrice: json['parlour_price'] != null ? _toDouble(json['parlour_price']) : null,
      parlourDurationMinutes: json['parlour_duration_minutes'] as int?,
      parlourTargetGender: json['parlour_target_gender'] as String?,
      parlourPriceMen: json['parlour_price_men'] != null ? _toDouble(json['parlour_price_men']) : null,
      parlourDurationMen: json['parlour_duration_men'] as int?,
      parlourPriceWomen: json['parlour_price_women'] != null ? _toDouble(json['parlour_price_women']) : null,
      parlourDurationWomen: json['parlour_duration_women'] as int?,
      parlourPrepMen: json['parlour_prep_men'] as String?,
      parlourPrepWomen: json['parlour_prep_women'] as String?,
      isHomeAvailable: json['is_home_available'] as bool? ?? false,
      homePrice: json['home_price'] != null ? _toDouble(json['home_price']) : null,
      homeDurationMinutes: json['home_duration_minutes'] as int?,
      homeTargetGender: json['home_target_gender'] as String?,
      homePriceMen: json['home_price_men'] != null ? _toDouble(json['home_price_men']) : null,
      homeDurationMen: json['home_duration_men'] as int?,
      homePriceWomen: json['home_price_women'] != null ? _toDouble(json['home_price_women']) : null,
      homeDurationWomen: json['home_duration_women'] as int?,
      homePrepMen: json['home_prep_men'] as String?,
      homePrepWomen: json['home_prep_women'] as String?,
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
    this.freeRadiusKm = 0,
    this.perKmCharge = 0.0,
    this.isParlourAvailable = true,
    this.parlourPrice,
    this.parlourDurationMinutes,
    this.parlourTargetGender,
    this.parlourPriceMen,
    this.parlourDurationMen,
    this.parlourPriceWomen,
    this.parlourDurationWomen,
    this.parlourPrepMen,
    this.parlourPrepWomen,
    this.isHomeAvailable = false,
    this.homePrice,
    this.homeDurationMinutes,
    this.homeTargetGender,
    this.homePriceMen,
    this.homeDurationMen,
    this.homePriceWomen,
    this.homeDurationWomen,
    this.homePrepMen,
    this.homePrepWomen,
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
  final int freeRadiusKm;
  final double perKmCharge;
  
  final bool isParlourAvailable;
  final double? parlourPrice;
  final int? parlourDurationMinutes;
  final String? parlourTargetGender;
  final double? parlourPriceMen;
  final int? parlourDurationMen;
  final double? parlourPriceWomen;
  final int? parlourDurationWomen;
  final String? parlourPrepMen;
  final String? parlourPrepWomen;
  
  final bool isHomeAvailable;
  final double? homePrice;
  final int? homeDurationMinutes;
  final String? homeTargetGender;
  final double? homePriceMen;
  final int? homeDurationMen;
  final double? homePriceWomen;
  final int? homeDurationWomen;
  final String? homePrepMen;
  final String? homePrepWomen;
  
  final String? serviceImage;
  final bool isFeatured;
  final String? prepInstructions;
  final bool isActive;

  Map<String, dynamic> toCreateParams() => {
        'partner_id': partnerId,
        'service_name': name,
        'description': description,
        'category': category,
        'discount_price': discountPrice,
        'free_radius_km': freeRadiusKm,
        'per_km_charge': perKmCharge,
        
        'is_parlour_available': isParlourAvailable,
        'parlour_price_men': parlourPriceMen,
        'parlour_duration_men': parlourDurationMen,
        'parlour_price_women': parlourPriceWomen,
        'parlour_duration_women': parlourDurationWomen,
        'parlour_prep_men': parlourPrepMen,
        'parlour_prep_women': parlourPrepWomen,
        
        'is_home_available': isHomeAvailable,
        'home_price_men': homePriceMen,
        'home_duration_men': homeDurationMen,
        'home_price_women': homePriceWomen,
        'home_duration_women': homeDurationWomen,
        'home_prep_men': homePrepMen,
        'home_prep_women': homePrepWomen,
        
        'service_image': serviceImage,
        'is_featured': isFeatured,
        'prep_instructions': prepInstructions,
      };

  Map<String, dynamic> toUpdateParams(String serviceId) => {
        'service_id': serviceId,
        'partner_id': partnerId,
        'service_name': name,
        'description': description,
        'active': isActive,
        'category': category,
        'discount_price': discountPrice,
        'free_radius_km': freeRadiusKm,
        'per_km_charge': perKmCharge,
        
        'is_parlour_available': isParlourAvailable,
        'parlour_price_men': parlourPriceMen,
        'parlour_duration_men': parlourDurationMen,
        'parlour_price_women': parlourPriceWomen,
        'parlour_duration_women': parlourDurationWomen,
        'parlour_prep_men': parlourPrepMen,
        'parlour_prep_women': parlourPrepWomen,
        
        'is_home_available': isHomeAvailable,
        'home_price_men': homePriceMen,
        'home_duration_men': homeDurationMen,
        'home_price_women': homePriceWomen,
        'home_duration_women': homeDurationWomen,
        'home_prep_men': homePrepMen,
        'home_prep_women': homePrepWomen,
        
        'service_image': serviceImage,
        'is_featured': isFeatured,
        'prep_instructions': prepInstructions,
      };
}
