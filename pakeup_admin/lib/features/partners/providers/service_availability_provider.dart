import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/service_availability_repository.dart';
import '../models/service_availability_models.dart';

final serviceAvailabilityRepositoryProvider =
    Provider<ServiceAvailabilityRepository>((ref) {
  return ServiceAvailabilityRepository(ref.watch(supabaseClientProvider));
});

// Provider family: load overrides for a specific service + month
final serviceMonthOverridesProvider = FutureProvider.family<
    List<ServiceAvailabilityOverride>, ({String serviceId, String yearMonth})>(
  (ref, params) async {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) return [];
    return ref.read(serviceAvailabilityRepositoryProvider).getMonthOverrides(
          callerId: user.id,
          serviceId: params.serviceId,
          yearMonth: params.yearMonth,
        );
  },
);
