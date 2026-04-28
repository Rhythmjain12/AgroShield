import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_shell.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'theme/app_theme.dart';

final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_complete') ?? false;
});

class AgroShieldApp extends ConsumerWidget {
  const AgroShieldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'AgroShield',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: ref.watch(onboardingCompleteProvider).when(
            data: (done) => done ? const AppShell() : const OnboardingFlow(),
            loading: () => const _SplashScreen(),
            error: (_, __) => const OnboardingFlow(),
          ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentDark.withValues(alpha: 0.2),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.local_fire_department,
                  size: 36, color: AppTheme.accent),
            ),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: 'Agro',
                    style: GoogleFonts.fraunces(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                TextSpan(
                    text: 'Shield',
                    style: GoogleFonts.fraunces(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accent)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
