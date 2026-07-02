import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return supabase;
});
