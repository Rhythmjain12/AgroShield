class DayForecast {
  final DateTime date;
  final double tempMin;
  final double tempMax;
  final int humidity;
  final double windSpeed; // km/h
  final String windDirection;
  final double precipMm;

  const DayForecast({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.precipMm,
  });
}

class WeatherContext {
  final double currentTemp;
  final int humidity;
  final double windSpeed; // km/h
  final String windDirection;
  final double precipMm;
  final List<DayForecast> forecast; // 5-day for Weather tab display
  final List<DayForecast> forecast48hr; // first 2 days for Advisor context injection
  final String summaryLineEn;
  final String summaryLineHi;
  final DateTime fetchedAt;

  const WeatherContext({
    required this.currentTemp,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.precipMm,
    required this.forecast,
    required this.forecast48hr,
    required this.summaryLineEn,
    required this.summaryLineHi,
    required this.fetchedAt,
  });
}
