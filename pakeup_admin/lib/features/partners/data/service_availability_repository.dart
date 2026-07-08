import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_availability_models.dart';

class ServiceAvailabilityRepository {
  ServiceAvailabilityRepository(this._client);

  final SupabaseClient _client;

  Future<List<ServiceAvailabilityOverride>> getMonthOverrides({
    required String callerId,
    required String serviceId,
    required String yearMonth, // 'YYYY-MM'
  }) async {
    final result = await _client.rpc<dynamic>(
      'get_service_availability_overrides',
      params: {
        'caller_id': callerId,
        'service_id': serviceId,
        'year_month': yearMonth,
      },
    );
    if (result == null) return [];
    return (result as List<dynamic>)
        .map((e) => ServiceAvailabilityOverride.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<void> setOverride({
    required String callerId,
    required String serviceId,
    required DateTime date,
    required VisitType visitType,
    String? note,
  }) async {
    await _client.rpc(
      'set_service_availability_override',
      params: {
        'caller_id': callerId,
        'service_id': serviceId,
        'override_date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'visit_type': visitType.dbValue,
        'note': note,
      },
    );
  }

  Future<void> clearOverride({
    required String callerId,
    required String serviceId,
    required DateTime date,
  }) async {
    await _client.rpc(
      'clear_service_availability_override',
      params: {
        'caller_id': callerId,
        'service_id': serviceId,
        'override_date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      },
    );
  }

  Future<PartnerWeekInventory> getPartnerWeekInventory({
    required String callerId,
    required String partnerId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final result = await _client.rpc<dynamic>(
      'get_partner_week_inventory',
      params: {
        'caller_id': callerId,
        'partner_id': partnerId,
        'start_date': fmt(startDate),
        'end_date': fmt(endDate),
      },
    );
    if (result == null) {
      return const PartnerWeekInventory(availability: [], pricing: []);
    }
    return PartnerWeekInventory.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<void> setDayAvailable({
    required String callerId,
    required String serviceId,
    required DateTime date,
    required bool isAvailable,
  }) async {
    if (isAvailable) {
      await setOverride(
        callerId: callerId,
        serviceId: serviceId,
        date: date,
        visitType: VisitType.both,
      );
    } else {
      await clearOverride(
        callerId: callerId,
        serviceId: serviceId,
        date: date,
      );
    }
  }

  Future<void> upsertDayPricing({
    required String callerId,
    required String serviceId,
    required DateTime date,
    double? parlourPriceMen,
    double? parlourPriceWomen,
    double? homePriceMen,
    double? homePriceWomen,
    int? parlourDurationMen,
    int? parlourDurationWomen,
    int? homeDurationMen,
    int? homeDurationWomen,
  }) async {
    await _client.rpc(
      'upsert_service_day_pricing',
      params: {
        'caller_id': callerId,
        'service_id': serviceId,
        'override_date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'parlour_price_men': parlourPriceMen,
        'parlour_price_women': parlourPriceWomen,
        'home_price_men': homePriceMen,
        'home_price_women': homePriceWomen,
        'parlour_duration_men': parlourDurationMen,
        'parlour_duration_women': parlourDurationWomen,
        'home_duration_men': homeDurationMen,
        'home_duration_women': homeDurationWomen,
      },
    );
  }

  Future<void> updateServicePricing({
    required String callerId,
    required String serviceId,
    required bool isParlourAvailable,
    double? parlourPriceMen,
    int? parlourDurationMen,
    double? parlourPriceWomen,
    int? parlourDurationWomen,
    bool isHomeAvailable = false,
    double? homePriceMen,
    int? homeDurationMen,
    double? homePriceWomen,
    int? homeDurationWomen,
    int freeRadiusKm = 0,
    double perKmCharge = 0.0,
    double? discountPrice,
  }) async {
    await _client.rpc(
      'update_service_pricing',
      params: {
        'caller_id': callerId,
        'service_id': serviceId,
        'is_parlour_available': isParlourAvailable,
        'parlour_price_men': parlourPriceMen,
        'parlour_duration_men': parlourDurationMen,
        'parlour_price_women': parlourPriceWomen,
        'parlour_duration_women': parlourDurationWomen,
        'is_home_available': isHomeAvailable,
        'home_price_men': homePriceMen,
        'home_duration_men': homeDurationMen,
        'home_price_women': homePriceWomen,
        'home_duration_women': homeDurationWomen,
        'free_radius_km': freeRadiusKm,
        'per_km_charge': perKmCharge,
        'discount_price': discountPrice,
      },
    );
  }
}
