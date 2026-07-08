import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/kyc_repository.dart';
import '../models/kyc_models.dart';

final kycRepositoryProvider = Provider<KycRepository>((ref) {
  return KycRepository(ref.watch(supabaseClientProvider));
});

final storeKycProvider =
    FutureProvider.family<StoreKycRecord?, String>((ref, storeId) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final loginPass = await ref.read(authRepositoryProvider).getStoredLoginPass();
  if (loginPass == null || loginPass.isEmpty) return null;

  return ref.read(kycRepositoryProvider).getStoreKyc(
        accountId: user.id,
        loginPass: loginPass,
        storeId: storeId,
      );
});
