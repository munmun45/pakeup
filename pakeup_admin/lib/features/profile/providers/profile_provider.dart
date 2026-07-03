import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';

final adminProfileProvider = FutureProvider<AdminProfile>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    throw Exception('Not signed in');
  }

  return ref.read(authRepositoryProvider).getProfile(user.id);
});
