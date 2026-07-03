/// Parses Google Maps embed iframe/HTML or direct URL.
class PartnerMapUtils {
  PartnerMapUtils._();

  static String? extractEmbedUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final input = raw.trim();

    final srcMatch = RegExp(
      r'''src=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(input);
    if (srcMatch != null) {
      return srcMatch.group(1);
    }

    if (input.startsWith('http://') || input.startsWith('https://')) {
      return input;
    }

    return null;
  }

  static String? resolvePreviewUrl({
    String? googleMapEmbed,
    double? latitude,
    double? longitude,
  }) {
    final embed = extractEmbedUrl(googleMapEmbed);
    if (embed != null && embed.isNotEmpty) return embed;

    if (latitude != null && longitude != null) {
      return 'https://maps.google.com/maps?q=$latitude,$longitude&hl=en&z=15&output=embed';
    }

    return null;
  }

  static String? externalMapsUrl({
    String? googleMapEmbed,
    double? latitude,
    double? longitude,
  }) {
    final embed = extractEmbedUrl(googleMapEmbed);
    if (embed != null) return embed;

    if (latitude != null && longitude != null) {
      return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    }

    return null;
  }

  static double? parseCoordinate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim());
  }

  static String buildEmbedFromCoords(double latitude, double longitude) {
    return '<iframe src="https://maps.google.com/maps?q=$latitude,$longitude&hl=en&z=15&output=embed" '
        'width="600" height="450" style="border:0;" allowfullscreen="" loading="lazy"></iframe>';
  }
}
