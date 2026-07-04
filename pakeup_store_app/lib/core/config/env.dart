import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../constants/app_constants.dart';

class Env {
  Env._();

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? AppConstants.supabaseUrl;

  static String get supabaseAnonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty || key.contains('paste-your')) {
      throw StateError(
        'Missing SUPABASE_ANON_KEY.\n'
        'Copy .env.example to .env and paste your anon key from Supabase.',
      );
    }
    return key;
  }
}
