import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/partners_repository.dart';

final partnersRepositoryProvider = Provider<PartnersRepository>((ref) {
  return PartnersRepository(ref.watch(supabaseClientProvider));
});

final partnersListProvider = FutureProvider<List<PartnerRecord>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];

  final repo = ref.watch(partnersRepositoryProvider);
  return repo.listPartners(user.id);
});
