import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'app_shell.dart';
import 'config/prefs_keys.dart';
import 'firebase_options.dart';
import 'providers/language_provider.dart';
import 'screens/fire_map/fire_map_screen.dart';

// Required top-level handler for background FCM messages.
// The OS shows the notification automatically; no action needed here for MVP.
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

  // Feature 2: log organic app open on every cold start.
  // app_opened_from_notification is logged in _FcmWrapper when a notification tap is detected.
  await FirebaseAnalytics.instance.logEvent(
    name: 'app_opened_organic',
    parameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
  );

  // Read persisted language before runApp so languageProvider starts with the
  // correct value. Without this, Hindi users see a flash of English on cold start
  // when any screen watches languageProvider.
  final prefs = await SharedPreferences.getInstance();
  final savedLanguage = prefs.getString(PrefsKeys.language) ?? 'en';

  runApp(ProviderScope(
    overrides: [
      languageProvider.overrideWith((ref) => savedLanguage),
    ],
    child: const _FcmWrapper(),
  ));
}

// Thin wrapper that lives inside ProviderScope so it can read/write providers.
// Handles all three FCM entry points without modifying app.dart or app_shell.dart.
class _FcmWrapper extends ConsumerStatefulWidget {
  const _FcmWrapper();

  @override
  ConsumerState<_FcmWrapper> createState() => _FcmWrapperState();
}

class _FcmWrapperState extends ConsumerState<_FcmWrapper> {
  @override
  void initState() {
    super.initState();
    _initFcm();
  }

  Future<void> _initFcm() async {
    // Story 1.1: log notification_received when FCM delivers a foreground message.
    FirebaseMessaging.onMessage.listen((message) {
      FirebaseAnalytics.instance.logEvent(
        name: 'notification_received',
        parameters: {
          'fire_id': message.data['fireId'] ?? '',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    });

    // App was in background; user tapped the notification.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // App was fully terminated; user tapped the notification to launch it.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (message.data['type'] != 'fire_alert') return;

    final fireLat = double.tryParse(message.data['fireLat'] ?? '');
    final fireLng = double.tryParse(message.data['fireLng'] ?? '');

    // Story 1.1: log app_opened_from_notification on notification tap.
    FirebaseAnalytics.instance.logEvent(
      name: 'app_opened_from_notification',
      parameters: {
        'fire_id': message.data['fireId'] ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );

    // Switch to Fire Map tab (index 1 in activeTabProvider).
    ref.read(activeTabProvider.notifier).state = 1;

    // Deliver the zoom target to FireMapScreen via provider.
    if (fireLat != null && fireLng != null) {
      ref.read(fireMapTargetProvider.notifier).state = LatLng(fireLat, fireLng);
    }
  }

  @override
  Widget build(BuildContext context) => const AgroShieldApp();
}
