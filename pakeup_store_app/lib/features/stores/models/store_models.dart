import 'store_schedule_models.dart';

class StoreRecord {
  const StoreRecord({
    required this.id,
    required this.accountId,
    required this.businessName,
    required this.ownerName,
    this.phone,
    this.whatsapp,
    this.alternatePhone,
    this.email,
    this.description,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.latitude,
    this.longitude,
    this.category = 'salon',
    this.isActive = true,
    this.kycStatus = 'pending',
    this.primaryImage,
    this.images = const [],
    this.serviceCount = 0,
    this.createdAt,
    this.schedules = const [],
  });

  final String id;
  final String accountId;
  final String businessName;
  final String ownerName;
  final String? phone;
  final String? whatsapp;
  final String? alternatePhone;
  final String? email;
  final String? description;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final double? latitude;
  final double? longitude;
  final String category;
  final bool isActive;
  final String kycStatus;
  final String? primaryImage;
  final List<String> images;
  final int serviceCount;
  final DateTime? createdAt;
  final List<DaySchedule> schedules;

  String get locationLabel {
    final cityState = [city, state]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (cityState.isNotEmpty) return cityState.join(', ');
    final addr = address?.trim();
    if (addr != null && addr.isNotEmpty) return addr;
    return 'No location set';
  }

  String get addressLabel {
    final parts = <String>[];
    final addr = address?.trim();
    if (addr != null && addr.isNotEmpty) parts.add(addr);

    final cityState = [city, state]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(', ');
    if (cityState.isNotEmpty) parts.add(cityState);

    final pin = pincode?.trim();
    if (pin != null && pin.isNotEmpty) parts.add(pin);

    if (parts.isNotEmpty) return parts.join(', ');
    return 'No address set';
  }

  bool get isKycApproved => kycStatus == 'approved';

  String get kycLabel => switch (kycStatus) {
        'approved' => 'KYC Approved',
        'rejected' => 'KYC Rejected',
        _ => 'KYC Pending',
      };

  String get categoryLabel {
    final value = category.trim().replaceAll('_', ' ');
    if (value.isEmpty) return 'Store';
    return value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              part[0].toUpperCase() + part.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  factory StoreRecord.fromJson(Map<String, dynamic> json) => StoreRecord(
        id: json['id'] as String,
        accountId: json['account_id'] as String? ?? '',
        businessName: json['business_name'] as String? ?? '',
        ownerName: json['owner_name'] as String? ?? '',
        phone: json['phone'] as String?,
        whatsapp: json['whatsapp'] as String?,
        alternatePhone: json['alternate_phone'] as String?,
        email: json['email'] as String?,
        description: json['description'] as String?,
        address: json['address_line'] as String? ?? json['address'] as String?,
        city: json['city'] as String?,
        state: json['state'] as String?,
        pincode: json['pincode'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        category: json['category'] as String? ?? 'salon',
        isActive: json['is_active'] as bool? ?? true,
        kycStatus: json['kyc_status'] as String? ?? 'pending',
        primaryImage: json['primary_image'] as String?,
        images: (json['images'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        serviceCount: json['service_count'] as int? ?? 0,
        createdAt: _parseDate(json['created_at']),
        schedules: DaySchedule.parseList(json['schedules']),
      );
}

class AddStoreData {
  const AddStoreData({
    required this.businessName,
    required this.phone,
    required this.whatsapp,
    this.description,
    this.email,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.latitude,
    this.longitude,
    this.category = 'salon',
    this.schedules = const [],
  });

  final String businessName;
  final String phone;
  final String whatsapp;
  final String? description;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final double? latitude;
  final double? longitude;
  final String category;
  final List<DaySchedule> schedules;
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
