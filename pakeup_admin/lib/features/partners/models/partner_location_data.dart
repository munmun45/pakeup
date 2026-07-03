class PartnerLocationData {
  const PartnerLocationData({
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
  });

  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String state;
  final String pincode;

  factory PartnerLocationData.fromJson(Map<String, dynamic> json) {
    return PartnerLocationData(
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
    );
  }
}

class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.description,
  });

  final String placeId;
  final String description;
}
