/// Canonical SharedPreferences key constants.
///
/// All reads and writes to SharedPreferences must use these constants.
/// Never use raw string literals — a typo silently returns null.
class PrefsKeys {
  PrefsKeys._();

  // ── User & auth ────────────────────────────────────────────────────────────
  static const String language          = 'language';
  static const String authType          = 'auth_type';
  static const String deviceId          = 'device_id';

  // ── Farm location (individual keys — used by Home, Fire Map, notifications) ─
  static const String farmLat           = 'farm_lat';
  static const String farmLng           = 'farm_lng';
  static const String alertRadiusKm     = 'alert_radius_km';

  // ── Farm profile blob (crops + farmSizeAcres + farmLat/Lng for guest path) ──
  static const String farmProfile       = 'farm_profile';

  // ── Notification state ────────────────────────────────────────────────────
  static const String notificationGranted = 'notification_granted';

  // ── Home screen offline cache ─────────────────────────────────────────────
  static const String homeFireCount        = 'home_fire_count';
  static const String homeNearestDistance  = 'home_nearest_distance';
  static const String homeNearestDirection = 'home_nearest_direction';
  static const String homeFireTimestamp    = 'home_fire_timestamp';

  // ── UI state ───────────────────────────────────────────────────────────────
  static const String settingsTooltipShown = 'settings_tooltip_shown';

  // ── Onboarding ─────────────────────────────────────────────────────────────
  static const String onboardingComplete = 'onboarding_complete';
}
