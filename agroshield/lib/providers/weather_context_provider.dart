import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weather_context.dart';

class WeatherContextNotifier extends StateNotifier<WeatherContext?> {
  WeatherContextNotifier() : super(null);

  void setWeather(WeatherContext ctx) => state = ctx;
  void clear() => state = null;
}

final weatherContextProvider =
    StateNotifierProvider<WeatherContextNotifier, WeatherContext?>(
  (ref) => WeatherContextNotifier(),
);
