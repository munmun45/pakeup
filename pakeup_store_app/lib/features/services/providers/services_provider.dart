import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/services_repository.dart';
import '../models/service_models.dart';

final servicesRepositoryProvider = Provider<ServicesRepository>((ref) {
  return ServicesRepository(ref.watch(supabaseClientProvider));
});

final myServicesProvider = FutureProvider<List<ServiceRecord>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const [];

  final loginPass = await ref.read(authRepositoryProvider).getStoredLoginPass();
  if (loginPass == null || loginPass.isEmpty) return const [];

  return ref.read(servicesRepositoryProvider).getMyServices(
        accountId: user.id,
        loginPass: loginPass,
      );
});

final storeServicesProvider =
    FutureProvider.family<List<ServiceRecord>, String>((ref, storeId) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const [];

  final loginPass = await ref.read(authRepositoryProvider).getStoredLoginPass();
  if (loginPass == null || loginPass.isEmpty) return const [];

  return ref.read(servicesRepositoryProvider).getStoreServices(
        accountId: user.id,
        loginPass: loginPass,
        storeId: storeId,
      );
});
