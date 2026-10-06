import 'dart:io';
import 'dart:ui' show Tristate;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:my_farm/data/app_update.dart';
import 'package:my_farm/data/farm_store.dart';
import 'package:my_farm/data/models.dart';
import 'package:my_farm/data/weather.dart';
import 'package:my_farm/main.dart';

import 'app_update_test.dart' show FakePlatform, MetaStorage;
import 'farm_store_test.dart' show MemoryStorage;

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  Future<FarmStore> pumpApp(
    WidgetTester tester, {
    String locale = 'ko',
    UpdateController? update,
    Size size = const Size(400, 900),
  }) async {
    await tester.binding.setSurfaceSize(size);
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
    await tester.pumpWidget(MyFarmApp(store: store, weather: weather, update: update));
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

  testWidgets('새 버전이 있으면 홈 알림에서 안내 시트를 열고, 프로필에 업데이트 설정이 나온다', (tester) async {
    final now = DateTime(2026, 10, 5, 14, 30);
    final storage = MetaStorage()
      ..meta['update_enabled'] = 'true'
      ..meta['update_checked_at'] = now.toIso8601String()
      ..meta['update_manifest'] = jsonEncode({
        'versionCode': 99,
        'versionName': '9.9.0',
        'apkUrl': 'https://example.test/a.apk',
        'apkSizeBytes': 52 * 1024 * 1024,
        'sha256': 'ab' * 32,
        'minSdk': 24,
        'releaseNotesUrl': 'https://example.test/notes',
      });
    final update = UpdateController(
      storage: storage,
      platform: FakePlatform(Directory.systemTemp.path),
      clock: () => now,
      client: MockClient((_) async => fail('하루 안에는 다시 확인하지 않는다')),
    );
    // 캐시 폴더 정리가 실제 파일 시스템을 쓰므로 가짜 시간 밖에서 초기화한다.
    await tester.runAsync(update.init);
    await pumpApp(tester, update: update);
    final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

    await tester.scrollUntilVisible(find.text('새 버전 9.9.0 사용 가능'), 200, scrollable: vertical);
    await tester.tap(find.text('새 버전 9.9.0 사용 가능'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('내려받을 크기 52.0MB. 업데이트해도 농장 기록은 그대로 남아요.'), findsOneWidget);
    // 홈의 백업 알림에도 '나중에'가 있으므로 시트 안의 버튼을 누른다.
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('나중에')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.text('프로필').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(find.text('새 버전 자동 확인'), 300, scrollable: vertical);
    expect(find.text('설치된 버전 1.6.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('분석에서 장부를 열어 비용을 적으면 목록과 합계에 나온다', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('분석').last);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('매출·비용'), findsOneWidget);

    await tester.tap(find.text('장부 열기'));
    await tester.pumpAndSettle();
    expect(find.text('매출·비용 장부'), findsOneWidget);
    expect(find.text('2026년 10월'), findsOneWidget);

    await tester.tap(find.text('매출·비용 기록'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(SegmentedButton<bool>), matching: find.text('비용')));
    await tester.pump();
    await tester.tap(find.text('진료·약품'));
    await tester.enterText(find.byType(TextField).first, '0');
    await tester.tap(find.text('기록하기'));
    await tester.pump();
    expect(find.text('0보다 큰 숫자로 입력하세요.'), findsOneWidget);

    final before = store.state.ledger.length;
    await tester.enterText(find.byType(TextField).first, '45,000');
    await tester.enterText(find.byType(TextField).last, '송아지 설사약');
    await tester.tap(find.text('기록하기'));
    await tester.pumpAndSettle();
    expect(store.state.ledger, hasLength(before + 1));
    final added = store.state.ledger.last;
    expect((added.category, added.amount, added.note), (LedgerCategory.vet, 45000.0, '송아지 설사약'));
    expect(find.text('장부에 기록했어요.'), findsOneWidget);
    expect(find.text('송아지 설사약'), findsOneWidget);
    expect(find.text('-₩45,000'), findsOneWidget);
    // 순이익은 요약 카드에만 나오고, 방금 적은 비용이 빠진 값이어야 한다.
    final (income, expense) = store.ledgerTotals(DateTime(2026, 10), DateTime(2026, 11));
    expect(expense, greaterThanOrEqualTo(45000));
    final won = NumberFormat.simpleCurrency(locale: 'ko', name: 'KRW');
    expect(find.text(won.format(income - expense)), findsOneWidget);

    // 기록을 누르면 같은 값이 채워진 수정 시트가 열리고, 고치면 같은 기록이 바뀐다.
    await tester.tap(find.text('송아지 설사약'));
    await tester.pumpAndSettle();
    expect(find.text('장부 기록 고치기'), findsOneWidget);
    expect(find.widgetWithText(TextField, '45000'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '52000');
    await tester.tap(find.text('기록하기'));
    await tester.pumpAndSettle();
    expect(store.state.ledger, hasLength(before + 1));
    expect(store.state.ledger.last.id, added.id);
    expect(store.state.ledger.last.amount, 52000);
    expect(find.text('장부 기록을 고쳤어요.'), findsOneWidget);
    expect(find.text('-₩52,000'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('수확할 때 판매 금액을 적으면 장부에 작물 매출로 함께 남는다', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('수확').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('수확 기록하기'));
    await tester.pumpAndSettle();
    final before = store.state.ledger.length;
    await tester.enterText(find.widgetWithText(TextField, '수확량'), '12');
    await tester.enterText(find.widgetWithText(TextField, '판매 금액 (선택)'), '96,000');
    await tester.tap(find.text('기록하기'));
    await tester.pumpAndSettle();
    expect(store.state.ledger, hasLength(before + 1));
    final sale = store.state.ledger.last;
    expect((sale.category, sale.amount), (LedgerCategory.crops, 96000.0));
    expect(sale.note, endsWith('12kg 수확'));
    expect(find.text('수확과 판매 금액을 기록했습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('스크린리더로 지도 구역을 읽고 고를 수 있다', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    await tester.tap(find.text('농장'));
    // 탭 전환 애니메이션이 끝나 이전 화면이 빠질 때까지 프레임을 넘긴다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    // 구역 칩도 같은 이름이라 지도 안에서만 찾는다.
    FinderBase<SemanticsNode> inMap(Pattern label) =>
        find.semantics.descendant(of: find.semantics.byLabel('농장 지도'), matching: find.semantics.byLabel(label));
    bool selected(Pattern label) =>
        inMap(label).evaluate().single.getSemanticsData().flagsCollection.isSelected == Tristate.isTrue;

    expect(inMap('토마토 밭'), findsOne);
    expect(inMap('채소 밭, 물 줄 때가 됐어요'), findsOne);
    expect(selected('토마토 밭'), isFalse);
    tester.semantics.tap(inMap('토마토 밭'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(selected('토마토 밭'), isTrue);
    expect(find.text('토마토 밭'), findsWidgets);
    semantics.dispose();
    await _unmount(tester);
  });

  testWidgets('넓은 화면(PC)에서는 옆 메뉴와 두 열 배치로 모든 탭과 상세 화면이 오류 없이 그려진다', (tester) async {
    // MediaQuery는 테스트 뷰 크기를 따르므로 뷰도 PC 창 크기로 맞춘다.
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await pumpApp(tester, size: const Size(1440, 900));
    // 아래 탭 대신 옆 메뉴가 있고, 앱 이름이 메뉴 위에 보인다.
    expect(find.text('마이팜'), findsOneWidget);
    expect(find.text('오늘 할 일'), findsOneWidget);
    expect(find.text('오늘 확인할 것'), findsOneWidget);
    // 홈은 두 열이다: 오늘 할 일(왼쪽)과 확인할 것(오른쪽)이 나란히 있다.
    expect(tester.getTopLeft(find.text('오늘 확인할 것')).dx, greaterThan(tester.getTopLeft(find.text('오늘 할 일')).dx + 300));
    for (final tab in ['농장', '분석', '수확', '프로필', '홈']) {
      await tester.tap(find.text(tab).last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: tab);
    }
    // 수확 기록 버튼은 넓은 화면에서 떠 있지 않고 요약 아래에 있다.
    await tester.tap(find.text('수확').last);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('수확 기록하기'), findsOneWidget);

    // 상세 화면(장부)도 두 열로 그려진다.
    await tester.tap(find.text('분석').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('장부 열기'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('매출·비용 장부'), findsOneWidget);
    expect(find.text('매출·비용 기록'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('창 폭이 넓은 배치와 휴대폰 배치를 오가도 프로필의 저장 전 입력이 남는다', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await pumpApp(tester, size: const Size(1440, 900));
    await tester.tap(find.text('프로필').last);
    await tester.pump(const Duration(seconds: 1));
    final name = find.widgetWithText(TextFormField, '농장 이름');
    await tester.enterText(name, '바뀐 농장');
    await tester.pump();

    for (final size in const [Size(400, 860), Size(1440, 900), Size(1440, 320)]) {
      tester.view.physicalSize = size;
      await tester.binding.setSurfaceSize(size);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('바뀐 농장'), findsOneWidget, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size');
    }
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
