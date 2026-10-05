import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_farm/data/weather.dart';

const _sample = {
  'current': {'temperature_2m': 27.6, 'relative_humidity_2m': 61, 'weather_code': 1, 'wind_speed_10m': 8.4},
  'daily': {
    'time': ['2026-10-05', '2026-10-06'],
    'weather_code': [1, 63],
    'temperature_2m_max': [28.1, 22.0],
    'temperature_2m_min': [17.4, null],
    'precipitation_probability_max': [10, 80],
  },
};

void main() {
  test('Open-Meteo 응답을 해석한다(빈 값은 0으로)', () {
    final r = WeatherService.parse(_sample, DateTime(2026, 10, 5));
    expect(r.temperatureC, 27.6);
    expect(r.humidity, 61);
    expect(r.daily, hasLength(2));
    expect(r.daily[1].rainChance, 80);
    expect(r.daily[1].minC, 0);
    expect(describeWeather(r.daily[1].code).$1, '비');
  });

  test('서버 오류는 WeatherException으로 바꾼다', () async {
    final service = WeatherService(client: MockClient((_) async => http.Response('nope', 503)));
    expect(service.fetch(37, 127), throwsA(isA<WeatherException>()));
  });

  test('형식이 다른 응답도 WeatherException으로 바꾼다', () async {
    final service = WeatherService(client: MockClient((_) async => http.Response(jsonEncode({'current': 1}), 200)));
    expect(service.fetch(37, 127), throwsA(isA<WeatherException>()));
  });

  test('컨트롤러는 실패를 error로 노출한다', () async {
    final controller = WeatherController(WeatherService(client: MockClient((_) async => http.Response('', 500))));
    await controller.ensureLoaded(37, 127);
    expect(controller.report, isNull);
    expect(controller.error, isNotNull);
    expect(controller.loading, isFalse);
  });
}
