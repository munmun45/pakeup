import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/stores_repository.dart';
import '../models/store_models.dart';

final storesRepositoryProvider = Provider<StoresRepository>((ref) {
  return StoresRepository(ref.watch(supabaseClientProvider));
});

final myStoresProvider = FutureProvider<List<StoreRecord>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const [];

  final loginPass = await ref.read(authRepositoryProvider).getStoredLoginPass();
  if (loginPass == null || loginPass.isEmpty) return const [];

  return ref.read(storesRepositoryProvider).getMyStores(
        accountId: user.id,
        loginPass: loginPass,
      );
});

final hasStoresProvider = Provider<bool>((ref) {
  return ref.watch(myStoresProvider).maybeWhen(
        data: (stores) => stores.isNotEmpty,
        orElse: () => false,
      );
});

final storeDetailProvider =
    FutureProvider.family<StoreRecord, String>((ref, storeId) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) throw StateError('Not logged in');

  final loginPass = await ref.read(authRepositoryProvider).getStoredLoginPass();
  if (loginPass == null || loginPass.isEmpty) {
    throw StateError('Session expired. Please log in again.');
  }

  return ref.read(storesRepositoryProvider).getStore(
        accountId: user.id,
        loginPass: loginPass,
        storeId: storeId,
      );
});
