DateTime parseOverrideDate(dynamic value) {
  final parsed = DateTime.parse(value.toString());
  return DateTime(parsed.year, parsed.month, parsed.day);
}

enum VisitType {
  parlour,
  home,
  both,
  none;

  String get dbValue {
    switch (this) {
      case VisitType.parlour:
        return 'Parlour';
      case VisitType.home:
        return 'Home';
      case VisitType.both:
        return 'Both';
      case VisitType.none:
        return 'None';
    }
  }

  static VisitType fromDbValue(String? v) {
    switch (v) {
      case 'Parlour':
        return VisitType.parlour;
      case 'Home':
        return VisitType.home;
      case 'None':
        return VisitType.none;
      default:
        return VisitType.both;
    }
  }

  String get label {
    switch (this) {
      case VisitType.parlour:
        return 'Parlour Only';
      case VisitType.home:
        return 'Home Only';
      case VisitType.both:
        return 'Both';
      case VisitType.none:
        return 'Unavailable';
    }
  }
}

class ServicePricingOverride {
  const ServicePricingOverride({
    required this.serviceId,
    required this.overrideDate,
    this.parlourPriceMen,
    this.parlourPriceWomen,
    this.homePriceMen,
    this.homePriceWomen,
    this.parlourDurationMen,
    this.parlourDurationWomen,
    this.homeDurationMen,
    this.homeDurationWomen,
  });

  final String serviceId;
  final DateTime overrideDate;
  final double? parlourPriceMen;
  final double? parlourPriceWomen;
  final double? homePriceMen;
  final double? homePriceWomen;
  final int? parlourDurationMen;
  final int? parlourDurationWomen;
  final int? homeDurationMen;
  final int? homeDurationWomen;

  factory ServicePricingOverride.fromJson(Map<String, dynamic> json) {
    double? numVal(dynamic v) =>
        v == null ? null : (v as num).toDouble();
    int? intVal(dynamic v) => v == null ? null : (v as num).toInt();
    return ServicePricingOverride(
      serviceId: json['service_id']?.toString() ?? '',
      overrideDate: parseOverrideDate(json['override_date']),
      parlourPriceMen: numVal(json['parlour_price_men']),
      parlourPriceWomen: numVal(json['parlour_price_women']),
      homePriceMen: numVal(json['home_price_men']),
      homePriceWomen: numVal(json['home_price_women']),
      parlourDurationMen: intVal(json['parlour_duration_men']),
      parlourDurationWomen: intVal(json['parlour_duration_women']),
      homeDurationMen: intVal(json['home_duration_men']),
      homeDurationWomen: intVal(json['home_duration_women']),
    );
  }
}

class PartnerWeekInventory {
  const PartnerWeekInventory({
    required this.availability,
    required this.pricing,
  });

  final List<ServiceAvailabilityOverride> availability;
  final List<ServicePricingOverride> pricing;

  factory PartnerWeekInventory.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(
      dynamic raw,
      T Function(Map<String, dynamic>) fromMap,
    ) {
      if (raw == null) return [];
      return (raw as List<dynamic>)
          .map((e) => fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return PartnerWeekInventory(
      availability: parseList(
        json['availability'],
        (m) => ServiceAvailabilityOverride.fromJson(m),
      ),
      pricing: parseList(
        json['pricing'],
        (m) => ServicePricingOverride.fromJson(m),
      ),
    );
  }
}

class ServiceAvailabilityOverride {
  const ServiceAvailabilityOverride({
    required this.id,
    required this.serviceId,
    required this.overrideDate,
    required this.visitType,
    this.note,
  });

  final String id;
  final String serviceId;
  final DateTime overrideDate;
  final VisitType visitType;
  final String? note;

  factory ServiceAvailabilityOverride.fromJson(Map<String, dynamic> json) {
    return ServiceAvailabilityOverride(
      id: json['id']?.toString() ?? '',
      serviceId: json['service_id']?.toString() ?? '',
      overrideDate: parseOverrideDate(json['override_date']),
      visitType: VisitType.fromDbValue(json['visit_type']?.toString()),
      note: json['note'] as String?,
    );
  }
}

/// Local draft for in-memory pricing edits before bulk save
class ServicePricingDraft {
  ServicePricingDraft({
    required this.serviceId,
    required this.partnerId,
    required this.serviceName,
    required this.partnerName,
    required this.category,
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
    this.freeRadiusKm = 0,
    this.perKmCharge = 0.0,
    this.discountPrice,
  });

  final String serviceId;
  final String partnerId;
  final String serviceName;
  final String partnerName;
  final String category;
  bool isParlourAvailable;
  double? parlourPriceMen;
  int? parlourDurationMen;
  double? parlourPriceWomen;
  int? parlourDurationWomen;
  bool isHomeAvailable;
  double? homePriceMen;
  int? homeDurationMen;
  double? homePriceWomen;
  int? homeDurationWomen;
  int freeRadiusKm;
  double perKmCharge;
  double? discountPrice;
  bool isDirty = false;

  ServicePricingDraft copyWith({
    bool? isParlourAvailable,
    double? parlourPriceMen,
    int? parlourDurationMen,
    double? parlourPriceWomen,
    int? parlourDurationWomen,
    bool? isHomeAvailable,
    double? homePriceMen,
    int? homeDurationMen,
    double? homePriceWomen,
    int? homeDurationWomen,
    int? freeRadiusKm,
    double? perKmCharge,
    double? discountPrice,
  }) {
    final d = ServicePricingDraft(
      serviceId: serviceId,
      partnerId: partnerId,
      serviceName: serviceName,
      partnerName: partnerName,
      category: category,
      isParlourAvailable: isParlourAvailable ?? this.isParlourAvailable,
      parlourPriceMen: parlourPriceMen ?? this.parlourPriceMen,
      parlourDurationMen: parlourDurationMen ?? this.parlourDurationMen,
      parlourPriceWomen: parlourPriceWomen ?? this.parlourPriceWomen,
      parlourDurationWomen: parlourDurationWomen ?? this.parlourDurationWomen,
      isHomeAvailable: isHomeAvailable ?? this.isHomeAvailable,
      homePriceMen: homePriceMen ?? this.homePriceMen,
      homeDurationMen: homeDurationMen ?? this.homeDurationMen,
      homePriceWomen: homePriceWomen ?? this.homePriceWomen,
      homeDurationWomen: homeDurationWomen ?? this.homeDurationWomen,
      freeRadiusKm: freeRadiusKm ?? this.freeRadiusKm,
      perKmCharge: perKmCharge ?? this.perKmCharge,
      discountPrice: discountPrice ?? this.discountPrice,
    );
    d.isDirty = true;
    return d;
  }
}
