import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stores the active language code ('en' or 'hi').
///
/// Initialised from SharedPreferences in SettingsScreen._load().
/// Any screen that needs live language switching should watch this provider
/// instead of reading the SharedPrefs key only on initState.
final languageProvider = StateProvider<String>((ref) => 'en');
