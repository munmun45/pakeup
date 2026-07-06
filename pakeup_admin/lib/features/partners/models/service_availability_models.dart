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
      id: json['id'] as String,
      serviceId: json['service_id'] as String,
      overrideDate: DateTime.parse(json['override_date'] as String),
      visitType: VisitType.fromDbValue(json['visit_type'] as String?),
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
