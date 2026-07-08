class ServiceRecord {
  const ServiceRecord({
    required this.id,
    required this.partnerId,
    required this.name,
    this.description,
    required this.category,
    required this.targetGender,
    this.isParlourAvailable = true,
    this.parlourPriceMen,
    this.parlourDurationMen,
    this.parlourPriceWomen,
    this.parlourDurationWomen,
    this.isHomeAvailable = false,
    this.homePriceMen,
    this.homeDurationMen,
    this.homePriceWomen,
    this.homeDurationWomen,
    this.serviceImage,
    this.primaryImage,
    this.images = const [],
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String partnerId;
  final String name;
  final String? description;
  final String category;
  final String targetGender;
  final bool isParlourAvailable;
  final double? parlourPriceMen;
  final int? parlourDurationMen;
  final double? parlourPriceWomen;
  final int? parlourDurationWomen;
  final bool isHomeAvailable;
  final double? homePriceMen;
  final int? homeDurationMen;
  final double? homePriceWomen;
  final int? homeDurationWomen;
  final String? serviceImage;
  final String? primaryImage;
  final List<String> images;
  final bool isActive;
  final DateTime? createdAt;

  String? get displayImage {
    final primary = primaryImage?.trim();
    if (primary != null && primary.isNotEmpty) return primary;
    final legacy = serviceImage?.trim();
    if (legacy != null && legacy.isNotEmpty) return legacy;
    if (images.isNotEmpty) return images.first;
    return null;
  }

  bool get hasPricing {
    final prices = [
      parlourPriceMen,
      parlourPriceWomen,
      homePriceMen,
      homePriceWomen,
    ].whereType<double>().where((p) => p > 0);
    return prices.isNotEmpty;
  }

  String get priceDisplay {
    final prices = [
      parlourPriceMen,
      parlourPriceWomen,
      homePriceMen,
      homePriceWomen,
    ].whereType<double>().toList();
    if (prices.isEmpty) return '—';
    final min = prices.reduce((a, b) => a < b ? a : b);
    final max = prices.reduce((a, b) => a > b ? a : b);
    if (min == max) return '₹${min.toStringAsFixed(0)}';
    return '₹${min.toStringAsFixed(0)} – ₹${max.toStringAsFixed(0)}';
  }

  factory ServiceRecord.fromJson(Map<String, dynamic> json) => ServiceRecord(
        id: json['id'] as String,
        partnerId: json['partner_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        category: json['category'] as String? ?? '',
        targetGender: json['target_gender'] as String? ?? 'both',
        isParlourAvailable: json['is_parlour_available'] as bool? ?? true,
        parlourPriceMen: (json['parlour_price_men'] as num?)?.toDouble(),
        parlourDurationMen: json['parlour_duration_men'] as int?,
        parlourPriceWomen: (json['parlour_price_women'] as num?)?.toDouble(),
        parlourDurationWomen: json['parlour_duration_women'] as int?,
        isHomeAvailable: json['is_home_available'] as bool? ?? false,
        homePriceMen: (json['home_price_men'] as num?)?.toDouble(),
        homeDurationMen: json['home_duration_men'] as int?,
        homePriceWomen: (json['home_price_women'] as num?)?.toDouble(),
        homeDurationWomen: json['home_duration_women'] as int?,
        serviceImage: json['service_image'] as String?,
        primaryImage: json['primary_image'] as String?,
        images: (json['images'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        isActive: json['is_active'] as bool? ?? true,
        createdAt: _parseDate(json['created_at']),
      );
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
