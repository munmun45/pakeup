import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
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
  return repo.listCategories(user.id);
});

/// Active service categories only — for service form dropdown.
final activeServiceCategoriesProvider =
    FutureProvider<List<ServiceCategory>>((ref) async {
  final all = await ref.watch(serviceCategoriesListProvider.future);
  return all.where((c) => c.isActive).toList();
});
