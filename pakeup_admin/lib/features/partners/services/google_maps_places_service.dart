import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/partner_location_data.dart';

class GoogleMapsPlacesService {
  GoogleMapsPlacesService(this.apiKey);

  final String apiKey;

  static const _base = 'https://maps.googleapis.com/maps/api';

  Future<List<PlacePrediction>> autocomplete(String input) async {
    if (input.trim().length < 2) return [];

    final uri = Uri.parse('$_base/place/autocomplete/json').replace(
      queryParameters: {
        'input': input.trim(),
        'key': apiKey,
        'components': 'country:in',
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
      return [];
    }

    final predictions = data['predictions'] as List<dynamic>? ?? [];
    return predictions
        .map(
          (p) => PlacePrediction(
            placeId: p['place_id'] as String,
            description: p['description'] as String,
          ),
        )
        .toList();
  }

  Future<PartnerLocationData?> placeDetails(String placeId) async {
    final uri = Uri.parse('$_base/place/details/json').replace(
      queryParameters: {
        'place_id': placeId,
        'fields': 'geometry,formatted_address,address_component',
        'key': apiKey,
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;

    final result = data['result'] as Map<String, dynamic>?;
    if (result == null) return null;

    return _fromPlaceResult(result);
  }

  Future<PartnerLocationData?> reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse('$_base/geocode/json').replace(
      queryParameters: {
        'latlng': '$lat,$lng',
        'key': apiKey,
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;

    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;

    return _fromGeocodeResult(results.first as Map<String, dynamic>, lat, lng);
  }

  PartnerLocationData? _fromPlaceResult(Map<String, dynamic> result) {
    final geometry = result['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    if (location == null) return null;

    final lat = (location['lat'] as num).toDouble();
    final lng = (location['lng'] as num).toDouble();
    final parsed = _parseAddressComponents(
      result['address_components'] as List<dynamic>? ?? [],
    );

    return PartnerLocationData(
      latitude: lat,
      longitude: lng,
      address: result['formatted_address'] as String? ?? '',
      city: parsed.city,
      state: parsed.state,
      pincode: parsed.pincode,
    );
  }

  PartnerLocationData _fromGeocodeResult(
    Map<String, dynamic> result,
    double lat,
    double lng,
  ) {
    final parsed = _parseAddressComponents(
      result['address_components'] as List<dynamic>? ?? [],
    );

    return PartnerLocationData(
      latitude: lat,
      longitude: lng,
      address: result['formatted_address'] as String? ?? '',
      city: parsed.city,
      state: parsed.state,
      pincode: parsed.pincode,
    );
  }

  ({String city, String state, String pincode}) _parseAddressComponents(
    List<dynamic> components,
  ) {
    var city = '';
    var state = '';
    var pincode = '';

    for (final raw in components) {
      final c = raw as Map<String, dynamic>;
      final types = (c['types'] as List<dynamic>).cast<String>();
      final name = c['long_name'] as String? ?? '';

      if (types.contains('locality')) {
        city = name;
      } else if (types.contains('administrative_area_level_1')) {
        state = name;
      } else if (types.contains('postal_code')) {
        pincode = name;
      } else if (city.isEmpty && types.contains('sublocality_level_1')) {
        city = name;
      } else if (city.isEmpty && types.contains('administrative_area_level_2')) {
        city = name;
      }
    }

    return (city: city, state: state, pincode: pincode);
  }
}
