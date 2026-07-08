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

  static String? get googleMapsApiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty || key.contains('paste-your')) {
      return null;
    }
    return key;
  }

  static String get supportPhone =>
      _envOrDefault('SUPPORT_PHONE', AppConstants.supportPhone);

  static String get supportWhatsApp =>
      _envOrDefault('SUPPORT_WHATSAPP', AppConstants.supportWhatsApp);

  static String get supportEmail =>
      _envOrDefault('SUPPORT_EMAIL', AppConstants.supportEmail);

  static String _envOrDefault(String key, String fallback) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty || value.contains('paste-your')) {
      return fallback;
    }
    return value;
  }
}
