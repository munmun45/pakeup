import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, AdminUser?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AdminUser?> {
  late final AuthRepository _repository;

  @override
  Future<AdminUser?> build() async {
    _repository = ref.read(authRepositoryProvider);
    return _repository.getCurrentUser();
  }

  Future<void> login(String id, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _repository.login(id: id, password: password);
    });
    if (state.hasError) {
      throw state.error!;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncData(null);
  }
}
