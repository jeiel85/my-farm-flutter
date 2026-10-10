import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_farm/data/app_update.dart';
import 'package:my_farm/features/farm/farm_map_view.dart';
import 'package:my_farm/game/defs.dart';
import 'package:my_farm/game/engine.dart';
import 'package:my_farm/game/game_store.dart';
import 'package:my_farm/game/lots.dart';
import 'package:my_farm/main.dart';

import 'app_update_test.dart' show FakePlatform, MetaStorage;
import 'support/memory_storage.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 5, 14, 30));

  Future<GameStore> pumpApp(
    WidgetTester tester, {
    String locale = 'ko',
    UpdateController? update,
    MemoryStorage? storage,
    Size size = const Size(400, 900),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // 테스트 환경의 기기 언어와 상관없이 화면 언어를 고정한다.
    final store = await GameStore.load(
      (storage ?? MemoryStorage())..meta['locale'] = locale,
      clock: () => now,
      defaultFarmName: locale == 'ko' ? '햇살 농장' : 'Sunny Farm',
    );
    await tester.pumpWidget(MyFarmApp(store: store, update: update));
    await tester.pump(const Duration(seconds: 2));
    return store;
  }

  /// 매초 시계가 돌도록 [d]만큼 시간을 흘린다.
  Future<void> wait(WidgetTester tester, Duration d) async {
    now = now.add(d);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(f);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('새 농장: 달걀을 줍고, 상추가 다 자라면 수확해 창고에서 판다', (tester) async {
    final store = await pumpApp(tester);
    expect(find.text('햇살 농장'), findsOneWidget);
    expect(find.text('할 일'), findsOneWidget);
    expect(find.text('닭 생산물 1개 모으기'), findsOneWidget);

    await tapAndSettle(tester, find.text('달걀 줍기'));
    expect(find.text('달걀 1개 모았어요'), findsOneWidget);
    expect(store.state.countOf(ItemId.egg), 1);

    // 1분 뒤 상추가 다 자란다.
    await wait(tester, const Duration(minutes: 1));
    expect(find.text('밭 상추 수확'), findsOneWidget);
    await tapAndSettle(tester, find.text('수확').last);
    expect(find.text('상추 수확!'), findsOneWidget);

    await tapAndSettle(tester, find.text('창고').last);
    // 휴대폰 창고 탭은 마을 주문 아래에 시장 목록이 있어 내려서 본다.
    expect(find.text('마을 주문'), findsOneWidget);
    final lettuce = find.text('상추 × ${GameDefs.crops[CropId.lettuce]!.yieldCount}');
    await tester.scrollUntilVisible(lettuce, 200, scrollable: find.byType(Scrollable).last);
    expect(lettuce, findsOneWidget);
    expect(find.text('달걀 × 1'), findsOneWidget);
    final coins = store.state.coins;
    await tapAndSettle(tester, find.text('모두 팔기'));
    await tapAndSettle(tester, find.descendant(of: find.byType(AlertDialog), matching: find.text('모두 팔기')));
    expect(store.state.coins, greaterThan(coins));
    expect(store.state.barnUsed, 0);

    await tapAndSettle(tester, find.text('기록').last);
    expect(find.text('상추 판매'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('창고·기록·설정 탭이 오류 없이 그려진다', (tester) async {
    await pumpApp(tester);
    for (final tab in ['창고', '기록', '설정']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: tab);
    }
    expect(find.text('농장 정보'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('스크린리더로 지도 칸을 읽고, 빈 땅을 고르면 짓기 목록이, 짓고 나면 바로 그 건물 상세가 뜬다', (tester) async {
    final semantics = tester.ensureSemantics();
    final store = await pumpApp(tester);
    FinderBase<SemanticsNode> inMap(Pattern label) =>
        find.semantics.descendant(of: find.semantics.byLabel('농장 지도'), matching: find.semantics.byLabel(label));

    expect(inMap('밭, 상추 자라는 중'), findsOne);
    expect(inMap('빈 땅, 지을 수 있어요'), findsExactly(2));
    expect(inMap('닭장'), findsOne);
    // 처음 땅에 붙은 장애물 칸은 2레벨에 넓힐 수 있다고 읽힌다.
    expect(inMap(RegExp('레벨 2에 넓힐 수 있어요')), findsAtLeast(1));

    tester.semantics.tap(inMap('빈 땅, 지을 수 있어요').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('무엇을 지을까요?'), findsOneWidget);
    expect(find.text('염소 우리'), findsOneWidget); // 레벨이 모자란 건물도 다음 목표로 보인다
    await tester.tap(find.text('🪙 25'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(store.state.lots[const LotId(1, 2)]?.building, BuildingId.field);
    expect(find.text('심을 작물을 고르세요'), findsOneWidget);
    expect(find.text('🪙120에 Lv2로'), findsOneWidget); // 새로 지은 밭도 업그레이드할 수 있다
    expect(find.text('+ 수확량 +25%'), findsOneWidget);
    await tester.tapAt(const Offset(200, 40)); // 시트 밖을 눌러 닫는다
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    tester.semantics.tap(inMap('닭장'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('병아리 들이기 · 🪙30'), findsOneWidget);
    expect(find.text('지금 사료로 약 15시간 버텨요 · 한 묶음은 약 5시간 분량'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
    await _unmount(tester);
  });

  // 창고를 누르면 창고 탭으로 건너뛰던 때는 창고 업그레이드(한도·Lv3 자동 출하)에 닿을 길이 없었다.
  testWidgets('지도에서 창고를 누르면 창고 상세가 열리고 거기서 업그레이드할 수 있다', (tester) async {
    final semantics = tester.ensureSemantics();
    final store = await pumpApp(tester);
    await store.act((s) => s.copyWith(coins: 500));
    await tester.pump();
    final storehouse = find.semantics.descendant(
      of: find.semantics.byLabel('농장 지도'),
      matching: find.semantics.byLabel(RegExp('^창고')),
    );
    tester.semantics.tap(storehouse);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('업그레이드'), findsOneWidget);
    await tapAndSettle(tester, find.text('🪙200에 Lv2로'));
    expect(store.state.lots[GameDefs.storehouseLot]!.level, 2);
    expect(tester.takeException(), isNull);
    semantics.dispose();
    await _unmount(tester);
  });

  // 연못은 붙은 칸이 아니라 농장 전체에 효과가 있어 다른 꾸미기와 안내가 다르다.
  testWidgets('연못 상세는 농장 어디에 두어도 효과가 있다고 안내한다', (tester) async {
    final semantics = tester.ensureSemantics();
    final store = await pumpApp(tester);
    await store.act(
      (s) => GameEngine.build(s.copyWith(coins: 500, xp: GameDefs.xpForLevel(2)), const LotId(1, 2), BuildingId.pond),
    );
    await tester.pump();
    tester.semantics.tap(
      find.semantics.descendant(
        of: find.semantics.byLabel('농장 지도'),
        matching: find.semantics.byLabel(RegExp('^작은 연못')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('농장 어디에 두어도 효과가 있어요. 꾸미기는 올릴 수 없어요.'), findsOneWidget);
    expect(find.text('상하좌우로 붙은 칸에 효과가 있어요. 꾸미기는 올릴 수 없어요.'), findsNothing);
    semantics.dispose();
    await _unmount(tester);
  });

  testWidgets('오래 비웠다 돌아오면 그동안 일어난 일을 알려 준다', (tester) async {
    await pumpApp(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(hours: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1시간 동안 이런 일이 있었어요'), findsOneWidget);
    expect(find.text('밭 1곳의 작물이 다 자랐어요'), findsOneWidget);
    await tapAndSettle(tester, find.text('확인'));
    expect(find.byType(AlertDialog), findsNothing);
    await _unmount(tester);
  });

  testWidgets('날씨 표시를 누르면 하늘이 열리고 날씨 카드가 뜨며, 닫으면 평면으로 돌아오고 미리 보기는 잠깐 뒤 끝난다', (tester) async {
    await pumpApp(tester); // 10월 5일 14시 30분: 구름 많음(game_sky_test가 영향 없는 날씨임을 확인한다)
    expect(find.text('구름 많음'), findsOneWidget);
    await tapAndSettle(tester, find.text('구름 많음'));
    expect(find.text('농장 하늘 · 구름 많음'), findsOneWidget);
    expect(find.text('앞으로 12시간'), findsOneWidget);
    expect(find.text('16시에 날씨가 바뀌어요'), findsOneWidget);

    // 미리 보기 칩은 넘기지 않아도 모두 보인다(PC에서는 가로 목록을 마우스로 넘길 수 없었다).
    final winter = find.widgetWithText(ChoiceChip, '겨울');
    await tester.ensureVisible(winter);
    await tester.pump();
    expect(winter.hitTestable(), findsOneWidget);
    final rain = find.widgetWithText(ChoiceChip, '비');
    await tapAndSettle(tester, rain);
    // 미리 보기를 골라도 카드는 남아 하늘에서 바로 볼 수 있다.
    expect(find.text('앞으로 12시간'), findsOneWidget);
    await tapAndSettle(tester, find.byTooltip('닫기'));
    expect(find.text('앞으로 12시간'), findsNothing);
    expect(find.text('미리 보기 · 비'), findsOneWidget);
    await tester.pump(const Duration(seconds: 13));
    expect(find.text('미리 보기 · 비'), findsNothing);
    expect(find.text('구름 많음'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('하늘 보기 중에 하늘을 누르면 평면으로 돌아온다', (tester) async {
    await pumpApp(tester);
    await tapAndSettle(tester, find.text('구름 많음'));
    expect(find.text('앞으로 12시간'), findsOneWidget);
    // 하늘(지도 위쪽)을 누른다. 지도판 위를 누르는 경우는 farm_map_view_test가 확인한다.
    await tester.tapAt(tester.getRect(find.byType(FarmMapView)).topCenter + const Offset(0, 40));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('앞으로 12시간'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('구름 많음'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('스크린리더로 날씨 표시를 두 번 탭하면 하늘이 열리고 날씨 카드가 뜬다', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    tester.semantics.tap(find.semantics.byLabel('농장 하늘: 구름 많음'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('앞으로 12시간'), findsOneWidget);
    semantics.dispose();
    await _unmount(tester);
  });

  testWidgets('하늘 보기에서 구역을 고르면 눕힌 채로 다가가고, 하늘을 누를 때마다 한 단계씩 돌아온다', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await pumpApp(tester, size: const Size(1440, 900));
    await tapAndSettle(tester, find.text('구름 많음'));
    tester.semantics.tap(find.semantics.byLabel('빈 땅, 지을 수 있어요').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // 구역 상세가 뜨고 하늘 보기(날씨 카드)는 그대로다.
    expect(find.text('무엇을 지을까요?'), findsOneWidget);
    expect(find.text('앞으로 12시간'), findsOneWidget);
    final sky = tester.getRect(find.byType(FarmMapView)).topCenter + const Offset(0, 30);
    await tester.tapAt(sky);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('무엇을 지을까요?'), findsNothing);
    expect(find.text('앞으로 12시간'), findsOneWidget);
    await tester.tapAt(sky);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('앞으로 12시간'), findsNothing);
    semantics.dispose();
    await _unmount(tester);
  });

  testWidgets('넓은 화면에서는 구역을 고르면 지도를 가리지 않고 오른쪽 열에 상세가 뜬다', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await pumpApp(tester, size: const Size(1440, 900));
    tester.semantics.tap(find.semantics.byLabel('빈 땅, 지을 수 있어요').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(BottomSheet), findsNothing);
    final need = find.text('무엇을 지을까요?');
    expect(need, findsOneWidget);
    expect(tester.getTopLeft(need).dx, greaterThan(tester.getTopRight(find.bySemanticsLabel('농장 지도')).dx));
    await tapAndSettle(tester, find.byTooltip('닫기'));
    expect(find.text('무엇을 지을까요?'), findsNothing);
    semantics.dispose();
    await _unmount(tester);
  });

  testWidgets('관리 앱(1.x) 기록이 있으면 보관했다고 알린다', (tester) async {
    final legacy = jsonEncode({
      'schemaVersion': 4,
      'profile': {'name': '초록골 농장'},
    });
    await pumpApp(tester, storage: MemoryStorage(legacy));
    expect(find.textContaining('방치형 농장 게임으로 바뀌었어요'), findsOneWidget);
    expect(find.text('초록골 농장'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('새 버전이 있으면 농장 화면에서 안내 시트를 열고, 설정에 업데이트 설정이 나온다', (tester) async {
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

    await tapAndSettle(tester, find.text('새 버전 9.9.0 사용 가능'));
    expect(find.text('내려받을 크기 52.0MB. 업데이트해도 농장 기록은 그대로 남아요.'), findsOneWidget);
    await tapAndSettle(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('나중에')));
    expect(find.byType(BottomSheet), findsNothing);

    await tapAndSettle(tester, find.text('설정').last);
    await tester.scrollUntilVisible(
      find.text('새 버전 자동 확인'),
      300,
      scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first,
    );
    expect(find.text('설치된 버전 1.6.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('넓은 화면(PC)에서는 옆 메뉴와 두 열 배치로 모든 탭이 오류 없이 그려진다', (tester) async {
    // MediaQuery는 테스트 뷰 크기를 따르므로 뷰도 PC 창 크기로 맞춘다.
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await pumpApp(tester, size: const Size(1440, 900));
    expect(find.text('마이팜'), findsOneWidget);
    // 옆 메뉴는 화면 위에서 아래까지 꽉 찬다(내용 높이로 줄어 가운데에 뜨지 않는다).
    final sideBar = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SideBar');
    expect(tester.getTopLeft(sideBar).dy, 0);
    expect(tester.getSize(sideBar).height, 900);
    // 농장은 두 열이다: 지도(왼쪽)와 할 일(오른쪽)이 나란히 있다.
    final map = find.bySemanticsLabel('농장 지도');
    expect(tester.getTopLeft(find.text('할 일')).dx, greaterThan(tester.getTopRight(map).dx));
    for (final tab in ['창고', '기록', '설정', '농장']) {
      await tester.tap(find.text(tab).last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: tab);
    }
    await _unmount(tester);
  });

  testWidgets('창 폭이 넓은 배치와 휴대폰 배치를 오가도 설정의 저장 전 입력이 남는다', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await pumpApp(tester, size: const Size(1440, 900));
    await tester.tap(find.text('설정').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.widgetWithText(TextField, '농장 이름'), '바뀐 농장');
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

  testWidgets('영어로 바꾸면 화면이 영어로 나온다', (tester) async {
    await pumpApp(tester, locale: 'en');
    expect(find.text('Sunny Farm'), findsOneWidget);
    expect(find.text('To do'), findsOneWidget);
    expect(find.text('Collect eggs'), findsOneWidget);
    for (final tab in ['Barn', 'Records', 'Settings']) {
      await tester.tap(find.text(tab).last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: tab);
    }
    expect(find.text('Farm details'), findsOneWidget);
    await _unmount(tester);
  });
}

/// 화면 애니메이션의 지연 타이머가 남지 않도록 트리를 내리고 시간을 흘려보낸다.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}
