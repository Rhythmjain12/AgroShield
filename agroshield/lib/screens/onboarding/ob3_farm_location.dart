import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/app_theme.dart';

const _strings = {
  'en': {
    'title': 'Where is your farm?',
    'instruction': 'Drag the pin to your farm location',
    'detecting': 'Finding your location…',
    'confirm': 'Confirm Farm Location',
    'permission_denied': 'Location permission denied. Drag pin manually.',
  },
  'hi': {
    'title': 'आपका खेत कहाँ है?',
    'instruction': 'पिन को अपने खेत पर खींचें',
    'detecting': 'स्थान खोज रहे हैं…',
    'confirm': 'खेत का स्थान पक्का करें',
    'permission_denied': 'स्थान की अनुमति नहीं। पिन खींचें।',
  },
};

const _defaultCenter = LatLng(20.9374, 77.7796);

class Ob3FarmLocation extends StatefulWidget {
  final String language;
  final void Function(double lat, double lng) onConfirm;

  const Ob3FarmLocation({super.key, required this.language, required this.onConfirm});

  @override
  State<Ob3FarmLocation> createState() => _Ob3FarmLocationState();
}

class _Ob3FarmLocationState extends State<Ob3FarmLocation> {
  GoogleMapController? _mapController;
  LatLng _pinPosition = _defaultCenter;
  bool _locating = true;
  String? _locationError;

  Map<String, String> get _s => _strings[widget.language] ?? _strings['en']!;

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        setState(() {
          _locating = false;
          _locationError = _s['permission_denied'];
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _pinPosition = latLng;
        _locating = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14));
    } catch (_) {
      setState(() {
        _locating = false;
        _locationError = _s['permission_denied'];
      });
    }
  }

  void _onCameraMove(CameraPosition pos) {
    setState(() => _pinPosition = pos.target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StepDots(current: 2, total: 6),
                  const SizedBox(height: 18),
                  Text(
                    _s['title']!,
                    style: GoogleFonts.fraunces(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  if (_locating)
                    Row(children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.accent),
                      ),
                      const SizedBox(width: 10),
                      Text(_s['detecting']!,
                          style: GoogleFonts.dmSans(
                              color: AppTheme.textSub, fontSize: 14)),
                    ])
                  else if (_locationError != null)
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: AppTheme.amberText),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_locationError!,
                              style: GoogleFonts.dmSans(
                                  color: AppTheme.amberText,
                                  fontSize: 13))),
                    ])
                  else
                    Row(children: [
                      const Icon(Icons.touch_app_outlined,
                          size: 16, color: AppTheme.textMuted),
                      const SizedBox(width: 8),
                      Text(_s['instruction']!,
                          style: GoogleFonts.dmSans(
                              color: AppTheme.textSub, fontSize: 14)),
                    ]),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Map ──────────────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition:
                        const CameraPosition(target: _defaultCenter, zoom: 12),
                    onMapCreated: (c) => _mapController = c,
                    onCameraMove: _onCameraMove,
                    mapType: MapType.hybrid,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                  ),
                  // Fixed centre pin
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_pin,
                            color: AppTheme.dangerRed, size: 48),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                  // Coordinates chip
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_pinPosition.latitude.toStringAsFixed(4)}, ${_pinPosition.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                  // Re-centre button
                  if (!_locating)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: _detectLocation,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.bgNav,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                                color: AppTheme.accent.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.my_location,
                              color: AppTheme.accent, size: 22),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Confirm button ───────────────────────────────────────
            Container(
              color: AppTheme.bg,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: GestureDetector(
                onTap: _locating
                    ? null
                    : () => widget.onConfirm(
                        _pinPosition.latitude, _pinPosition.longitude),
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: _locating
                        ? null
                        : const LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accentDark]),
                    color: _locating
                        ? Colors.white.withValues(alpha: 0.08)
                        : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 22,
                          color: _locating ? AppTheme.textMuted : AppTheme.bg),
                      const SizedBox(width: 10),
                      Text(
                        _s['confirm']!,
                        style: GoogleFonts.dmSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color:
                                _locating ? AppTheme.textMuted : AppTheme.bg),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class _StepDots extends StatelessWidget {
  final int current;
  final int total;
  const _StepDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i <= current;
        return Container(
          margin: const EdgeInsets.only(right: 6),
          width: i == current ? 24 : 8,
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
