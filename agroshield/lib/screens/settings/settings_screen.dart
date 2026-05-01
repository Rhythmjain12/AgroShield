import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../screens/onboarding/ob3_farm_location.dart';
import '../../screens/onboarding/ob4_crop_picker.dart';
import '../../screens/onboarding/ob5_farm_size.dart';
import '../../screens/onboarding/onboarding_flow.dart';
import '../../config/prefs_keys.dart';
import '../../providers/language_provider.dart';
import '../../services/farm_profile_service.dart';
import '../../theme/app_theme.dart';

// Mirrors the crop IDs in ob4_crop_picker.dart
const _cropNameMap = {
  'cotton': 'Cotton',
  'wheat': 'Wheat',
  'soybean': 'Soybean',
  'rice': 'Rice',
  'sugarcane': 'Sugarcane',
  'maize': 'Maize',
  'groundnut': 'Groundnut',
  'onion': 'Onion',
  'other': 'Other',
};

// ══════════════════════════════════════════════════════════════════════════════
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _loading = true;
  bool _navigating = false; // prevents double-tap pushing sub-screen twice

  String _language = 'en';
  List<String> _crops = [];
  double? _farmLat;
  double? _farmLng;
  double _farmSizeAcres = 3.0;
  double _alertRadiusKm = 50.0;
  bool _notificationGranted = false;
  bool _isGuest = true;
  String? _displayName;
  String? _email;

  final _profileService = FarmProfileService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Load all state from SharedPrefs + FarmProfileService + Auth ────────────

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profile = await _profileService.loadProfile();
      final user = FirebaseAuth.instance.currentUser;
      final authType = prefs.getString(PrefsKeys.authType);

      if (!mounted) return;
      setState(() {
        _language = prefs.getString(PrefsKeys.language) ?? 'en';
        _farmLat = prefs.getDouble(PrefsKeys.farmLat);
        _farmLng = prefs.getDouble(PrefsKeys.farmLng);
        _alertRadiusKm = prefs.getDouble(PrefsKeys.alertRadiusKm) ?? 50.0;
        _notificationGranted = prefs.getBool(PrefsKeys.notificationGranted) ?? false;
        _crops = List<String>.from((profile?['crops'] as List?) ?? []);
        _farmSizeAcres =
            (profile?['farmSizeAcres'] as num?)?.toDouble() ?? 3.0;
        _isGuest = user == null || authType == 'guest';
        _displayName = user?.displayName;
        _email = user?.email;
        _loading = false;
      });

      // Sync provider so any downstream watcher reflects the persisted value.
      ref.read(languageProvider.notifier).state = _language;
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Display value helpers ──────────────────────────────────────────────────

  String get _cropsDisplay {
    if (_crops.isEmpty) return 'None selected';
    final names = _crops.map((id) => _cropNameMap[id] ?? id).toList();
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  String get _locationDisplay {
    if (_farmLat == null || _farmLng == null) return 'Not set';
    return '${_farmLat!.toStringAsFixed(4)}, ${_farmLng!.toStringAsFixed(4)}';
  }

  String get _sizeRadiusDisplay {
    final acres = _farmSizeAcres < 10
        ? _farmSizeAcres.toStringAsFixed(1)
        : _farmSizeAcres.round().toString();
    return '$acres acres · ${_alertRadiusKm.round()} km';
  }

  // ── Sub-screen openers ─────────────────────────────────────────────────────

  void _openCropPicker() {
    if (_navigating) return;
    setState(() => _navigating = true);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Ob4CropPicker(
        language: _language,
        onBack: () => Navigator.of(context).pop(),
        onConfirm: (crops) async {
          await _profileService.saveProfile({'crops': crops});
          if (mounted) {
            setState(() => _crops = crops);
            Navigator.of(context).pop();
          }
        },
      ),
    )).then((_) {
      if (mounted) setState(() => _navigating = false);
    });
  }

  void _openFarmLocation() {
    if (_navigating) return;
    setState(() => _navigating = true);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Ob3FarmLocation(
        language: _language,
        onBack: () => Navigator.of(context).pop(),
        onConfirm: (lat, lng) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble(PrefsKeys.farmLat, lat);
          await prefs.setDouble(PrefsKeys.farmLng, lng);
          await _profileService.saveProfile({'farmLat': lat, 'farmLng': lng});
          if (mounted) {
            setState(() {
              _farmLat = lat;
              _farmLng = lng;
            });
            Navigator.of(context).pop();
          }
        },
      ),
    )).then((_) {
      if (mounted) setState(() => _navigating = false);
    });
  }

  void _openFarmSize() {
    if (_navigating) return;
    setState(() => _navigating = true);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Ob5FarmSize(
        language: _language,
        onBack: () => Navigator.of(context).pop(),
        onConfirm: (acres, radiusKm) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble(PrefsKeys.alertRadiusKm, radiusKm);
          await _profileService.saveProfile({'farmSizeAcres': acres});
          if (mounted) {
            setState(() {
              _farmSizeAcres = acres;
              _alertRadiusKm = radiusKm;
            });
            Navigator.of(context).pop();
          }
        },
      ),
    )).then((_) {
      if (mounted) setState(() => _navigating = false);
    });
  }

  // ── Language ───────────────────────────────────────────────────────────────

  Future<void> _setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.language, lang);
    if (mounted) {
      setState(() => _language = lang);
      ref.read(languageProvider.notifier).state = lang;
    }
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      final status = await Permission.notification.request();
      final granted = status.isGranted;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PrefsKeys.notificationGranted, granted);
      if (mounted) setState(() => _notificationGranted = granted);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PrefsKeys.notificationGranted, false);
      if (mounted) setState(() => _notificationGranted = false);
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingFlow()),
        (_) => false,
      );
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bgTopBar,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.fraunces(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Farm Profile ───────────────────────────────────────
                  const _SectionHeader('FARM PROFILE'),
                  _EditableRow(
                    icon: Icons.grass_outlined,
                    label: 'Crops',
                    value: _cropsDisplay,
                    onTap: _openCropPicker,
                  ),
                  const _RowDivider(),
                  _EditableRow(
                    icon: Icons.location_on_outlined,
                    label: 'Farm location',
                    value: _locationDisplay,
                    onTap: _openFarmLocation,
                  ),
                  const _RowDivider(),
                  _EditableRow(
                    icon: Icons.radar_outlined,
                    label: 'Farm size & alert radius',
                    value: _sizeRadiusDisplay,
                    onTap: _openFarmSize,
                  ),

                  // ── App Preferences ────────────────────────────────────
                  const _SectionHeader('APP PREFERENCES'),
                  _LanguageRow(
                    currentLang: _language,
                    onSelect: _setLanguage,
                  ),
                  const _RowDivider(),
                  _NotificationRow(
                    granted: _notificationGranted,
                    onToggle: _toggleNotifications,
                  ),

                  // ── Account ────────────────────────────────────────────
                  const _SectionHeader('ACCOUNT'),
                  if (_isGuest)
                    const _GuestRow()
                  else ...[
                    _AccountRow(
                      name: _displayName ?? 'Google User',
                      email: _email ?? '',
                    ),
                    const _RowDivider(indent: 0),
                    _SignOutRow(onSignOut: _signOut),
                  ],

                  // ── About ──────────────────────────────────────────────
                  const _SectionHeader('ABOUT'),
                  const _InfoRow(
                    icon: Icons.info_outline,
                    label: 'App version',
                    value: '1.0.0',
                  ),
                  const _RowDivider(),
                  const _InfoRow(
                    icon: Icons.source_outlined,
                    label: 'Data sources',
                    value: 'NASA FIRMS · Tomorrow.io · Gemini AI',
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Section header — slim label row
// ══════════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 6),
      child: Text(
        label,
        style: GoogleFonts.fraunces(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tappable row: icon + label on left, value + chevron on right
// ══════════════════════════════════════════════════════════════════════════════
class _EditableRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _EditableRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.04),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.textMuted),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.textSub,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Language row — EN / HI chip pair
// ══════════════════════════════════════════════════════════════════════════════
class _LanguageRow extends StatelessWidget {
  final String currentLang;
  final void Function(String) onSelect;

  const _LanguageRow({required this.currentLang, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.language_outlined,
              size: 20, color: AppTheme.textMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Language',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          _LangChip(
            label: 'EN',
            active: currentLang == 'en',
            onTap: () => onSelect('en'),
          ),
          const SizedBox(width: 8),
          _LangChip(
            label: 'HI',
            active: currentLang == 'hi',
            onTap: () => onSelect('hi'),
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LangChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.accent.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppTheme.accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? AppTheme.accent : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Notification row — label + Material 3 Switch
// ══════════════════════════════════════════════════════════════════════════════
class _NotificationRow extends StatelessWidget {
  final bool granted;
  final Future<void> Function(bool) onToggle;

  const _NotificationRow({required this.granted, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 6, top: 4, bottom: 4),
      child: Row(
        children: [
          Icon(
            granted
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            size: 20,
            color: AppTheme.textMuted,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Fire notifications',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          Switch(
            value: granted,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Account rows
// ══════════════════════════════════════════════════════════════════════════════
class _AccountRow extends StatelessWidget {
  final String name;
  final String email;

  const _AccountRow({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withValues(alpha: 0.12),
              border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.person_outline,
                color: AppTheme.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestRow extends StatelessWidget {
  const _GuestRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(Icons.person_outline,
                color: Colors.white.withValues(alpha: 0.35), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guest mode',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Data stored on this device only',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignOutRow extends StatelessWidget {
  final VoidCallback onSignOut;
  const _SignOutRow({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSignOut,
        splashColor: AppTheme.dangerRed.withValues(alpha: 0.06),
        highlightColor: AppTheme.dangerRed.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.logout_outlined,
                  size: 20,
                  color: AppTheme.dangerRed.withValues(alpha: 0.8)),
              const SizedBox(width: 14),
              Text(
                'Sign out',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.dangerRed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Read-only info row (About section)
// ══════════════════════════════════════════════════════════════════════════════
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Intra-section divider
// ══════════════════════════════════════════════════════════════════════════════
class _RowDivider extends StatelessWidget {
  /// Left indent in logical pixels.
  /// Default 50 aligns under row text (left-pad 16 + icon 20 + gap 14).
  /// Pass 0 for full-width (used in Account section where avatar width differs).
  final double indent;
  const _RowDivider({this.indent = 50});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: const Color(0x14FFFFFF),
      indent: indent,
    );
  }
}
