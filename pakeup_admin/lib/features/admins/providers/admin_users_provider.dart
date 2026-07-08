import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/utils/list_sort.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/admin_users_repository.dart';

final adminUsersRepositoryProvider = Provider<AdminUsersRepository>((ref) {
  return AdminUsersRepository(ref.watch(supabaseClientProvider));
});

final adminUsersListProvider = FutureProvider<List<AdminAccount>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || !user.isSuperAdmin) return [];

  final repo = ref.watch(adminUsersRepositoryProvider);
  return (await repo.listAdmins(user.id))
      .sortedByNewest((a) => a.createdAt);
});
