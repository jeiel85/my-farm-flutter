import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_farm/core/widgets.dart';
import 'package:my_farm/data/farm_store.dart';
import 'package:my_farm/data/models.dart';
import 'package:my_farm/data/weather.dart';
import 'package:my_farm/features/livestock/livestock_screen.dart';
import 'package:my_farm/main.dart';

import 'farm_store_test.dart' show MemoryStorage;

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  Future<FarmStore> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await FarmStore.load(MemoryStorage(), clock: () => DateTime(2026, 10, 5, 14, 30));
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
    expect(find.text('우리 소'), findsOneWidget);
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

  testWidgets('가축 관리에서 염소를 들이면 목록과 입식 기록에 바로 보인다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await FarmStore.load(MemoryStorage(), clock: () => DateTime(2026, 10, 5, 14, 30));
    await tester.pumpWidget(
      FarmScope(
        store: store,
        child: const MaterialApp(home: LivestockScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('들이기'));
    // 첫 프레임에서 시트 애니메이션이 시작되므로 한 번 더 그린 뒤 시간을 흘린다.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.widgetWithText(ChoiceChip, '염소'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, '이름'), '새봄');
    await tester.enterText(find.widgetWithText(TextField, '나이'), '6');
    await tester.enterText(find.widgetWithText(TextField, '체중'), '32');
    await tester.tap(find.widgetWithText(PrimaryButton, '들이기'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(store.countOf(AnimalKind.goat), 5);
    expect(find.text('우리 염소'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('입식 · 염소 새봄'), 300);
    expect(find.textContaining('입식 · 염소 새봄'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });
}

/// flutter_animate의 지연 타이머가 남지 않도록 트리를 내리고 시간을 흘려보낸다.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}
