class StoreLocationData {
  const StoreLocationData({
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

  factory StoreLocationData.fromJson(Map<String, dynamic> json) {
    return StoreLocationData(
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
    );
  }
}
