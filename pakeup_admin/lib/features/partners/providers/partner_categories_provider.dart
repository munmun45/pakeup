import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/partner_categories_repository.dart';

final partnerCategoriesRepositoryProvider =
    Provider<PartnerCategoriesRepository>((ref) {
  return PartnerCategoriesRepository(ref.watch(supabaseClientProvider));
});

final partnerCategoriesListProvider =
    FutureProvider<List<PartnerCategory>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];

  final repo = ref.watch(partnerCategoriesRepositoryProvider);
  return repo.listCategories(user.id);
});

/// Active categories only — for partner form dropdown.
final activePartnerCategoriesProvider =
    FutureProvider<List<PartnerCategory>>((ref) async {
  final all = await ref.watch(partnerCategoriesListProvider.future);
  return all.where((c) => c.isActive).toList();
});
