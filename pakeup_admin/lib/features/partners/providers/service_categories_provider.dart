import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/utils/list_sort.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/service_categories_repository.dart';

final serviceCategoriesRepositoryProvider =
    Provider<ServiceCategoriesRepository>((ref) {
  return ServiceCategoriesRepository(ref.watch(supabaseClientProvider));
});

final serviceCategoriesListProvider =
    FutureProvider<List<ServiceCategory>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];

  final repo = ref.watch(serviceCategoriesRepositoryProvider);
  return (await repo.listCategories(user.id))
      .sortedByNewest((c) => c.createdAt);
});

/// Active service categories only — for service form dropdown (manual sort order).
final activeServiceCategoriesProvider =
    FutureProvider<List<ServiceCategory>>((ref) async {
  final all = await ref.watch(serviceCategoriesListProvider.future);
  final active = all.where((c) => c.isActive).toList();
  active.sort((a, b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    if (byOrder != 0) return byOrder;
    return a.name.compareTo(b.name);
  });
  return active;
});
