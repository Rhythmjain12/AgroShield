import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

const _strings = {
  'en': {
    'title': 'Sign in to protect\nyour farm data',
    'subtitle': 'Back up your settings. Never lose your farm profile.',
    'google': 'Continue with Google',
    'guest': 'Continue without account',
    'guest_note': 'Farm data saved on this device only',
  },
  'hi': {
    'title': 'अपना डेटा सुरक्षित करें',
    'subtitle': 'सेटिंग्स का बैकअप लें। फार्म प्रोफाइल कभी न खोएं।',
    'google': 'Google से जारी रखें',
    'guest': 'बिना खाते के जारी रखें',
    'guest_note': 'डेटा केवल इस डिवाइस पर',
  },
};

class Ob2SignIn extends StatefulWidget {
  final String language;
  final void Function(String authType) onComplete;

  const Ob2SignIn({super.key, required this.language, required this.onComplete});

  @override
  State<Ob2SignIn> createState() => _Ob2SignInState();
}

class _Ob2SignInState extends State<Ob2SignIn> {
  bool _loading = false;
  String? _error;
  final _authService = AuthService();

  Map<String, String> get _s => _strings[widget.language] ?? _strings['en']!;

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _authService.signInWithGoogle();
      await FirebaseAnalytics.instance.logEvent(name: 'app_opened_organic',
          parameters: {'auth_type': 'google', 'timestamp': DateTime.now().millisecondsSinceEpoch});
      widget.onComplete('google');
    } catch (e) {
      setState(() {
        _error = widget.language == 'hi'
            ? 'साइन-इन विफल। पुनः प्रयास करें।'
            : 'Sign-in failed. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() { _loading = true; _error = null; });
    await _authService.continueAsGuest();
    await FirebaseAnalytics.instance.logEvent(name: 'app_opened_organic',
        parameters: {'auth_type': 'guest', 'timestamp': DateTime.now().millisecondsSinceEpoch});
    widget.onComplete('guest');
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
              const SizedBox(height: 48),

              // Step indicator
              _StepIndicator(current: 1, total: 6),

              const SizedBox(height: 36),

              // Icon mark
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.shield_outlined,
                    color: AppTheme.accent, size: 26),
              ),

              const SizedBox(height: 22),

              Text(
                _s['title']!,
                style: GoogleFonts.fraunces(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 10),
              Text(
                _s['subtitle']!,
                style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: AppTheme.textSub,
                    height: 1.5),
              ),

              const Spacer(),

              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.dangerRed.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.dangerRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: AppTheme.dangerRed))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_loading)
                const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.accent))
              else
                Column(
                  children: [
                    // Google button
                    GestureDetector(
                      onTap: _googleSignIn,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.bgNav,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: const Center(
                                child: Text('G',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4285F4))),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _s['google']!,
                              style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // CTA gradient button for guest
                    GestureDetector(
                      onTap: _continueAsGuest,
                      child: Container(
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accentDark],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            _s['guest']!,
                            style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.bg),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline,
                            size: 13, color: AppTheme.textMuted),
                        const SizedBox(width: 5),
                        Text(
                          _s['guest_note']!,
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared step indicator ──────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current; // 0-based
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i <= current;
        final isCurrent = i == current;
        return Container(
          margin: const EdgeInsets.only(right: 6),
          width: isCurrent ? 24 : 8,
          height: 4,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accent
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
