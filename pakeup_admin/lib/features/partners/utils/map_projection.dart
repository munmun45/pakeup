import 'dart:math' as math;

class MapProjection {
  MapProjection._();

  static const _tileSize = 256.0;

  static double _latToMercatorY(double lat) {
    final siny = math.sin(lat * math.pi / 180).clamp(-0.9999, 0.9999);
    return math.log((1 + siny) / (1 - siny)) / 2;
  }

  static double _mercatorYToLat(double y) {
    return 180 / math.pi * (2 * math.atan(math.exp(y)) - math.pi / 2);
  }

  static ({double lat, double lng}) pixelToLatLng({
    required double x,
    required double y,
    required double centerLat,
    required double centerLng,
    required int zoom,
    required double width,
    required double height,
  }) {
    final scale = _tileSize * math.pow(2, zoom);
    final centerX = (centerLng + 180) / 360 * scale;
    final centerY =
        (0.5 - _latToMercatorY(centerLat) / (2 * math.pi)) * scale;

    final pointX = centerX + (x - width / 2);
    final pointY = centerY + (y - height / 2);

    final lng = pointX / scale * 360 - 180;
    final lat = _mercatorYToLat(math.pi * (1 - 2 * pointY / scale));
    return (lat: lat, lng: lng);
  }

  static ({double lat, double lng}) panOffsetToCenter({
    required double panDx,
    required double panDy,
    required double centerLat,
    required double centerLng,
    required int zoom,
    required double width,
    required double height,
  }) {
    return pixelToLatLng(
      x: width / 2 - panDx,
      y: height / 2 - panDy,
      centerLat: centerLat,
      centerLng: centerLng,
      zoom: zoom,
      width: width,
      height: height,
    );
  }
}

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
