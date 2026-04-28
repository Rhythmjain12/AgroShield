import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class Ob1Language extends StatelessWidget {
  final void Function(String lang) onSelect;

  const Ob1Language({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 52, 32, 0),
              child: Column(
                children: [
                  // App mark
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentDark.withValues(alpha: 0.2),
                      border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.4),
                          width: 1.5),
                    ),
                    child: const Icon(Icons.local_fire_department,
                        color: AppTheme.accent, size: 36),
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
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Choose your language\nभाषा चुनें',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: AppTheme.textSub,
                        height: 1.6),
                  ),
                ],
              ),
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _LangButton(
                    primary: 'English',
                    secondary: 'अंग्रेज़ी',
                    flagEmoji: '🇬🇧',
                    onTap: () => onSelect('en'),
                  ),
                  const SizedBox(height: 14),
                  _LangButton(
                    primary: 'हिंदी',
                    secondary: 'Hindi',
                    flagEmoji: '🇮🇳',
                    onTap: () => onSelect('hi'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _LangButton extends StatefulWidget {
  final String primary;
  final String secondary;
  final String flagEmoji;
  final VoidCallback onTap;

  const _LangButton({
    required this.primary,
    required this.secondary,
    required this.flagEmoji,
    required this.onTap,
  });

  @override
  State<_LangButton> createState() => _LangButtonState();
}

class _LangButtonState extends State<_LangButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 88,
        decoration: BoxDecoration(
          gradient: _pressed
              ? const LinearGradient(
                  colors: [AppTheme.accent, AppTheme.accentDark])
              : null,
          color: _pressed ? null : AppTheme.bgNav,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed
                ? AppTheme.accent
                : AppTheme.accent.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(widget.flagEmoji,
                  style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 18),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.primary,
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _pressed ? AppTheme.bg : Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    widget.secondary,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _pressed
                          ? AppTheme.bg.withValues(alpha: 0.7)
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: _pressed
                    ? AppTheme.bg
                    : AppTheme.accent.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
