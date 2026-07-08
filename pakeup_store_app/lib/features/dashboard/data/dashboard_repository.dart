import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this._client);

  final SupabaseClient _client;

  Future<PartnerDashboardStats> getStats({
    required String accountId,
    required String loginPass,
  }) async {
    try {
      final result = await _client.rpc<dynamic>(
        'get_partner_dashboard_stats',
        params: {
          'p_account_id': accountId,
          'p_login_pass': loginPass,
        },
      );
      if (result == null) return const PartnerDashboardStats();
      return PartnerDashboardStats.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (_) {
      return const PartnerDashboardStats();
    }
  }
}
