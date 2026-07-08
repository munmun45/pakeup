import 'package:url_launcher/url_launcher.dart';

class ExternalLinks {
  ExternalLinks._();

  static Future<bool> openPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;
    return launchUrl(
      Uri(scheme: 'tel', path: digits),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<bool> openWhatsApp(String whatsapp) async {
    final digits = whatsapp.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;
    final normalized = digits.length == 10 ? '91$digits' : digits;
    return launchUrl(
      Uri.parse('https://wa.me/$normalized'),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<bool> openEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return false;
    return launchUrl(
      Uri(scheme: 'mailto', path: trimmed),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<bool> openMaps({
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final Uri uri;
    if (latitude != null && longitude != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );
    } else if (address != null && address.trim().isNotEmpty) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address.trim())}',
      );
    } else {
      return false;
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
