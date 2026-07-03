import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/partner_kyc_repository.dart';
import '../models/partner_kyc_models.dart';

final partnerKycRepositoryProvider = Provider<PartnerKycRepository>((ref) {
  return PartnerKycRepository(ref.watch(supabaseClientProvider));
});

final partnerAccountsListProvider =
    FutureProvider<List<PartnerAccountRecord>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];

  return ref.read(partnerKycRepositoryProvider).listAccounts(user.id);
});
