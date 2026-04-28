import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

const _strings = {
  'en': {
    'title': 'Tell us about\nyour farm',
    'farm_size': 'Farm size',
    'acres': 'acres',
    'alert_radius': 'Fire alert radius',
    'radius_hint': 'Fires within this distance will notify you',
    'confirm': 'Continue',
  },
  'hi': {
    'title': 'अपने खेत के बारे में\nबताएं',
    'farm_size': 'खेत का आकार',
    'acres': 'एकड़',
    'alert_radius': 'आग अलर्ट दूरी',
    'radius_hint': 'इस दायरे में आग लगने पर सूचना मिलेगी',
    'confirm': 'आगे बढ़ें',
  },
};

class Ob5FarmSize extends StatefulWidget {
  final String language;
  final void Function(double acres, double radiusKm) onConfirm;

  const Ob5FarmSize({super.key, required this.language, required this.onConfirm});

  @override
  State<Ob5FarmSize> createState() => _Ob5FarmSizeState();
}

class _Ob5FarmSizeState extends State<Ob5FarmSize> {
  double _farmAcres = 3.0;
  double _radiusKm = 50.0;

  Map<String, String> get _s => _strings[widget.language] ?? _strings['en']!;

  String _formatAcres(double v) =>
      v < 10 ? v.toStringAsFixed(1) : v.round().toString();

  double get _acresSlider => ((_farmAcres - 0.5) / 199.5).clamp(0.0, 1.0);
  set _acresSlider(double v) {
    _farmAcres = (v * 199.5 + 0.5).clamp(0.5, 200.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              _StepDots(current: 4, total: 6),

              const SizedBox(height: 28),

              Text(
                _s['title']!,
                style: GoogleFonts.fraunces(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.5),
              ),

              const SizedBox(height: 32),

              // Farm size slider card
              _SliderCard(
                icon: Icons.agriculture_outlined,
                label: _s['farm_size']!,
                valueDisplay: '${_formatAcres(_farmAcres)} ${_s['acres']}',
                sliderValue: _acresSlider,
                trackColor: AppTheme.accent,
                minLabel: '0.5 ${_s['acres']}',
                maxLabel: '200 ${_s['acres']}',
                onChanged: (v) => setState(() => _acresSlider = v),
              ),

              const SizedBox(height: 16),

              // Alert radius slider card
              _SliderCard(
                icon: Icons.radar_outlined,
                label: _s['alert_radius']!,
                valueDisplay: '${_radiusKm.round()} km',
                sliderValue: ((_radiusKm - 10) / 140).clamp(0.0, 1.0),
                trackColor: AppTheme.amberText,
                minLabel: '10 km',
                maxLabel: '150 km',
                onChanged: (v) =>
                    setState(() => _radiusKm = (v * 140 + 10).clamp(10, 150)),
              ),

              const SizedBox(height: 16),

              Center(child: _RadiusVisual(radiusKm: _radiusKm)),

              const Spacer(),

              GestureDetector(
                onTap: () => widget.onConfirm(_farmAcres, _radiusKm),
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accentDark]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _s['confirm']!,
                      style: GoogleFonts.dmSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.bg),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valueDisplay;
  final double sliderValue;
  final Color trackColor;
  final String minLabel;
  final String maxLabel;
  final ValueChanged<double> onChanged;

  const _SliderCard({
    required this.icon,
    required this.label,
    required this.valueDisplay,
    required this.sliderValue,
    required this.trackColor,
    required this.minLabel,
    required this.maxLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        // PERF: blur is expensive on budget Android; remove filter to disable.
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          decoration: AppTheme.frostedCard(radius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: trackColor, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: trackColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: trackColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      valueDisplay,
                      style: GoogleFonts.fraunces(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: trackColor),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: trackColor,
                  inactiveTrackColor: trackColor.withValues(alpha: 0.2),
                  thumbColor: trackColor,
                  overlayColor: trackColor.withValues(alpha: 0.15),
                  trackHeight: 5,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
                ),
                child: Slider(value: sliderValue, onChanged: onChanged),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(minLabel,
                        style: GoogleFonts.dmSans(
                            fontSize: 11, color: AppTheme.textMuted)),
                    Text(maxLabel,
                        style: GoogleFonts.dmSans(
                            fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadiusVisual extends StatelessWidget {
  final double radiusKm;
  const _RadiusVisual({required this.radiusKm});

  @override
  Widget build(BuildContext context) {
    final fraction = ((radiusKm - 10) / 140).clamp(0.0, 1.0);
    return SizedBox(
      width: 120,
      height: 60,
      child: CustomPaint(painter: _ArcPainter(fraction: fraction)),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double fraction;
  _ArcPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;

    for (int i = 3; i >= 1; i--) {
      final r =
          (size.height * 0.28 * i) * (0.3 + 0.7 * fraction);
      final paint = Paint()
        ..color = AppTheme.amberText
            .withValues(alpha: 0.08 + 0.12 * (4 - i))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(
        Rect.fromCircle(
            center: Offset(cx, cy),
            radius: r.clamp(4.0, double.infinity)),
        math.pi,
        math.pi,
        false,
        paint,
      );
    }

    canvas.drawCircle(
      Offset(cx, cy),
      4,
      Paint()..color = AppTheme.accent,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.fraction != fraction;
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
