import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_farm/data/farm_store.dart';
import 'package:my_farm/data/weather.dart';
import 'package:my_farm/main.dart';

import 'farm_store_test.dart' show MemoryStorage;

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  Future<FarmStore> pumpApp(WidgetTester tester, {String locale = 'ko'}) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // 테스트 환경의 기기 언어와 상관없이 화면 언어를 고정한다.
    final storage = MemoryStorage()..meta['locale'] = locale;
    final store = await FarmStore.load(storage, clock: () => DateTime(2026, 10, 5, 14, 30), english: locale == 'en');
    final weather = WeatherController(
      WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'current': {'temperature_2m': 24.0, 'relative_humidity_2m': 50, 'weather_code': 0, 'wind_speed_10m': 5.0},
              'daily': {
                'time': ['2026-10-05'],
                'weather_code': [0],
                'temperature_2m_max': [25.0],
                'temperature_2m_min': [14.0],
                'precipitation_probability_max': [0],
              },
            }),
            200,
          ),
        ),
      ),
    );
    await tester.pumpWidget(MyFarmApp(store: store, weather: weather));
    await tester.pump(const Duration(seconds: 2));
    return store;
  }

  testWidgets('홈에서 시작해 농장 탭의 구역을 고르면 상세 카드가 바뀐다', (tester) async {
    await pumpApp(tester);
    expect(find.text('오늘 할 일'), findsOneWidget);
    expect(find.textContaining('24°'), findsOneWidget);

    await tester.tap(find.text('농장'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('구역을 눌러 둘러보세요'), findsOneWidget);

    final chips = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal);
    await tester.dragUntilVisible(find.text('가축 구역'), chips, const Offset(-150, 0));
    await tester.tap(find.text('가축 구역'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('가축 관리 열기'), findsOneWidget);

    await tester.ensureVisible(find.text('가축 관리 열기'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('가축 관리 열기'));
    // 첫 프레임에서 라우트 전환이 시작되므로 한 번 더 그린 뒤 시간을 흘린다.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('오늘의 급이'), findsOneWidget);
    expect(find.text('백신·진료 일정'), findsOneWidget);
    // 일정 카드가 생겨 가축 목록 제목은 첫 화면 아래에 있다.
    await tester.scrollUntilVisible(find.text('우리 소'), 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('우리 소'), findsOneWidget);

    // 입식 시트가 열린다.
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('가축 입식'), findsOneWidget);
    expect(find.textContaining('COW-'), findsWidgets);
    expect(find.textContaining('18마리'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('분석·수확·프로필 탭이 오류 없이 그려진다', (tester) async {
    await pumpApp(tester);
    for (final tab in ['분석', '수확', '프로필']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    }
    expect(find.text('농장 정보'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('영어로 바꾸면 화면과 예시 데이터가 영어로 나온다', (tester) async {
    await pumpApp(tester, locale: 'en');
    expect(find.text("Today's tasks"), findsOneWidget);
    expect(find.text('Prune tomato suckers'), findsOneWidget);
    expect(find.textContaining('°'), findsWidgets);

    await tester.tap(find.text('Farm'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Tap a zone to explore'), findsOneWidget);

    for (final tab in ['Analytics', 'Harvest', 'Profile']) {
      await tester.tap(find.text(tab).last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Farm details'), findsOneWidget);
    await _unmount(tester);
  });
}

/// flutter_animate의 지연 타이머가 남지 않도록 트리를 내리고 시간을 흘려보낸다.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}
