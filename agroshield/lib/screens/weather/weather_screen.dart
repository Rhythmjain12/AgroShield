import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_keys.dart';
import '../../models/weather_context.dart';
import '../../providers/weather_context_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/geo_utils.dart';

// Tomorrow.io windSpeed is in m/s (metric mode).
const double _kWindFactor = 3.6;
const Duration _kCacheTtl = Duration(minutes: 30);

// ══════════════════════════════════════════════════════════════════════════
class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  double? _farmLat;
  double? _farmLng;
  String _language = 'en';

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_init);
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('farm_lat');
    final lng = prefs.getDouble('farm_lng');
    final lang = prefs.getString('language') ?? 'en';

    if (mounted) {
      setState(() {
        _farmLat = lat;
        _farmLng = lng;
        _language = lang;
      });
    }

    final existing = ref.read(weatherContextProvider);
    if (existing != null &&
        DateTime.now().difference(existing.fetchedAt) < _kCacheTtl) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    await _loadWeather();
  }

  Future<void> _loadWeather() async {
    if (mounted) setState(() { _loading = true; _error = null; });

    if (kTomorrowApiKey == 'YOUR_TOMORROW_IO_API_KEY') {
      if (mounted) setState(() { _loading = false; _error = 'api_key_missing'; });
      return;
    }

    final lat = _farmLat;
    final lng = _farmLng;
    if (lat == null || lng == null) {
      if (mounted) setState(() { _loading = false; _error = 'no_location'; });
      return;
    }

    try {
      final locParam = '$lat,$lng';
      final headers = {'accept': 'application/json'};

      // Fire both requests in parallel — realtime for "now", forecast for 5-day.
      final realtimeUrl = Uri.parse(
        'https://api.tomorrow.io/v4/weather/realtime'
        '?location=$locParam&apikey=$kTomorrowApiKey&units=metric',
      );
      final forecastUrl = Uri.parse(
        'https://api.tomorrow.io/v4/weather/forecast'
        '?location=$locParam&apikey=$kTomorrowApiKey&units=metric',
      );

      final results = await Future.wait([
        http.get(realtimeUrl, headers: headers).timeout(const Duration(seconds: 15)),
        http.get(forecastUrl, headers: headers).timeout(const Duration(seconds: 15)),
      ]);

      if (results[0].statusCode != 200) throw Exception('Realtime HTTP ${results[0].statusCode}');
      if (results[1].statusCode != 200) throw Exception('Forecast HTTP ${results[1].statusCode}');

      final realtimeBody = jsonDecode(results[0].body) as Map<String, dynamic>;
      final forecastBody = jsonDecode(results[1].body) as Map<String, dynamic>;
      final ctx = _parse(realtimeBody, forecastBody);

      ref.read(weatherContextProvider.notifier).setWeather(ctx);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ── Parse Tomorrow.io responses ────────────────────────────────────────
  // realtimeBody  → /v4/weather/realtime  (live sensor-fused current conditions)
  // forecastBody  → /v4/weather/forecast  (5-day daily + hourly timelines)
  WeatherContext _parse(Map<String, dynamic> realtimeBody, Map<String, dynamic> forecastBody) {
    // Current conditions — from realtime endpoint (accurate for ongoing rain etc.)
    final rtValues = (realtimeBody['data']?['values'] ?? {}) as Map<String, dynamic>;
    final currentTemp = (rtValues['temperature'] as num?)?.toDouble() ?? 0;
    final humidity = ((rtValues['humidity'] as num?) ?? 0).toInt();
    final windSpeedRaw = (rtValues['windSpeed'] as num?)?.toDouble() ?? 0;
    final windSpeed = windSpeedRaw * _kWindFactor;
    final windDirDeg = (rtValues['windDirection'] as num?)?.toDouble() ?? 0;
    final windDirection = windHeadingToLabel(windDirDeg);
    final precipMm = (rtValues['precipitationIntensity'] as num?)?.toDouble() ?? 0;

    // 5-day forecast — from forecast endpoint
    final timelines = forecastBody['timelines'] as Map<String, dynamic>;
    final daily = (timelines['daily'] as List).cast<Map<String, dynamic>>();

    DayForecast parseDailySlot(Map<String, dynamic> slot) {
      final v = slot['values'] as Map<String, dynamic>;
      return DayForecast(
        date: DateTime.parse(slot['time'] as String).toLocal(),
        tempMin: (v['temperatureMin'] as num).toDouble(),
        tempMax: (v['temperatureMax'] as num).toDouble(),
        humidity: ((v['humidityAvg'] as num?) ?? 0).toInt(),
        windSpeed: ((v['windSpeedAvg'] as num?) ?? 0).toDouble() * _kWindFactor,
        windDirection: windHeadingToLabel(((v['windDirectionAvg'] as num?) ?? 0).toDouble()),
        precipMm: (v['rainAccumulationAvg'] as num?)?.toDouble() ??
            (v['precipitationIntensityAvg'] as num?)?.toDouble() ??
            0,
      );
    }

    final forecast = daily.take(5).map(parseDailySlot).toList();
    final forecast48hr = daily.take(2).map(parseDailySlot).toList();

    return WeatherContext(
      currentTemp: currentTemp,
      humidity: humidity,
      windSpeed: windSpeed,
      windDirection: windDirection,
      precipMm: precipMm,
      forecast: forecast,
      forecast48hr: forecast48hr,
      summaryLineEn: _advisoryEn(currentTemp, humidity, windSpeed, precipMm),
      summaryLineHi: _advisoryHi(currentTemp, humidity, windSpeed, precipMm),
      fetchedAt: DateTime.now(),
    );
  }

  // ── Advisory strings ──────────────────────────────────────────────────
  String _advisoryEn(double temp, int hum, double wind, double precip) {
    if (precip > 0.1) return 'Rain falling now — lower fire risk, good day to prepare fields.';
    if (temp > 38 && hum < 25 && wind > 25) return 'Extreme fire conditions — very dry and windy, keep fields clear.';
    if (temp > 35 && hum < 35) return 'Hot and dry — elevated fire risk, avoid burning waste.';
    if (wind > 20) return 'Strong winds — fire could spread quickly if one starts nearby.';
    if (temp > 32) return 'Warm day — stay alert for fire risk during dry hours.';
    return 'Moderate conditions — a calm day for farm work.';
  }

  String _advisoryHi(double temp, int hum, double wind, double precip) {
    if (precip > 0.1) return 'अभी बारिश हो रही है — आग का खतरा कम, खेत तैयार करने का अच्छा समय।';
    if (temp > 38 && hum < 25 && wind > 25) return 'अत्यधिक आग का खतरा — बहुत शुष्क और तेज़ हवा, खेत साफ रखें।';
    if (temp > 35 && hum < 35) return 'गर्म और शुष्क — आग का खतरा बढ़ा हुआ, कचरा न जलाएं।';
    if (wind > 20) return 'तेज़ हवा — अगर आग लगी तो जल्दी फैल सकती है।';
    if (temp > 32) return 'गर्म दिन — शुष्क घंटों में आग के प्रति सावधान रहें।';
    return 'सामान्य मौसम — खेती के काम के लिए अच्छा दिन।';
  }

  String _dayAdvisoryEn(DayForecast day) {
    if (day.precipMm > 0.5) return 'Rain likely — lower fire risk';
    if (day.tempMax > 38 && day.humidity < 30) return 'High fire risk — hot and dry';
    if (day.windSpeed > 20) return 'Windy — fire risk elevated';
    if (day.tempMax > 35) return 'Hot — stay alert for fires';
    return 'Moderate conditions';
  }

  String _dayAdvisoryHi(DayForecast day) {
    if (day.precipMm > 0.5) return 'बारिश संभव — आग का खतरा कम';
    if (day.tempMax > 38 && day.humidity < 30) return 'उच्च आग खतरा — गर्म और शुष्क';
    if (day.windSpeed > 20) return 'तेज़ हवा — आग का खतरा बढ़ा';
    if (day.tempMax > 35) return 'गर्म — आग से सावधान रहें';
    return 'सामान्य मौसम स्थिति';
  }

  // ══════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final weather = ref.watch(weatherContextProvider);
    final isHi = _language == 'hi';

    return Container(
      color: AppTheme.bg,
      child: CustomScrollView(
        slivers: [
          // Topbar
          SliverToBoxAdapter(child: _buildTopbar(isHi)),

          // Today card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: _buildTodayCard(weather, isHi),
            ),
          ),

          // 5-day forecast
          if (weather != null && weather.forecast.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 20, 14, 10),
                child: Text(
                  isHi ? '5-दिन का पूर्वानुमान' : '5-Day Forecast',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.10 * 10,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 7),
                  child: _buildDayCard(weather.forecast[i], isHi),
                ),
                childCount: weather.forecast.length,
              ),
            ),
          ],

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              child: _buildTimestampRow(weather, isHi),
            ),
          ),
        ],
      ),
    );
  }

  // ── Topbar ────────────────────────────────────────────────────────────
  Widget _buildTopbar(bool isHi) {
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
              Text(
                isHi ? 'मौसम' : 'Weather',
                style: GoogleFonts.fraunces(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.02 * 21),
              ),
              const Spacer(),
              if (!_loading)
                GestureDetector(
                  onTap: _loadWeather,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    child: Icon(Icons.refresh,
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

  // ── Today card ────────────────────────────────────────────────────────
  Widget _buildTodayCard(WeatherContext? weather, bool isHi) {
    if (_loading) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppTheme.bgNav,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
              color: AppTheme.accent, strokeWidth: 2.5),
        ),
      );
    }

    if (_error != null) return _buildErrorCard(isHi);
    if (weather == null) return const SizedBox.shrink();

    final advisory = isHi ? weather.summaryLineHi : weather.summaryLineEn;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Temperature hero with radial mesh gradient
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF122416),
                    Color(0xFF1A3D1F),
                    Color(0xFF0F2E14),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Ghost watermark
                  Positioned(
                    right: -8,
                    bottom: -16,
                    child: Text('☀',
                        style: TextStyle(
                            fontSize: 100,
                            color: Colors.white.withValues(alpha: 0.07))),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHi ? 'आज · आपका खेत' : 'Today · Your farm',
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${weather.currentTemp.round()}°',
                            style: GoogleFonts.fraunces(
                                fontSize: 72,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.0,
                                letterSpacing: -0.04 * 72),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10, left: 12),
                            child: Text(
                              _tempConditionEn(weather.currentTemp,
                                  weather.humidity, isHi),
                              style: GoogleFonts.fraunces(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Advisory strip
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0x1AEF9E27),
              border: Border(
                  top: BorderSide(color: Color(0x33EF9E27)),
                  bottom: BorderSide(color: Color(0x1AFFFFFF))),
            ),
            child: Row(
              children: [
                const Text('🌿', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    advisory,
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.textSub,
                        fontStyle: FontStyle.italic,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          // Metric rows
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _metricRow(
                  emoji: '💧',
                  label: isHi ? 'नमी' : 'Humidity',
                  value: '${weather.humidity}%',
                  sub: isHi
                      ? _humidityNoteHi(weather.humidity)
                      : _humidityNoteEn(weather.humidity),
                ),
                const SizedBox(height: 7),
                _metricRow(
                  emoji: '💨',
                  label: isHi ? 'हवा' : 'Wind',
                  value: '${weather.windSpeed.round()} km/h ${weather.windDirection}',
                  sub: isHi
                      ? _windNoteHi(weather.windSpeed, weather.windDirection)
                      : _windNoteEn(weather.windSpeed, weather.windDirection),
                  trailing: Transform.rotate(
                    angle: _windDirDegrees(weather.windDirection) * (pi / 180),
                    child: const Icon(Icons.navigation,
                        size: 16, color: AppTheme.accent),
                  ),
                ),
                const SizedBox(height: 7),
                _metricRow(
                  emoji: '🌧',
                  label: isHi ? 'वर्षा' : 'Rainfall',
                  value: weather.precipMm > 0
                      ? '${weather.precipMm.toStringAsFixed(1)} mm/h'
                      : (isHi ? 'कोई नहीं' : 'None'),
                  sub: weather.precipMm > 0.1
                      ? (isHi
                          ? 'बारिश हो रही है — खेत में पानी की जाँच करें'
                          : 'Active rainfall — check drainage in fields')
                      : (isHi ? 'सूखा मौसम' : 'Dry conditions'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Frosted metric row ────────────────────────────────────────────────
  Widget _metricRow({
    required String emoji,
    required String label,
    required String value,
    required String sub,
    Widget? trailing,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        // PERF: blur is expensive on budget Android; remove filter to disable.
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x2E6FCF80), Color(0x1A43A853)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x406FCF80)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.25)),
                ),
                child: Center(
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.01 * 13)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: GoogleFonts.dmSans(
                            fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              if (trailing != null) ...[trailing, const SizedBox(width: 4)],
              Text(
                value,
                style: GoogleFonts.fraunces(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 5-day forecast card ───────────────────────────────────────────────
  Widget _buildDayCard(DayForecast day, bool isHi) {
    final dayName = DateFormat('EEE d MMM').format(day.date);
    final advisory = isHi ? _dayAdvisoryHi(day) : _dayAdvisoryEn(day);
    final isHighRisk = day.tempMax > 38 && day.humidity < 30;
    final isRain = day.precipMm > 3;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        // PERF: blur is expensive on budget Android; remove filter to disable.
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHighRisk
                  ? AppTheme.dangerRed.withValues(alpha: 0.4)
                  : isRain
                      ? const Color(0xFF1565C0).withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                child: Text(
                  dayName,
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${day.tempMin.round()}° – ${day.tempMax.round()}°',
                      style: GoogleFonts.fraunces(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      advisory,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: isHighRisk
                            ? AppTheme.dangerRed
                            : isRain
                                ? const Color(0xFF64B5F6)
                                : AppTheme.textMuted,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _miniChip(Icons.air, '${day.windSpeed.round()} km/h'),
                  const SizedBox(height: 4),
                  _miniChip(
                      Icons.water_drop_outlined, '${day.humidity}%'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textMuted),
        const SizedBox(width: 3),
        Text(text,
            style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── Error card ────────────────────────────────────────────────────────
  Widget _buildErrorCard(bool isHi) {
    String title;
    String body;
    bool showRetry = true;

    if (_error == 'api_key_missing') {
      title = 'API Key Required';
      body = 'Add your Tomorrow.io API key to lib/config/api_keys.dart to load weather data.';
      showRetry = false;
    } else if (_error == 'no_location') {
      title = isHi ? 'स्थान उपलब्ध नहीं' : 'Farm Location Missing';
      body = isHi
          ? 'मौसम के लिए खेत का स्थान चाहिए। ऑनबोर्डिंग पूरी करें।'
          : 'Complete farm setup to see weather for your location.';
      showRetry = false;
    } else {
      title = isHi ? 'मौसम लोड नहीं हो सका' : 'Unable to Load Weather';
      body = isHi
          ? 'नेटवर्क की जाँच करें और दोबारा कोशिश करें।'
          : 'Check your connection and tap retry.';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.bgNav,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            _error == 'api_key_missing'
                ? Icons.key_outlined
                : Icons.cloud_off_outlined,
            size: 40,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 12),
          Text(title,
              style: GoogleFonts.fraunces(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textMuted)),
          if (showRetry) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadWeather,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(isHi ? 'दोबारा कोशिश' : 'Retry'),
            ),
          ],
        ],
      ),
    );
  }

  // ── Timestamp row ─────────────────────────────────────────────────────
  Widget _buildTimestampRow(WeatherContext? weather, bool isHi) {
    if (weather == null) return const SizedBox.shrink();
    final diff = DateTime.now().difference(weather.fetchedAt);
    final ago = diff.inMinutes < 1
        ? (isHi ? 'अभी' : 'Just now')
        : diff.inMinutes < 60
            ? (isHi ? '${diff.inMinutes} मिनट पहले' : '${diff.inMinutes}m ago')
            : (isHi ? '${diff.inHours} घंटे पहले' : '${diff.inHours}h ago');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.update, size: 13, color: AppTheme.textMuted),
        const SizedBox(width: 5),
        Text(
          isHi ? 'Tomorrow.io से $ago अपडेट किया' : 'Updated $ago via Tomorrow.io',
          style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ── Advisory helper strings ───────────────────────────────────────────
  String _tempConditionEn(double temp, int hum, bool isHi) {
    if (isHi) {
      if (temp > 38 && hum < 30) return 'गर्म और सूखा';
      if (temp > 35) return 'बहुत गर्म';
      if (temp > 30) return 'गर्म';
      return 'सामान्य';
    }
    if (temp > 38 && hum < 30) return 'Hot & dry';
    if (temp > 35) return 'Very hot';
    if (temp > 30) return 'Warm';
    return 'Pleasant';
  }

  String _humidityNoteEn(int h) {
    if (h < 25) return 'Very dry — high fire ignition risk';
    if (h < 40) return 'Low humidity — fire risk elevated';
    if (h > 75) return 'High humidity — lower fire risk today';
    return 'Normal humidity for farm work';
  }

  String _humidityNoteHi(int h) {
    if (h < 25) return 'बहुत शुष्क — आग का खतरा अधिक';
    if (h < 40) return 'कम नमी — आग का खतरा बढ़ा हुआ';
    if (h > 75) return 'अधिक नमी — आज आग का कम खतरा';
    return 'सामान्य नमी — खेती के लिए ठीक';
  }

  String _windNoteEn(double speed, String dir) {
    if (speed > 30) return 'Strong winds — fire spreads very fast';
    if (speed > 20) return 'Moderate winds — fire risk elevated';
    if (speed > 10) return 'Light winds — normal precautions apply';
    return 'Calm — low wind-driven fire risk';
  }

  String _windNoteHi(double speed, String dir) {
    if (speed > 30) return 'बहुत तेज़ हवा — आग बहुत तेज़ी से फैल सकती है';
    if (speed > 20) return 'मध्यम हवा — आग का खतरा बढ़ा हुआ';
    if (speed > 10) return 'हल्की हवा — सामान्य सावधानी बरतें';
    return 'शांत मौसम — हवा से आग का कम खतरा';
  }

  double _windDirDegrees(String dir) {
    const map = {
      'N': 0.0, 'NE': 45.0, 'E': 90.0, 'SE': 135.0,
      'S': 180.0, 'SW': 225.0, 'W': 270.0, 'NW': 315.0,
    };
    return map[dir] ?? 0.0;
  }
}
