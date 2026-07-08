import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final partnerCategoriesProvider =
    FutureProvider<List<PartnerCategoryOption>>((ref) async {
  return ref.read(authRepositoryProvider).listCategories();
});

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, PartnerUser?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<PartnerUser?> {
  late final AuthRepository _repository;

  @override
  Future<PartnerUser?> build() async {
    _repository = ref.read(authRepositoryProvider);
    return _repository.getCurrentUser();
  }

  Future<void> login(String phone, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _repository.login(phone: phone, password: password);
    });
    if (state.hasError) throw state.error!;
  }

  Future<void> register(PartnerRegisterData data) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _repository.register(data);
    });
    if (state.hasError) throw state.error!;
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncData(null);
  }

  Future<void> refreshSession() async {
    final user = await _repository.refreshSession();
    if (user != null) {
      state = AsyncData(user);
    }
  }
}
