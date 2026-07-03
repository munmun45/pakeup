import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/partner_services_repository.dart';
import '../models/partner_service_models.dart';

final partnerServicesRepositoryProvider =
    Provider<PartnerServicesRepository>((ref) {
  return PartnerServicesRepository(ref.watch(supabaseClientProvider));
});

final partnerServicesListProvider =
    FutureProvider<List<PartnerServiceRecord>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];

  return ref.read(partnerServicesRepositoryProvider).listServices(user.id);
});
