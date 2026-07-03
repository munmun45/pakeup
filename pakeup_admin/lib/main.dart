import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/platform/webview_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await bootstrapWindowsWebView();

  String? initError;
  try {
    await bootstrapSupabase();
  } catch (e) {
    initError = e.toString();
  }

  runApp(ProviderScope(child: PakeUpAdminApp(initError: initError)));
}
