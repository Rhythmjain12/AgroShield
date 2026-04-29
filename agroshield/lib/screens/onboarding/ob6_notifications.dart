import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

const _strings = {
  'en': {
    'title': 'Get fire alerts\nwhen it matters',
    'body': 'We\'ll notify you when a fire appears within your alert radius. One alert per new fire — no spam.',
    'allow': 'Enable Fire Alerts',
    'skip': 'Not now',
    'saving': 'Setting up alerts…',
  },
  'hi': {
    'title': 'आग की सूचना\nसमय पर पाएं',
    'body': 'जब आपकी सीमा में आग लगे, हम तुरंत सूचित करेंगे। हर नई आग के लिए एक अलर्ट — कोई स्पैम नहीं।',
    'allow': 'अग्नि अलर्ट चालू करें',
    'skip': 'अभी नहीं',
    'saving': 'अलर्ट सेट हो रहे हैं…',
  },
};

class Ob6Notifications extends StatefulWidget {
  final String language;
  final VoidCallback onBack;
  final void Function(bool granted) onComplete;

  const Ob6Notifications({super.key, required this.language, required this.onBack, required this.onComplete});

  @override
  State<Ob6Notifications> createState() => _Ob6NotificationsState();
}

class _Ob6NotificationsState extends State<Ob6Notifications> {
  bool _loading = false;
  Map<String, String> get _s => _strings[widget.language] ?? _strings['en']!;

  Future<void> _requestPermission() async {
    setState(() => _loading = true);
    final status = await Permission.notification.request();
    final granted = status.isGranted;
    if (granted) await _registerFcmToken();
    widget.onComplete(granted);
  }

  Future<void> _registerFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? '';
      final farmLat = prefs.getDouble('farm_lat');
      final farmLng = prefs.getDouble('farm_lng');
      final radiusKm = prefs.getDouble('alert_radius_km') ?? 50.0;

      await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .set({
        'deviceId': deviceId,
        'fcmToken': token,
        'farmLat': farmLat,
        'farmLng': farmLng,
        'radiusInKm': radiusKm,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Back button + all-filled dots (final step)
              Row(
                children: [
                  _ObBackButton(onTap: widget.onBack),
                  const Spacer(),
                  ...List.generate(6, (i) => Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: i == 5 ? 24 : 8,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )),
                ],
              ),

              const Spacer(),

              // Illustration icon
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.2)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications_outlined,
                          size: 60, color: AppTheme.accent),
                      Positioned(
                        top: 22,
                        right: 22,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: AppTheme.dangerRed,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                              Icons.local_fire_department,
                              size: 14,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                _s['title']!,
                textAlign: TextAlign.center,
                style: GoogleFonts.fraunces(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.5),
              ),

              const SizedBox(height: 16),

              Text(
                _s['body']!,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: AppTheme.textSub,
                    height: 1.6),
              ),

              const Spacer(),

              if (_loading)
                const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent))
              else ...[
                GestureDetector(
                  onTap: _requestPermission,
                  child: Container(
                    height: 62,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppTheme.accent, AppTheme.accentDark]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_active_outlined,
                            size: 22, color: AppTheme.bg),
                        const SizedBox(width: 10),
                        Text(
                          _s['allow']!,
                          style: GoogleFonts.dmSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.bg),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Center(
                  child: TextButton(
                    onPressed: () => widget.onComplete(false),
                    child: Text(
                      _s['skip']!,
                      style: GoogleFonts.dmSans(
                          fontSize: 15, color: AppTheme.textMuted),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ObBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.07),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 14,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
