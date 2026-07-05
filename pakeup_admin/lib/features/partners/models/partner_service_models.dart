class PartnerServiceRecord {
  const PartnerServiceRecord({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.name,
    this.description,
    required this.price,
    required this.durationMinutes,
    this.primaryImage,
    this.images = const [],
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String partnerId;
  final String partnerName;
  final String? primaryImage;
  final List<String> images;
  final String name;
  final String? description;
  final double price;
  final int durationMinutes;
  final bool isActive;
  final DateTime? createdAt;

  factory PartnerServiceRecord.fromJson(Map<String, dynamic> json) {
    return PartnerServiceRecord(
      id: json['id'] as String,
      partnerId: json['partner_id'] as String,
      partnerName: json['partner_name'] as String? ?? '',
      primaryImage: json['primary_image'] as String?,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      name: json['name'] as String,
      description: json['description'] as String?,
      price: _toDouble(json['price']),
      durationMinutes: json['duration_minutes'] as int? ?? 30,
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
    this.isActive = true,
  });

  final String partnerId;
  final String name;
  final String? description;
  final double price;
  final int durationMinutes;
  final bool isActive;

  Map<String, dynamic> toCreateParams() => {
        'partner_id': partnerId,
        'service_name': name,
        'description': description,
        'price': price,
        'duration_minutes': durationMinutes,
      };

  Map<String, dynamic> toUpdateParams(String serviceId) => {
        'service_id': serviceId,
        'partner_id': partnerId,
        'service_name': name,
        'description': description,
        'price': price,
        'duration_minutes': durationMinutes,
        'active': isActive,
      };
}
