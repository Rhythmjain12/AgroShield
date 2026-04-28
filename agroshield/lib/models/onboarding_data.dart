class OnboardingData {
  String language; // 'en' | 'hi'
  String authType; // 'google' | 'guest'
  double? farmLat;
  double? farmLng;
  List<String> crops;
  double farmSizeAcres;
  double alertRadiusKm;
  bool notificationGranted;

  OnboardingData({
    this.language = 'en',
    this.authType = 'guest',
    this.farmLat,
    this.farmLng,
    this.crops = const [],
    this.farmSizeAcres = 3.0,
    this.alertRadiusKm = 50.0,
    this.notificationGranted = false,
  });

  Map<String, dynamic> toMap() => {
        'language': language,
        'authType': authType,
        'farmLat': farmLat,
        'farmLng': farmLng,
        'crops': crops,
        'farmSizeAcres': farmSizeAcres,
        'alertRadiusKm': alertRadiusKm,
      };
}
