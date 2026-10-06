import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'farm_store.dart';

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

  /// [today] 이전 예보를 뺀 사본(보관본을 다음 날 보여 줄 때). 남는 날이 없으면 null.
  WeatherReport? fromDay(DateTime today) {
    final start = DateTime(today.year, today.month, today.day);
    final rest = daily.where((d) => !d.date.isBefore(start)).toList();
    if (rest.isEmpty) return null;
    return WeatherReport(
      temperatureC: temperatureC,
      code: code,
      windKmh: windKmh,
      humidity: humidity,
      daily: rest,
      fetchedAt: fetchedAt,
    );
  }
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

  Future<WeatherReport> fetch(double latitude, double longitude) async =>
      _parseChecked(await fetchJson(latitude, longitude), DateTime.now());

  /// 응답 JSON을 그대로 돌려준다(보관본으로 저장할 때). 해석할 수 없으면 [WeatherException].
  Future<Map<String, Object?>> fetchJson(double latitude, double longitude) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
      'current': 'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'timezone': 'auto',
      'forecast_days': '5',
    });
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const WeatherException(WeatherProblem.network);
    } on http.ClientException {
      throw const WeatherException(WeatherProblem.network);
    }
    if (res.statusCode != 200) {
      throw WeatherException(WeatherProblem.server, statusCode: res.statusCode);
    }
    final Object? json;
    try {
      json = jsonDecode(res.body);
    } on FormatException {
      throw const WeatherException(WeatherProblem.badData);
    }
    if (json is! Map<String, Object?>) throw const WeatherException(WeatherProblem.badData);
    _parseChecked(json, DateTime.now());
    return json;
  }

  static WeatherReport _parseChecked(Map<String, Object?> json, DateTime fetchedAt) {
    try {
      return parse(json, fetchedAt);
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

  /// 잠시 뒤 다시 하면 될 수도 있는 실패(연결 끊김, 서버 과부하·장애). 형식 오류나 4xx는 다시 해도 같다.
  bool get transient =>
      problem == WeatherProblem.network ||
      (problem == WeatherProblem.server && (statusCode == null || statusCode! >= 500 || statusCode == 429));

  @override
  String toString() => 'WeatherException($problem, $statusCode)';
}

/// 앱 전역에서 날씨를 한 번만 받아 공유한다. 15분 동안은 받은 값을 다시 쓴다.
///
/// 마지막으로 받은 응답은 기기별 meta에 보관해 두고(백업 파일에는 들어가지 않는다), 앱을 다시 열었을 때나
/// 연결이 안 될 때 [cacheMaxAge]까지 보여 준다. 일시적인 실패는 [retryDelays] 간격으로 다시 시도한다.
class WeatherController extends ChangeNotifier {
  WeatherController(this._service, {this._cache, DateTime Function()? clock, Future<void> Function(Duration)? wait})
    : _clock = clock ?? DateTime.now,
      _wait = wait ?? Future<void>.delayed;

  final WeatherService _service;
  final FarmStorage? _cache;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _wait;

  static const cacheKey = 'weather_cache';
  static const cacheMaxAge = Duration(days: 3);
  static const retryDelays = [Duration(seconds: 2), Duration(seconds: 5)];

  WeatherReport? report;

  /// 마지막 시도의 실패. [report]가 함께 있으면 보관본이나 이전 값을 보여 주는 중이다.
  WeatherException? error;
  bool loading = false;
  (double, double)? _loadedFor;
  bool _cacheChecked = false;

  bool _isFresh(double lat, double lon) =>
      report != null &&
      _loadedFor == (lat, lon) &&
      _clock().difference(report!.fetchedAt) < const Duration(minutes: 15);

  Future<void> ensureLoaded(double lat, double lon, {bool force = false}) async {
    if (loading) return;
    if (_cacheChecked && _isFresh(lat, lon) && !force) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (!_cacheChecked) {
        _cacheChecked = true;
        await _restoreCache(lat, lon);
        if (_isFresh(lat, lon) && !force) return;
      }
      if (_loadedFor != (lat, lon)) report = null; // 다른 곳의 날씨를 보여 주지 않는다.
      final json = await _fetchWithRetry(lat, lon);
      final fetchedAt = _clock();
      report = WeatherService.parse(json, fetchedAt);
      _loadedFor = (lat, lon);
      await _saveCache(lat, lon, fetchedAt, json);
    } on WeatherException catch (e) {
      error = e;
    } catch (e) {
      error = const WeatherException(WeatherProblem.network);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, Object?>> _fetchWithRetry(double lat, double lon) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _service.fetchJson(lat, lon);
      } on WeatherException catch (e) {
        if (!e.transient || attempt >= retryDelays.length) rethrow;
        await _wait(retryDelays[attempt]);
      }
    }
  }

  Future<void> _restoreCache(double lat, double lon) async {
    final raw = await _cache?.readMeta(cacheKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      if (j['lat'] != lat || j['lon'] != lon) return;
      final fetchedAt = DateTime.parse(j['fetchedAt'] as String);
      final now = _clock();
      if (now.difference(fetchedAt) > cacheMaxAge || fetchedAt.isAfter(now)) return;
      final cached = WeatherService.parse((j['json'] as Map).cast<String, Object?>(), fetchedAt).fromDay(now);
      if (cached == null) return;
      report = cached;
      _loadedFor = (lat, lon);
      notifyListeners();
    } catch (e) {
      // 보관본은 다시 받으면 되는 값이다. 읽지 못하면 없는 것으로 본다.
      debugPrint('Ignoring unreadable weather cache: $e');
    }
  }

  Future<void> _saveCache(double lat, double lon, DateTime fetchedAt, Map<String, Object?> json) async {
    try {
      await _cache?.writeMeta(
        cacheKey,
        jsonEncode({'lat': lat, 'lon': lon, 'fetchedAt': fetchedAt.toIso8601String(), 'json': json}),
      );
    } catch (e) {
      // 화면에는 이미 새 값이 있다. 보관만 못 했을 뿐이라 다음 성공 때 다시 저장한다.
      debugPrint('Could not save weather cache: $e');
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
