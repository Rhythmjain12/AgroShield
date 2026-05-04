import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_shell.dart';
import '../../config/prefs_keys.dart';
import '../../models/weather_context.dart';
import '../../providers/language_provider.dart';
import '../../providers/weather_context_provider.dart';
import '../../screens/settings/settings_screen.dart';
import '../../theme/app_theme.dart';
import '../../utils/geo_utils.dart';

// ── Banner fire status ─────────────────────────────────────────────────────
enum _FireStatus { loading, safe, warning, danger }

class _NearbyFire {
  final String id;
  final double distanceKm;
  final String direction;
  final double frp;
  final DateTime detectedAt;

  const _NearbyFire({
    required this.id,
    required this.distanceKm,
    required this.direction,
    required this.frp,
    required this.detectedAt,
  });
}

// ══════════════════════════════════════════════════════════════════════════
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  double? _farmLat;
  double? _farmLng;
  double _alertRadius = 50.0;
  String _language = 'en';

  List<_NearbyFire> _fires = [];
  bool _isLoading = true;
  DateTime? _lastUpdated;

  bool _isOffline = false;
  bool _showNotifBanner = false;

  int _cachedFireCount = 0;
  double? _cachedNearestDist;
  String? _cachedNearestDir;
  DateTime? _cachedTimestamp;

  StreamSubscription<QuerySnapshot>? _firestoreSub;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  OverlayEntry? _tooltipOverlay;
  Timer? _tooltipTimer;
  Timer? _clockTimer;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _init();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _clockTimer?.cancel();
    _firestoreSub?.cancel();
    _connectivitySub?.cancel();
    _tooltipTimer?.cancel();
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(PrefsKeys.farmLat);
    final lng = prefs.getDouble(PrefsKeys.farmLng);
    final radius = prefs.getDouble(PrefsKeys.alertRadiusKm) ?? 50.0;
    final notifGranted = prefs.getBool(PrefsKeys.notificationGranted) ?? true;

    final cachedCount = prefs.getInt(PrefsKeys.homeFireCount) ?? 0;
    final cachedDist = prefs.getDouble(PrefsKeys.homeNearestDistance);
    final cachedDir = prefs.getString(PrefsKeys.homeNearestDirection);
    final cachedTs = prefs.getInt(PrefsKeys.homeFireTimestamp);

    if (mounted) {
      setState(() {
        _farmLat = lat;
        _farmLng = lng;
        _alertRadius = radius;
        _showNotifBanner = !notifGranted;
        _cachedFireCount = cachedCount;
        _cachedNearestDist = cachedDist;
        _cachedNearestDir = cachedDir;
        _cachedTimestamp = cachedTs != null
            ? DateTime.fromMillisecondsSinceEpoch(cachedTs)
            : null;
      });
    }

    await _checkConnectivity();
    _setupConnectivityListener();

    if (lat != null && lng != null) {
      _setupFirestoreListener();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }

    final tooltipShown = prefs.getBool(PrefsKeys.settingsTooltipShown) ?? false;
    if (!tooltipShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSettingsTooltip(prefs);
      });
    }
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _isOffline = result == ConnectivityResult.none);
    }
  }

  void _setupConnectivityListener() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      final offline = result == ConnectivityResult.none;
      if (mounted) setState(() => _isOffline = offline);
      if (!offline && _firestoreSub == null && _farmLat != null) {
        _setupFirestoreListener();
      }
    });
  }

  void _setupFirestoreListener() {
    _firestoreSub = FirebaseFirestore.instance
        .collection('fires')
        .snapshots()
        .listen(_onFiresSnapshot,
            onError: (_) {
          if (mounted) setState(() {
            _isLoading = false;
            _lastUpdated ??= DateTime.now();
          });
        });
  }

  void _onFiresSnapshot(QuerySnapshot snapshot) {
    if (!mounted || _farmLat == null || _farmLng == null) return;

    final nearby = <_NearbyFire>[];
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final dist = haversineKm(_farmLat!, _farmLng!, lat, lng);
      if (dist > _alertRadius) continue;

      nearby.add(_NearbyFire(
        id: doc.id,
        distanceKm: dist,
        direction: bearingDirection(_farmLat!, _farmLng!, lat, lng),
        frp: (data['frp'] as num?)?.toDouble() ?? 0,
        detectedAt: (data['detectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ));
    }
    nearby.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final now = DateTime.now();
    _persistFireCache(nearby, now);

    setState(() {
      _fires = nearby;
      _isLoading = false;
      _lastUpdated = now;
    });
  }

  Future<void> _persistFireCache(List<_NearbyFire> fires, DateTime ts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PrefsKeys.homeFireCount, fires.length);
    await prefs.setInt(PrefsKeys.homeFireTimestamp, ts.millisecondsSinceEpoch);
    if (fires.isNotEmpty) {
      await prefs.setDouble(PrefsKeys.homeNearestDistance, fires.first.distanceKm);
      await prefs.setString(PrefsKeys.homeNearestDirection, fires.first.direction);
    } else {
      await prefs.remove(PrefsKeys.homeNearestDistance);
      await prefs.remove(PrefsKeys.homeNearestDirection);
    }
    _cachedFireCount = fires.length;
    _cachedNearestDist = fires.isNotEmpty ? fires.first.distanceKm : null;
    _cachedNearestDir = fires.isNotEmpty ? fires.first.direction : null;
    _cachedTimestamp = ts;
  }

  void _showSettingsTooltip(SharedPreferences prefs) {
    prefs.setBool(PrefsKeys.settingsTooltipShown, true);
    _tooltipOverlay = OverlayEntry(
      builder: (ctx) => _SettingsTooltipOverlay(
        onDismiss: _dismissTooltip,
        language: _language,
      ),
    );
    Overlay.of(context).insert(_tooltipOverlay!);
    _tooltipTimer = Timer(const Duration(seconds: 5), _dismissTooltip);
  }

  void _dismissTooltip() {
    _tooltipTimer?.cancel();
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  void _switchTab(int index) =>
      ref.read(activeTabProvider.notifier).state = index;

  _FireStatus get _fireStatus {
    if (_isLoading) return _FireStatus.loading;
    final count = _isOffline ? _cachedFireCount : _fires.length;
    if (count == 0) return _FireStatus.safe;
    if (count == 1) return _FireStatus.warning;
    return _FireStatus.danger;
  }

  int get _displayFireCount => _isOffline ? _cachedFireCount : _fires.length;
  double? get _displayNearestDist =>
      _isOffline ? _cachedNearestDist : (_fires.isNotEmpty ? _fires.first.distanceKm : null);
  String? get _displayNearestDir =>
      _isOffline ? _cachedNearestDir : (_fires.isNotEmpty ? _fires.first.direction : null);

  String _timeAgo(DateTime? dt) {
    if (dt == null) return _language == 'hi' ? 'कभी नहीं' : 'Never';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return _language == 'hi' ? 'अभी' : 'Just now';
    if (diff.inMinutes < 60) {
      return _language == 'hi' ? '${diff.inMinutes} मिनट पहले' : '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return _language == 'hi' ? '${diff.inHours} घंटे पहले' : '${diff.inHours}h ago';
    }
    return _language == 'hi' ? '${diff.inDays} दिन पहले' : '${diff.inDays}d ago';
  }

  // ══════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    _language = ref.watch(languageProvider);
    final weather = ref.watch(weatherContextProvider);
    final isHi = _language == 'hi';

    return Container(
      color: AppTheme.bg,
      child: Column(
        children: [
          // ── Topbar (gradient, outside SafeArea so gradient reaches status bar)
          _buildTopbar(),

          // ── System banners inside SafeArea
          if (_isOffline) _buildOfflineBanner(isHi),
          if (_showNotifBanner && !_isOffline) _buildNotifBanner(isHi),

          // ── Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFireBanner(isHi),
                  const SizedBox(height: 10),
                  if (weather != null) _buildStatsRow(weather, isHi),
                  if (weather != null) const SizedBox(height: 10),
                  _buildWeatherStrip(weather, isHi),
                  const SizedBox(height: 10),
                  _buildAdvisorCTA(isHi),
                  const SizedBox(height: 14),
                  if (_lastUpdated != null || _isOffline) _buildTimestamp(isHi),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Topbar ────────────────────────────────────────────────────────────
  Widget _buildTopbar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.bgTopBar, AppTheme.bg],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(
            children: [
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                      text: 'Agro',
                      style: GoogleFonts.fraunces(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.02 * 21)),
                  TextSpan(
                      text: 'Shield',
                      style: GoogleFonts.fraunces(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accent,
                          letterSpacing: -0.02 * 21)),
                ]),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  child: Icon(Icons.settings_outlined,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Offline banner ────────────────────────────────────────────────────
  Widget _buildOfflineBanner(bool isHi) {
    return Container(
      color: const Color(0xFF263238),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isHi
                  ? 'आखिरी बार ${_timeAgo(_cachedTimestamp)} — कोई कनेक्शन नहीं'
                  : 'Last updated ${_timeAgo(_cachedTimestamp)} — no connection',
              style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ── Notification banner ───────────────────────────────────────────────
  Widget _buildNotifBanner(bool isHi) {
    return Container(
      color: AppTheme.amberStrip,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_outlined,
              color: AppTheme.amberText, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isHi
                  ? 'आग की सूचना पाने के लिए नोटिफिकेशन चालू करें'
                  : 'Enable notifications to get fire alerts',
              style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.amberText,
                  fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: openAppSettings,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.amberText,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(isHi ? 'सेटिंग' : 'Settings',
                style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          GestureDetector(
            onTap: () => setState(() => _showNotifBanner = false),
            child: const Icon(Icons.close,
                size: 16, color: AppTheme.amberText),
          ),
        ],
      ),
    );
  }

  // ── Fire hero banner ──────────────────────────────────────────────────
  Widget _buildFireBanner(bool isHi) {
    final status = _fireStatus;
    final count = _displayFireCount;
    final nearestDist = _displayNearestDist;
    final nearestDir = _displayNearestDir;

    final List<Color> gradColors;
    final String eyebrow;
    final String headline;
    final String sub;
    final String ghostChar;
    final Color pillColor;
    final bool animating;

    switch (status) {
      case _FireStatus.loading:
        gradColors = [const Color(0xFF1A4A22), const Color(0xFF0F2E14)];
        eyebrow = isHi ? 'आग की स्थिति जाँची जा रही है' : 'Checking fire status';
        headline = isHi ? 'जाँच हो रही है…' : 'Checking…';
        sub = '';
        ghostChar = '🛡';
        pillColor = AppTheme.accent;
        animating = false;
      case _FireStatus.safe:
        gradColors = [
          const Color(0xFF1A4A22), const Color(0xFF2D7A3A),
          const Color(0xFF1F5C28), const Color(0xFF0F2E14),
        ];
        eyebrow = isHi
            ? 'आग की स्थिति · ${_alertRadius.toInt()} किमी दायरा'
            : 'Fire status · ${_alertRadius.toInt()}km radius';
        headline = isHi ? 'कोई आग नहीं\nमिली' : 'No fires\ndetected';
        sub = isHi ? 'आपका खेत आज सुरक्षित है' : 'Your farm is safe today';
        ghostChar = '🛡';
        pillColor = AppTheme.accent;
        animating = false;
      case _FireStatus.warning:
        gradColors = [
          const Color(0xFF4A2A0A), const Color(0xFF8B4A0A),
          const Color(0xFF6B3508), const Color(0xFF2E1505),
        ];
        eyebrow = isHi
            ? 'आग अलर्ट · ${nearestDist?.toStringAsFixed(0) ?? '?'} किमी'
            : 'Fire alert · ${nearestDist?.toStringAsFixed(0) ?? '?'}km away';
        headline = isHi ? 'आग मिली\nआसपास' : 'Fire detected\nnearby';
        sub = isHi
            ? 'सावधानी बरतें — ${_dirHi(nearestDir)} दिशा में'
            : 'Take precautions — ${nearestDir ?? '?'} direction';
        ghostChar = '🔥';
        pillColor = AppTheme.amberText;
        animating = true;
      case _FireStatus.danger:
        gradColors = [
          const Color(0xFF4A0F0F), const Color(0xFF8B1F1F),
          const Color(0xFF6B1515), const Color(0xFF2E0A0A),
        ];
        eyebrow = isHi
            ? '$count आग पास में — अलर्ट'
            : '$count fires nearby — Alert';
        headline = isHi ? 'खतरा —\nकई आग' : 'Danger —\nmultiple fires';
        sub = isHi
            ? 'नज़दीकी: ${nearestDist?.toStringAsFixed(0) ?? '?'} किमी ${_dirHi(nearestDir)}'
            : 'Nearest: ${nearestDist?.toStringAsFixed(0) ?? '?'}km $nearestDir';
        ghostChar = '🔥';
        pillColor = AppTheme.dangerRed;
        animating = true;
    }

    final ts = _isOffline ? _cachedTimestamp : _lastUpdated;
    final pillText = status == _FireStatus.loading
        ? (isHi ? 'लोड हो रहा है…' : 'Loading…')
        : (isHi
            ? 'लाइव · ${_timeAgo(ts)} अपडेट'
            : 'Live · Updated ${_timeAgo(ts)}');

    Widget banner = GestureDetector(
      onTap: status != _FireStatus.loading ? () => _switchTab(1) : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 180),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradColors,
            stops: gradColors.length == 4
                ? const [0, 0.4, 0.7, 1.0]
                : const [0, 1.0],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Stack(
          children: [
            // Ghost watermark icon
            Positioned(
              right: -8,
              bottom: -16,
              child: Text(ghostChar,
                  style: TextStyle(
                      fontSize: 100,
                      color: Colors.white.withValues(alpha: 0.07))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Eyebrow
                  Text(eyebrow,
                      style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.5),
                          letterSpacing: 0.12 * 10)),
                  const SizedBox(height: 8),
                  // Headline
                  if (status == _FireStatus.loading)
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  else
                    Text(
                      headline,
                      style: GoogleFonts.fraunces(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.05,
                          letterSpacing: -0.02 * 30),
                    ),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(sub,
                        style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.6))),
                  ],
                  const SizedBox(height: 16),
                  // Pulse pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulseDot(color: pillColor),
                        const SizedBox(width: 6),
                        Text(pillText,
                            style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color:
                                    Colors.white.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (animating) {
      banner = ScaleTransition(scale: _pulse, child: banner);
    }
    return banner;
  }

  // ── Stats row (temp + humidity from weather) ──────────────────────────
  Widget _buildStatsRow(WeatherContext weather, bool isHi) {
    final temp = weather.currentTemp;
    final humidity = weather.humidity;

    final tempBadge = temp > 38
        ? (isHi ? '🌡 बहुत गर्म' : '🌡 Very hot')
        : temp > 32
            ? (isHi ? '🌡 गर्म' : '🌡 Warm')
            : (isHi ? '🌡 सामान्य' : '🌡 Normal');
    final tempBadgeColor = temp > 38
        ? AppTheme.amberText
        : temp > 32
            ? const Color(0xFFF5B53F)
            : AppTheme.accent;

    final humBadge = humidity < 25
        ? (isHi ? '⚠ आग का खतरा' : '⚠ Fire risk')
        : humidity < 40
            ? (isHi ? '⚠ कम नमी' : '⚠ Low humidity')
            : (isHi ? '✓ सामान्य' : '✓ Normal');
    final humBadgeColor = humidity < 25
        ? AppTheme.dangerRed
        : humidity < 40
            ? AppTheme.amberText
            : AppTheme.accent;

    return Row(
      children: [
        Expanded(
            child: _StatCard(
                label: isHi ? 'तापमान' : 'Temp',
                value: '${temp.round()}',
                unit: '°C',
                badge: tempBadge,
                badgeColor: tempBadgeColor)),
        const SizedBox(width: 9),
        Expanded(
            child: _StatCard(
                label: isHi ? 'नमी' : 'Humidity',
                value: '$humidity',
                unit: '%',
                badge: humBadge,
                badgeColor: humBadgeColor)),
      ],
    );
  }

  // ── Weather strip ──────────────────────────────────────────────────────
  Widget _buildWeatherStrip(dynamic weather, bool isHi) {
    final hasWeather = weather != null;
    final summary = hasWeather
        ? (isHi ? weather.summaryLineHi : weather.summaryLineEn)
        : (isHi ? 'मौसम देखने के लिए टैप करें' : 'Tap to check today\'s conditions');

    return GestureDetector(
      onTap: () => _switchTab(2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          // PERF: blur is expensive on budget Android; remove filter to disable.
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.cloud_outlined,
                      color: AppTheme.accent, size: 18),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHi ? 'आज का मौसम' : "Today's weather",
                        style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.08 * 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppTheme.textSub,
                            fontWeight: FontWeight.w500,
                            height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.25),
                    size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Advisor CTA ───────────────────────────────────────────────────────
  Widget _buildAdvisorCTA(bool isHi) {
    return GestureDetector(
      onTap: () => _switchTab(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.accent, AppTheme.accentDark],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline,
                color: AppTheme.bg, size: 18),
            const SizedBox(width: 9),
            Text(
              isHi ? 'अपने खेत के बारे में पूछें →' : 'Ask about your farm →',
              style: GoogleFonts.dmSans(
                  color: AppTheme.bg,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ── Timestamp ─────────────────────────────────────────────────────────
  Widget _buildTimestamp(bool isHi) {
    final ts = _isOffline ? _cachedTimestamp : _lastUpdated;
    final ago = _timeAgo(ts);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.update, size: 13, color: AppTheme.textMuted),
        const SizedBox(width: 5),
        Text(
          isHi ? 'आग डेटा $ago अपडेट हुआ' : 'Fire data updated $ago',
          style: GoogleFonts.dmSans(
              fontSize: 10,
              color: AppTheme.textMuted,
              letterSpacing: 0.04 * 10),
        ),
      ],
    );
  }

  // ── Hindi direction helper ────────────────────────────────────────────
  String _dirHi(String? dir) {
    const map = {
      'N': 'उत्तर', 'NE': 'उत्तर-पूर्व', 'E': 'पूर्व',
      'SE': 'दक्षिण-पूर्व', 'S': 'दक्षिण', 'SW': 'दक्षिण-पश्चिम',
      'W': 'पश्चिम', 'NW': 'उत्तर-पश्चिम',
    };
    return map[dir] ?? dir ?? '';
  }
}

// ── Frosted stat card ─────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String badge;
  final Color badgeColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.badge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        // PERF: blur is expensive on budget Android; set sigmaX/Y to 0 to disable.
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x2E6FCF80), Color(0x1A43A853)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x406FCF80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.08 * 10),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                      text: value,
                      style: GoogleFonts.fraunces(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.02 * 26)),
                  TextSpan(
                      text: unit,
                      style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: AppTheme.textMuted)),
                ]),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: badgeColor.withValues(alpha: 0.30)),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: badgeColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated pulse dot ────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 1.0, end: 0.3).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Settings tooltip overlay — shown once on first open, 5s auto-dismiss
// ══════════════════════════════════════════════════════════════════════════
class _SettingsTooltipOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final String language;
  const _SettingsTooltipOverlay({required this.onDismiss, required this.language});

  @override
  State<_SettingsTooltipOverlay> createState() =>
      _SettingsTooltipOverlayState();
}

class _SettingsTooltipOverlayState extends State<_SettingsTooltipOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Gear icon is inside HomeScreen topbar below status bar.
    // Position tooltip just below it.
    final statusBarH = MediaQuery.of(context).padding.top;
    return Positioned(
      top: statusBarH + 52,
      right: 12,
      child: FadeTransition(
        opacity: _opacity,
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: const Size(14, 7),
                  painter: _TrianglePainter(AppTheme.bgTopBar),
                ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgTopBar,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.settings,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        widget.language == 'hi' ? 'सेटिंग्स यहाँ है' : 'Settings is up here',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}
