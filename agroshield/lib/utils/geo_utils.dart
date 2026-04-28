import 'dart:math';

double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}

// Returns compass direction FROM point1 TOWARD point2
String bearingDirection(double lat1, double lng1, double lat2, double lng2) {
  final dLng = (lng2 - lng1) * pi / 180;
  final radLat1 = lat1 * pi / 180;
  final radLat2 = lat2 * pi / 180;
  final y = sin(dLng) * cos(radLat2);
  final x = cos(radLat1) * sin(radLat2) - sin(radLat1) * cos(radLat2) * cos(dLng);
  final bearing = (atan2(y, x) * 180 / pi + 360) % 360;
  return _degToCompass(bearing);
}

// Wind meteorological degrees (where wind comes FROM) → display direction (where it blows TO)
String windDegToDirection(double degrees) => _degToCompass((degrees + 180) % 360);

// Wind display heading (as returned by API) → compass label
String windHeadingToLabel(double degrees) => _degToCompass(degrees);

String _degToCompass(double deg) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return dirs[((deg + 22.5) / 45).floor() % 8];
}
