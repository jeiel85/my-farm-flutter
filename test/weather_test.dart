import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_farm/data/weather.dart';

import 'farm_store_test.dart' show MemoryStorage;

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
    expect(describeWeather(r.daily[1].code).$1, WeatherCondition.rain);
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
    final controller = WeatherController(
      WeatherService(client: MockClient((_) async => http.Response('', 500))),
      wait: (_) async {},
    );
    await controller.ensureLoaded(37, 127);
    expect(controller.report, isNull);
    expect(controller.error, isNotNull);
    expect(controller.loading, isFalse);
  });

  group('재시도와 보관본', () {
    final now = DateTime(2026, 10, 5, 9);

    /// 응답을 차례로 돌려주는 가짜 서버. 다 쓰면 연결 실패를 낸다.
    (WeatherService, List<Uri>) server(List<http.Response> responses) {
      final calls = <Uri>[];
      final queue = [...responses];
      return (
        WeatherService(
          client: MockClient((req) async {
            calls.add(req.url);
            if (queue.isEmpty) throw http.ClientException('offline');
            return queue.removeAt(0);
          }),
        ),
        calls,
      );
    }

    http.Response ok() => http.Response(jsonEncode(_sample), 200);

    test('일시적인 실패(5xx·연결 끊김)는 정해진 간격으로 다시 시도한다', () async {
      final (service, calls) = server([http.Response('', 503), ok()]);
      final waits = <Duration>[];
      final c = WeatherController(service, clock: () => now, wait: (d) async => waits.add(d));
      await c.ensureLoaded(37, 127);
      expect(c.report?.temperatureC, 27.6);
      expect(c.error, isNull);
      expect(calls, hasLength(2));
      expect(waits, [WeatherController.retryDelays.first]);
    });

    test('4xx·형식 오류는 다시 시도하지 않고, 재시도도 정해진 횟수까지만 한다', () async {
      final (bad, badCalls) = server([http.Response('', 400), ok()]);
      final c1 = WeatherController(bad, clock: () => now, wait: (_) async {});
      await c1.ensureLoaded(37, 127);
      expect(c1.error?.statusCode, 400);
      expect(badCalls, hasLength(1));

      final (down, downCalls) = server([]);
      final c2 = WeatherController(down, clock: () => now, wait: (_) async {});
      await c2.ensureLoaded(37, 127);
      expect(c2.error?.problem, WeatherProblem.network);
      expect(downCalls, hasLength(1 + WeatherController.retryDelays.length));
    });

    test('받은 날씨를 보관했다가, 다음에 연결이 안 되면 지난 날 예보를 빼고 보여 준다', () async {
      final storage = MemoryStorage();
      final (online, _) = server([ok()]);
      await WeatherController(online, cache: storage, clock: () => now).ensureLoaded(37, 127);
      expect(storage.meta[WeatherController.cacheKey], isNotNull);

      final nextDay = DateTime(2026, 10, 6, 8);
      final (offline, _) = server([]);
      final c = WeatherController(offline, cache: storage, clock: () => nextDay, wait: (_) async {});
      await c.ensureLoaded(37, 127);
      expect(c.error?.problem, WeatherProblem.network);
      expect(c.report?.fetchedAt, now);
      expect([for (final d in c.report!.daily) d.date], [DateTime(2026, 10, 6)]);
    });

    test('15분이 지나지 않은 보관본이면 다시 받지 않는다', () async {
      final storage = MemoryStorage();
      final (online, _) = server([ok()]);
      await WeatherController(online, cache: storage, clock: () => now).ensureLoaded(37, 127);
      final (again, calls) = server([ok()]);
      final c = WeatherController(again, cache: storage, clock: () => now.add(const Duration(minutes: 5)));
      await c.ensureLoaded(37, 127);
      expect(calls, isEmpty);
      expect(c.report, isNotNull);
    });

    test('다른 위치이거나 너무 오래되었거나 읽을 수 없는 보관본은 쓰지 않는다', () async {
      final storage = MemoryStorage();
      final (online, _) = server([ok()]);
      await WeatherController(online, cache: storage, clock: () => now).ensureLoaded(37, 127);

      Future<WeatherReport?> offlineReport(double lat, DateTime at) async {
        final (offline, _) = server([]);
        final c = WeatherController(offline, cache: storage, clock: () => at, wait: (_) async {});
        await c.ensureLoaded(lat, 127);
        return c.report;
      }

      expect(await offlineReport(35, now), isNull);
      expect(await offlineReport(37, now.add(WeatherController.cacheMaxAge + const Duration(hours: 1))), isNull);
      storage.meta[WeatherController.cacheKey] = '{broken';
      expect(await offlineReport(37, now), isNull);
    });
  });
}
