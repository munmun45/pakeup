String buildStaticMapUrl({
  required String apiKey,
  required double latitude,
  required double longitude,
  required int width,
  required int height,
  required int zoom,
  bool showMarker = false,
}) {
  final w = width.clamp(100, 640).toInt();
  final h = height.clamp(100, 640).toInt();
  final marker = showMarker
      ? '&markers=color:0xe91e8c%7C$latitude,$longitude'
      : '';
  return 'https://maps.googleapis.com/maps/api/staticmap'
      '?center=$latitude,$longitude'
      '&zoom=$zoom'
      '&size=${w}x$h'
      '&scale=2'
      '&maptype=roadmap'
      '&style=feature:poi|visibility:simplified'
      '&style=feature:transit|visibility:off'
      '$marker'
      '&key=$apiKey';
}
