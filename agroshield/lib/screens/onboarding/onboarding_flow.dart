import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/prefs_keys.dart';
import '../../models/onboarding_data.dart';
import '../../providers/alert_radius_provider.dart';
import '../../providers/farm_location_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/farm_profile_service.dart';
import '../../app_shell.dart';
import 'ob1_language.dart';
import 'ob2_signin.dart';
import 'ob3_farm_location.dart';
import 'ob4_crop_picker.dart';
import 'ob5_farm_size.dart';
import 'ob6_notifications.dart';

// Single stateful widget owns OnboardingData; passes callbacks down.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _data = OnboardingData();
  final PageController _pageController = PageController();

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _prev() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _complete() async {
    // Save all collected data
    await FarmProfileService().saveProfile(_data.toMap());

    // Mark onboarding done
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.onboardingComplete, true);
    await prefs.setString(PrefsKeys.language, _data.language);
    await prefs.setBool(PrefsKeys.notificationGranted, _data.notificationGranted);

    if (!mounted) return;

    // Sync providers so AppShell screens open with the correct values
    // immediately — without this, the ProviderScope overrides set in main()
    // still hold the pre-onboarding defaults ('en', 50.0, null/null).
    ref.read(languageProvider.notifier).state = _data.language;
    ref.read(alertRadiusProvider.notifier).state = _data.alertRadiusKm;
    ref.read(farmLocationProvider.notifier).state =
        FarmLocation(lat: _data.farmLat, lng: _data.farmLng);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar during onboarding — full-bleed screens
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // navigated by buttons only
        children: [
          Ob1Language(
            onSelect: (lang) {
              setState(() => _data.language = lang);
              _next();
            },
          ),
          Ob2SignIn(
            language: _data.language,
            onBack: _prev,
            onComplete: (authType) {
              _data.authType = authType;
              _next();
            },
          ),
          Ob3FarmLocation(
            language: _data.language,
            onBack: _prev,
            onConfirm: (lat, lng) async {
              _data.farmLat = lat;
              _data.farmLng = lng;
              // Write direct keys so Screen 6 FCM registration can read them
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble(PrefsKeys.farmLat, lat);
              await prefs.setDouble(PrefsKeys.farmLng, lng);
              _next();
            },
          ),
          Ob4CropPicker(
            language: _data.language,
            onBack: _prev,
            onConfirm: (crops) {
              _data.crops = crops;
              _next();
            },
          ),
          Ob5FarmSize(
            language: _data.language,
            onBack: _prev,
            onConfirm: (acres, radius) async {
              _data.farmSizeAcres = acres;
              _data.alertRadiusKm = radius;
              // Write direct key so Screen 6 FCM registration can read it
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble(PrefsKeys.alertRadiusKm, radius);
              _next();
            },
          ),
          Ob6Notifications(
            language: _data.language,
            onBack: _prev,
            onComplete: (granted) {
              _data.notificationGranted = granted;
              _complete();
            },
          ),
        ],
      ),
    );
  }
}
