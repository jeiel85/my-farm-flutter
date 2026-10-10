import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/features/reminders/reminders.dart';
import 'package:my_farm/game/defs.dart';
import 'package:my_farm/game/engine.dart';
import 'package:my_farm/game/game_store.dart';
import 'package:my_farm/game/reminder_plan.dart';
import 'package:my_farm/game/state.dart';
import 'package:my_farm/game/lots.dart';
import 'package:my_farm/l10n/l10n.dart';

import 'support/memory_storage.dart';

class FakeReminderPlatform implements ReminderPlatform {
  bool grant = true;
  bool enabledInSettings = true;
  Object? failWith;
  List<ReminderNotice> scheduled = [];
  int replaceCalls = 0;

  String? appName;

  @override
  Future<void> init({required String appName}) async => this.appName = appName;

  @override
  Future<bool> requestPermission() async => grant;

  @override
  Future<bool> permitted() async => enabledInSettings;

  @override
  Future<void> replaceAll(List<ReminderNotice> notices) async {
    if (failWith != null) throw failWith!;
    replaceCalls++;
    scheduled = notices;
  }

  @override
  Future<void> cancelScheduled() async => scheduled = [];
}

void main() {
  final now = DateTime(2026, 10, 5, 14, 30);
  const on = ReminderSettings(enabled: true);

  // 새 게임: 상추가 1분 뒤 다 자라고, 닭 두 마리(한 마리는 달걀 1개)가 6분마다 달걀을 낳는다(최대 5개).
  GameState fresh([DateTime? at]) => GameEngine.newGame(at ?? now, farmName: 'test');

  GameState withField(GameState s, LotId lot, FieldState f) => s.copyWith(
    lots: {
      ...s.lots,
      lot: Lot(s.lots[lot]?.building ?? BuildingId.field, field: f),
    },
  );

  group('알림 계획', () {
    test('꺼져 있으면 아무것도 잡지 않는다', () {
      expect(planReminders(fresh(), now, const ReminderSettings()), isEmpty);
    });

    test('작물이 다 자라는 시각, 생산물이 처음 가득 차는 시각을 순서대로 잡는다', () {
      final plan = planReminders(fresh(), now, on);
      final harvest = plan.whereType<HarvestReminder>().single;
      expect(harvest.at, DateTime(2026, 10, 5, 14, 31));
      expect(harvest.crops, [CropId.lettuce]);
      // 달걀 1개인 닭이 4개를 더 낳아 가득 차는 14:54에 한 번만.
      final animals = plan.whereType<AnimalsReminder>().single;
      expect((animals.at, animals.species), (DateTime(2026, 10, 5, 14, 54), Species.chicken));
      // 사료 60이면 4시간 안에 떨어지지 않는다.
      expect(plan.whereType<FeedReminder>(), isEmpty);
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i - 1].at.isAfter(plan[i].at), isFalse);
      }
    });

    test('같은 분에 다 자라는 작물은 한 알림으로 묶는다', () {
      var s = fresh();
      s = withField(s, const LotId(1, 2), const FieldState(crop: CropId.carrot, minutesLeft: 1, totalMinutes: 6));
      final harvest = planReminders(s, now, on).whereType<HarvestReminder>().single;
      expect(harvest.crops, [CropId.lettuce, CropId.carrot]);
    });

    test('사료가 떨어지는 시각을 알리고, 그 뒤 멈춘 생산은 가득 참으로 알리지 않는다', () {
      // 닭 두 마리가 1분에 4단위씩 먹으므로 40단위면 10분 뒤 바닥난다.
      final s = fresh().copyWith(feedUnits: 40);
      final plan = planReminders(s, now, on);
      expect(plan.whereType<FeedReminder>().single.at, DateTime(2026, 10, 5, 14, 41));
      expect(plan.whereType<AnimalsReminder>(), isEmpty);
    });

    test('이미 그런 상태인 것(다 자람·가득 참·사료 없음)은 앱 화면에 나오므로 보내지 않는다', () {
      var s = withField(
        fresh(),
        GameDefs.startFieldLot,
        const FieldState(crop: CropId.lettuce, ready: true, totalMinutes: 2),
      );
      s = s.copyWith(
        feedUnits: 0,
        animals: [for (final a in s.animals) a.copyWith(stored: GameDefs.animals[Species.chicken]!.storeCap)],
      );
      expect(planReminders(s, now, on), isEmpty);
    });

    test('앱을 닫아 둔 동안 진행되는 4시간 안의 일만 잡는다', () {
      final s = withField(
        fresh().copyWith(animals: const []),
        GameDefs.startFieldLot,
        const FieldState(crop: CropId.carrot, minutesLeft: 241, totalMinutes: 300),
      );
      expect(planReminders(s, now, on), isEmpty);
      final soon = withField(
        s,
        GameDefs.startFieldLot,
        const FieldState(crop: CropId.carrot, minutesLeft: 240, totalMinutes: 300),
      );
      expect(planReminders(soon, now, on).single.at, now.add(const Duration(minutes: 240)));
    });

    test('밤 9시~아침 7시에 일어나는 일은 아침 7시로 미룬다', () {
      final evening = DateTime(2026, 10, 5, 20, 50);
      final s = withField(
        fresh(evening).copyWith(animals: const []),
        GameDefs.startFieldLot,
        const FieldState(crop: CropId.carrot, minutesLeft: 20, totalMinutes: 20),
      );
      expect(planReminders(s, evening, on).single.at, DateTime(2026, 10, 6, 7));
    });

    test('종류를 끄면 그 종류는 빠진다', () {
      final plan = planReminders(fresh(), now, const ReminderSettings(enabled: true, harvest: false));
      expect(plan.whereType<HarvestReminder>(), isEmpty);
      expect(plan.whereType<AnimalsReminder>(), hasLength(1));
    });

    test('알림 id는 내용(종류·시각·대상)으로 정해져 다시 계산해도 같고, 서로 겹치지 않는다', () {
      final first = planReminders(fresh(), now, on);
      final again = planReminders(fresh(), now, on);
      final ids = [for (final r in first) reminderId(r)];
      expect([for (final r in again) reminderId(r)], ids);
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids.every((id) => id >= 0 && id <= 0x7fffffff), isTrue);
      final at = DateTime(2026, 10, 6, 7);
      expect(
        reminderId(HarvestReminder(at, const [CropId.lettuce])),
        isNot(reminderId(HarvestReminder(at, const [CropId.carrot]))),
      );
    });

    test('설정은 JSON으로 오가고, 읽을 수 없으면 꺼진 기본값이다. 1.x 설정은 켜기 여부만 이어받는다', () {
      const s = ReminderSettings(enabled: true, animals: false);
      final back = ReminderSettings.fromJson(s.toJson());
      expect((back.enabled, back.harvest, back.animals, back.feed), (true, true, false, true));
      expect(ReminderSettings.fromJson('nope').enabled, isFalse);
      expect(ReminderSettings.fromJson({'enabled': 'yes'}).enabled, isFalse);
      final legacy = ReminderSettings.fromJson({'enabled': true, 'watering': false, 'feeding': false, 'care': false});
      expect((legacy.enabled, legacy.harvest, legacy.animals, legacy.feed), (true, true, true, true));
    });
  });

  group('알림 컨트롤러', () {
    late GameStore store;
    late MemoryStorage storage;
    late FakeReminderPlatform platform;

    Future<ReminderController> controller() async {
      final c = ReminderController(
        store: store,
        platform: platform,
        storage: storage,
        localizations: () => lookupAppLocalizations(const Locale('ko')),
        debounce: Duration.zero,
      );
      addTearDown(c.dispose);
      await c.init();
      return c;
    }

    setUp(() async {
      storage = MemoryStorage();
      store = await GameStore.load(storage, clock: () => now, defaultFarmName: '햇살 농장');
      platform = FakeReminderPlatform();
    });

    test('권한을 거절하면 꺼진 채로 두고, 허락하면 설정을 저장하고 문구를 만들어 예약한다', () async {
      final c = await controller();
      expect(platform.appName, '마이팜');
      expect(platform.scheduled, isEmpty);

      platform.grant = false;
      expect(await c.setEnabled(true), isFalse);
      expect(c.settings.enabled, isFalse);
      expect(platform.scheduled, isEmpty);

      platform.grant = true;
      expect(await c.setEnabled(true), isTrue);
      expect(storage.meta[ReminderController.metaKey], contains('"enabled":true'));
      expect(c.scheduledCount, platform.scheduled.length);
      expect(c.nextAt, platform.scheduled.first.at);
      expect({for (final n in platform.scheduled) n.id}, hasLength(platform.scheduled.length));
      final harvest = platform.scheduled.firstWhere((n) => n.kind == ReminderKind.harvest);
      expect((harvest.title, harvest.body, harvest.channelName), ('작물이 다 자랐어요', '수확할 때예요: 상추', '수확 시기'));
      final animals = platform.scheduled.firstWhere((n) => n.kind == ReminderKind.animals);
      expect((animals.title, animals.body), ('닭: 생산물이 가득 찼어요', '달걀 보관함이 가득 차 생산이 멈췄어요. 모아 주세요.'));

      // 다음에 열면 저장된 설정으로 다시 예약한다.
      platform.scheduled = [];
      final again = await controller();
      expect(again.settings.enabled, isTrue);
      expect(platform.scheduled, isNotEmpty);
    });

    test('행동하면 다시 예약하고, 매초 시계는 무시하며, 끄면 모두 취소한다', () async {
      final c = await controller();
      await c.setEnabled(true);
      final calls = platform.replaceCalls;

      await store.tick();
      await Future<void>.delayed(Duration.zero);
      expect(platform.replaceCalls, calls, reason: '시계만 돌면 예정 시각이 그대로라 다시 계산하지 않는다');

      // 달걀을 모두 모으면 가득 차는 시각이 늦어진다.
      final before = platform.scheduled.firstWhere((n) => n.kind == ReminderKind.animals).at;
      await store.actWith((s) => GameEngine.collect(s, GameDefs.startCoopLot));
      await Future<void>.delayed(Duration.zero);
      await c.sync();
      expect(platform.replaceCalls, greaterThan(calls));
      expect(platform.scheduled.firstWhere((n) => n.kind == ReminderKind.animals).at.isAfter(before), isTrue);

      await c.setKind(ReminderKind.animals, false);
      expect(platform.scheduled.where((n) => n.kind == ReminderKind.animals), isEmpty);

      await c.setEnabled(false);
      expect(platform.scheduled, isEmpty);
      expect(c.scheduledCount, 0);
    });

    // 언어를 바꾸면 예약해 둔 알림 문구도 바로 새 언어로 다시 만든다(#32 리뷰).
    test('언어를 바꾸면 행동이 없어도 알림을 새 언어로 다시 예약한다', () async {
      final c = ReminderController(
        store: store,
        platform: platform,
        storage: storage,
        localizations: () => lookupAppLocalizations(Locale(store.localeOverride ?? 'ko')),
        debounce: Duration.zero,
      );
      addTearDown(c.dispose);
      await c.init();
      await c.setEnabled(true);
      String harvestTitle() => platform.scheduled.firstWhere((n) => n.kind == ReminderKind.harvest).title;
      expect(harvestTitle(), '작물이 다 자랐어요');

      await store.setLocaleOverride('en');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(harvestTitle(), lookupAppLocalizations(const Locale('en')).notifHarvestTitle);
    });

    test('휴대폰 설정에서 알림이 꺼졌거나 예약에 실패하면 알려 준다', () async {
      final c = await controller();
      await c.setEnabled(true);
      platform.enabledInSettings = false;
      await c.sync();
      expect(c.permissionMissing, isTrue);

      platform.failWith = StateError('alarm limit');
      await c.sync();
      expect(c.lastError, isA<StateError>());
      platform.failWith = null;
      await c.sync();
      expect(c.lastError, isNull);
    });
  });
}
