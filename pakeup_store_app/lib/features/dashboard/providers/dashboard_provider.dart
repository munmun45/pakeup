import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/dashboard_repository.dart';
import '../models/dashboard_models.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(supabaseClientProvider));
});

final partnerDashboardStatsProvider =
    FutureProvider<PartnerDashboardStats>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const PartnerDashboardStats();

  final loginPass = await ref.read(authRepositoryProvider).getStoredLoginPass();
  if (loginPass == null || loginPass.isEmpty) {
    return const PartnerDashboardStats();
  }

  return ref.read(dashboardRepositoryProvider).getStats(
        accountId: user.id,
        loginPass: loginPass,
      );
});
