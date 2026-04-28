class FireContext {
  final String fireId;
  final double distanceKm;
  final double frp;
  final DateTime detectedAt;
  final double lat;
  final double lng;

  const FireContext({
    required this.fireId,
    required this.distanceKm,
    required this.frp,
    required this.detectedAt,
    required this.lat,
    required this.lng,
  });
}
