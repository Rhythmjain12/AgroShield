import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the user's farm coordinates.
///
/// Initialised from SharedPreferences in main() and updated whenever the
/// user changes their farm location in Settings. HomeScreen and FireMapScreen
/// listen to this provider and restart their Firestore subscriptions when it
/// changes, so a location update is reflected immediately without an app restart.
class FarmLocation {
  final double? lat;
  final double? lng;
  const FarmLocation({this.lat, this.lng});
}

final farmLocationProvider = StateProvider<FarmLocation>(
  (ref) => const FarmLocation(),
);
