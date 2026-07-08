import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/utils/list_sort.dart';
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
  return (await repo.listCategories(user.id))
      .sortedByNewest((c) => c.createdAt);
});

/// Active categories only — for partner form dropdown (manual sort order).
final activePartnerCategoriesProvider =
    FutureProvider<List<PartnerCategory>>((ref) async {
  final all = await ref.watch(partnerCategoriesListProvider.future);
  final active = all.where((c) => c.isActive).toList();
  active.sort((a, b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    if (byOrder != 0) return byOrder;
    return a.name.compareTo(b.name);
  });
  return active;
});
