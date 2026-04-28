import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

// Placeholder — full implementation in Chat 9.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bgTopBar,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Settings',
            style: GoogleFonts.fraunces(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent.withValues(alpha: 0.08),
                border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.settings_outlined,
                  size: 32, color: AppTheme.accent),
            ),
            const SizedBox(height: 16),
            Text('Settings',
                style: GoogleFonts.fraunces(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text('Crop, location, language — Chat 9',
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
