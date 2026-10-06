import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/data/farm_state.dart';
import 'package:my_farm/data/farm_store.dart';
import 'package:my_farm/data/models.dart';
import 'package:my_farm/data/reminder_plan.dart';
import 'package:my_farm/data/seed.dart';
import 'package:my_farm/features/reminders/reminders.dart';
import 'package:my_farm/l10n/l10n.dart';

import 'farm_store_test.dart' show MemoryStorage;

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
  Future<void> cancelAll() async => scheduled = [];
}

void main() {
  final now = DateTime(2026, 10, 5, 14, 30);
  const on = ReminderSettings(enabled: true);
  const onlyWatering = ReminderSettings(enabled: true, feeding: false, care: false);

  /// 예시 농장에서 밭만 [fields]로 바꾼 상태.
  FarmState withFields(List<CropField> fields) => buildDemoFarm(now).copyWith(fields: fields, careItems: const []);

  CropField field(String crop, {required DateTime lastWatered, int hours = 24}) =>
      buildDemoFarm(now).fields.first.copyWith(cropName: crop, lastWateredAt: lastWatered, waterIntervalHours: hours);

  group('알림 계획', () {
    test('꺼져 있으면 아무것도 잡지 않는다', () {
      expect(planReminders(buildDemoFarm(now), now, const ReminderSettings()), isEmpty);
    });

    test('물주기: 다음 시각에, 같은 시각 밭은 묶고, 이미 지난 것은 빼고, 밤 시간은 아침 7시로 미룬다', () {
      final state = withFields([
        field('토마토', lastWatered: DateTime(2026, 10, 5, 10)), // 내일 10시
        field('딸기', lastWatered: DateTime(2026, 10, 5, 10)), // 같은 시각이라 함께
        field('상추', lastWatered: DateTime(2026, 10, 5, 14), hours: 9), // 오늘 23시 → 내일 7시
        field('당근', lastWatered: DateTime(2026, 10, 5, 14), hours: 38), // 모레 4시 → 모레 7시
        field('옥수수', lastWatered: DateTime(2026, 10, 4, 9)), // 오늘 9시, 이미 지남
      ]);
      final plan = planReminders(state, now, onlyWatering).cast<WateringReminder>();
      expect(
        [for (final r in plan) (r.at, r.crops.join(','))],
        [(DateTime(2026, 10, 6, 7), '상추'), (DateTime(2026, 10, 6, 10), '토마토,딸기'), (DateTime(2026, 10, 7, 7), '당근')],
      );
    });

    test('급이: 앞으로 7일 회차를 잡되 지난 시각과 오늘 이미 체크한 회차는 뺀다', () {
      final base = buildDemoFarm(now).copyWith(fields: const [], careItems: const []);
      final slots = base.feedingSlots; // 6:00, 12:00, 18:00
      expect([for (final s in slots) s.hour], [6, 12, 18]);
      final plan = planReminders(base, now, const ReminderSettings(enabled: true, watering: false, care: false));
      expect(plan.first.at, DateTime(2026, 10, 5, 18));
      expect(plan, hasLength(1 + 6 * 3));
      expect(plan.last.at, DateTime(2026, 10, 11, 18));

      final done = base.copyWith(
        feedingDone: {
          dateKeyOf(now): [2],
        },
      );
      final afterDone = planReminders(done, now, const ReminderSettings(enabled: true, watering: false, care: false));
      expect(afterDone.first.at, DateTime(2026, 10, 6, 6));
    });

    test('백신·진료: 14일 안의 일정을 그날 아침 8시에, 끝났거나 대상이 없어진 일정은 뺀다', () {
      final base = buildDemoFarm(now).copyWith(fields: const []);
      final cow = base.animals.firstWhere((a) => a.kind == AnimalKind.cow);
      CareItem care(String id, DateTime due, {String? animalId, DateTime? doneAt}) => CareItem(
        id: id,
        kind: AnimalKind.cow,
        animalId: animalId,
        type: CareType.vaccine,
        title: id,
        dueDate: due,
        repeatMonths: 0,
        doneAt: doneAt,
        note: '',
      );
      final state = base.copyWith(
        careItems: [
          care('today', DateTime(2026, 10, 5)), // 오늘 8시는 지남
          care('tomorrow', DateTime(2026, 10, 6), animalId: cow.id),
          care('done', DateTime(2026, 10, 7), doneAt: now),
          care('gone', DateTime(2026, 10, 7), animalId: 'cow-missing'),
          care('in13', DateTime(2026, 10, 18)),
          care('in20', DateTime(2026, 10, 25)),
        ],
      );
      final plan = planReminders(state, now, const ReminderSettings(enabled: true, watering: false, feeding: false));
      expect(
        [for (final r in plan.cast<CareReminder>()) (r.item.id, r.at, r.animal?.id)],
        [('tomorrow', DateTime(2026, 10, 6, 8), cow.id), ('in13', DateTime(2026, 10, 18, 8), null)],
      );
    });

    test('시각 순으로 정렬하고 최대 개수에서 자른다', () {
      final plan = planReminders(buildDemoFarm(now), now, on, maxCount: 5);
      expect(plan, hasLength(5));
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i - 1].at.isAfter(plan[i].at), isFalse);
      }
    });

    test('설정은 JSON으로 오가고, 읽을 수 없으면 꺼진 기본값이다', () {
      final s = const ReminderSettings(enabled: true, feeding: false);
      final back = ReminderSettings.fromJson(s.toJson());
      expect((back.enabled, back.watering, back.feeding, back.care), (true, true, false, true));
      expect(ReminderSettings.fromJson('nope').enabled, isFalse);
      expect(ReminderSettings.fromJson({'enabled': 'yes'}).enabled, isFalse);
    });
  });

  group('알림 컨트롤러', () {
    late FarmStore store;
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
      store = await FarmStore.load(storage, clock: () => now);
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
      expect(platform.scheduled, isNotEmpty);
      expect(c.scheduledCount, platform.scheduled.length);
      expect(c.nextAt, platform.scheduled.first.at);
      expect({for (final n in platform.scheduled) n.id}, hasLength(platform.scheduled.length));
      final feeding = platform.scheduled.firstWhere((n) => n.kind == ReminderKind.feeding);
      expect(feeding.title, contains('18:00'));
      // 회차 이름에 '급이'가 들어 있어도(예: 저녁 급이) 본문에서 다시 쓰지 않는다.
      expect(feeding.body, isNot(contains('급이')));
      expect(feeding.channelName, '급이');
      final watering = platform.scheduled.firstWhere((n) => n.kind == ReminderKind.watering);
      expect(watering.title, '물 줄 시간이에요');

      // 다음에 열면 저장된 설정으로 다시 예약한다.
      platform.scheduled = [];
      final again = await controller();
      expect(again.settings.enabled, isTrue);
      expect(platform.scheduled, isNotEmpty);
    });

    test('기록이 바뀌면 다시 예약하고, 종류를 끄면 그 종류가 빠지며, 끄면 모두 취소한다', () async {
      final c = await controller();
      await c.setEnabled(true);
      final calls = platform.replaceCalls;
      final feedingBefore = platform.scheduled.where((n) => n.kind == ReminderKind.feeding).length;

      await store.toggleFeeding(2); // 오늘 18시 회차 완료
      await Future<void>.delayed(Duration.zero);
      await c.sync();
      expect(platform.replaceCalls, greaterThan(calls));
      expect(platform.scheduled.where((n) => n.kind == ReminderKind.feeding), hasLength(feedingBefore - 1));

      await c.setKind(ReminderKind.feeding, false);
      expect(platform.scheduled.where((n) => n.kind == ReminderKind.feeding), isEmpty);

      await c.setEnabled(false);
      expect(platform.scheduled, isEmpty);
      expect(c.scheduledCount, 0);
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
