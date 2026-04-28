import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Feature 2: log organic app open on every cold start.
  // app_opened_from_notification is logged in Feature 9 (FCM tap handler).
  await FirebaseAnalytics.instance.logEvent(
    name: 'app_opened_organic',
    parameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
  );

  runApp(const ProviderScope(child: AgroShieldApp()));
}
