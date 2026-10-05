import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.code,
    required this.maxC,
    required this.minC,
    required this.rainChance,
  });

  final DateTime date;
  final int code;
  final double maxC;
  final double minC;
  final int rainChance;
}

class WeatherReport {
  const WeatherReport({
    required this.temperatureC,
    required this.code,
    required this.windKmh,
    required this.humidity,
    required this.daily,
    required this.fetchedAt,
  });

  final double temperatureC;
  final int code;
  final double windKmh;
  final int humidity;
  final List<DailyForecast> daily;
  final DateTime fetchedAt;

  int get todayRainChance => daily.isEmpty ? 0 : daily.first.rainChance;
}

enum WeatherCondition { clear, partlyCloudy, cloudy, fog, drizzle, rain, snow, thunder, unknown }

/// WMO 날씨 코드를 상태와 아이콘으로 바꾼다(문구는 l10n에서).
(WeatherCondition, IconData) describeWeather(int code) => switch (code) {
  0 => (WeatherCondition.clear, Icons.wb_sunny_rounded),
  1 || 2 => (WeatherCondition.partlyCloudy, Icons.wb_cloudy_outlined),
  3 => (WeatherCondition.cloudy, Icons.cloud_rounded),
  45 || 48 => (WeatherCondition.fog, Icons.foggy),
  51 || 53 || 55 || 56 || 57 => (WeatherCondition.drizzle, Icons.grain_rounded),
  61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => (WeatherCondition.rain, Icons.umbrella_rounded),
  71 || 73 || 75 || 77 || 85 || 86 => (WeatherCondition.snow, Icons.ac_unit_rounded),
  95 || 96 || 99 => (WeatherCondition.thunder, Icons.thunderstorm_rounded),
  _ => (WeatherCondition.unknown, Icons.help_outline_rounded),
};

/// Open-Meteo(무료, API 키 없음)에서 현재 날씨와 5일 예보를 가져온다.
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<WeatherReport> fetch(double latitude, double longitude) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
      'current': 'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'timezone': 'auto',
      'forecast_days': '5',
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw WeatherException(WeatherProblem.server, statusCode: res.statusCode);
    }
    try {
      return parse(jsonDecode(res.body) as Map<String, Object?>, DateTime.now());
    } on FormatException {
      throw const WeatherException(WeatherProblem.badData);
    } on TypeError {
      throw const WeatherException(WeatherProblem.badData);
    }
  }

  static WeatherReport parse(Map<String, Object?> json, DateTime fetchedAt) {
    final current = (json['current'] as Map).cast<String, Object?>();
    final daily = (json['daily'] as Map).cast<String, Object?>();
    final times = (daily['time'] as List).cast<String>();
    List<num?> col(String k) => (daily[k] as List).cast<num?>();
    final codes = col('weather_code');
    final maxes = col('temperature_2m_max');
    final mins = col('temperature_2m_min');
    final rain = col('precipitation_probability_max');
    return WeatherReport(
      temperatureC: (current['temperature_2m'] as num).toDouble(),
      code: (current['weather_code'] as num).toInt(),
      windKmh: (current['wind_speed_10m'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toInt(),
      fetchedAt: fetchedAt,
      daily: [
        for (var i = 0; i < times.length; i++)
          DailyForecast(
            date: DateTime.parse(times[i]),
            code: (codes[i] ?? 0).toInt(),
            maxC: (maxes[i] ?? 0).toDouble(),
            minC: (mins[i] ?? 0).toDouble(),
            rainChance: (rain[i] ?? 0).toInt(),
          ),
      ],
    );
  }
}

enum WeatherProblem { server, badData, network }

class WeatherException implements Exception {
  const WeatherException(this.problem, {this.statusCode});
  final WeatherProblem problem;
  final int? statusCode;
  @override
  String toString() => 'WeatherException($problem, $statusCode)';
}

/// 앱 전역에서 날씨를 한 번만 받아 공유한다. 15분 동안은 캐시를 쓴다.
class WeatherController extends ChangeNotifier {
  WeatherController(this._service);

  final WeatherService _service;
  WeatherReport? report;
  WeatherException? error;
  bool loading = false;
  (double, double)? _loadedFor;

  Future<void> ensureLoaded(double lat, double lon, {bool force = false}) async {
    if (loading) return;
    final fresh =
        report != null &&
        _loadedFor == (lat, lon) &&
        DateTime.now().difference(report!.fetchedAt) < const Duration(minutes: 15);
    if (fresh && !force) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      report = await _service.fetch(lat, lon);
      _loadedFor = (lat, lon);
    } catch (e) {
      error = e is WeatherException ? e : const WeatherException(WeatherProblem.network);
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

class WeatherScope extends InheritedNotifier<WeatherController> {
  const WeatherScope({super.key, required WeatherController controller, required super.child})
    : super(notifier: controller);

  static WeatherController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WeatherScope>()!.notifier!;

  static WeatherController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<WeatherScope>()!.notifier!;
}
