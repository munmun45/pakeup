import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? initError;
  try {
    await bootstrapSupabase();
  } catch (e) {
    initError = e.toString();
  }

  runApp(ProviderScope(child: PakeUpStoreApp(initError: initError)));
}
