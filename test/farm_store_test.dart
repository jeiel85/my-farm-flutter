import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/data/farm_state.dart';
import 'package:my_farm/data/farm_store.dart';
import 'package:my_farm/data/models.dart';
import 'package:my_farm/data/seed.dart';

class MemoryStorage implements FarmStorage {
  MemoryStorage([this.value]);

  String? value;

  /// keepCopy로 따로 보관된 (라벨, 내용) 목록.
  final copies = <(String, String)>[];

  List<String> copiesLabeled(String label) => [
    for (final (l, raw) in copies)
      if (l == label) raw,
  ];
  bool failWrites = false;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async {
    if (failWrites) throw StateError('disk full');
    value = json;
  }

  @override
  Future<void> keepCopy(String raw, String label) async => copies.add((label, raw));

  final meta = <String, String>{};

  @override
  Future<String?> readMeta(String key) async => meta[key];

  @override
  Future<void> writeMeta(String key, String value) async => meta[key] = value;
}

void main() {
  final now = DateTime(2026, 10, 5, 14, 30);
  DateTime clock() => now;

  Future<(FarmStore, MemoryStorage)> fresh() async {
    final storage = MemoryStorage();
    final store = await FarmStore.load(storage, clock: clock);
    return (store, storage);
  }

  test('처음 실행하면 예시 농장을 만들고 저장한다', () async {
    final (store, storage) = await fresh();
    expect(store.totalAnimals, 48);
    expect(store.countOf(AnimalKind.cow), 18);
    expect(store.countOf(AnimalKind.chicken), 20);
    expect(storage.value, isNotNull);
  });

  test('저장한 상태는 JSON 왕복 후에도 같다', () async {
    final state = buildDemoFarm(now);
    final restored = FarmState.fromJson(jsonDecode(jsonEncode(state.toJson())) as Map<String, Object?>);
    expect(jsonEncode(restored.toJson()), jsonEncode(state.toJson()));
  });

  test('손상된 저장본은 지우지 않고 보관한 뒤 예시 농장으로 시작한다', () async {
    final storage = MemoryStorage('{not json');
    final store = await FarmStore.load(storage, clock: clock);
    expect(storage.copiesLabeled('corrupt'), ['{not json']);
    expect(store.recoveredFromCorruptData, isTrue);
    expect(store.totalAnimals, 48);
  });

  test('더 새로운 형식은 읽지 않고 보관한 뒤 예시 농장으로 시작한다', () async {
    final storage = MemoryStorage(jsonEncode({'schemaVersion': 99}));
    final store = await FarmStore.load(storage, clock: clock);
    expect(storage.copiesLabeled('corrupt'), hasLength(1));
    expect(store.recoveredFromCorruptData, isTrue);
  });

  test('v1 저장본은 최신 형식으로 마이그레이션하고 원본을 따로 보관한다', () async {
    final v1 = buildDemoFarm(now).toJson()
      ..remove('animalEvents')
      ..remove('feedingUsage')
      ..remove('careItems')
      ..['schemaVersion'] = 1;
    final raw = jsonEncode(v1);
    final storage = MemoryStorage(raw);
    final store = await FarmStore.load(storage, clock: clock);
    expect(store.recoveredFromCorruptData, isFalse);
    expect(store.totalAnimals, 48);
    expect(store.state.animalEvents, isEmpty);
    expect(storage.copiesLabeled('pre_migration_v1'), [raw]);
    expect((jsonDecode(storage.value!) as Map)['schemaVersion'], FarmState.schemaVersion);
  });

  test('물을 주면 물탱크가 줄고 마지막 관수 시각이 바뀐다', () async {
    final (store, _) = await fresh();
    final tomato = store.fieldById('tomato')!;
    final before = store.state.tankStoredL;
    await store.waterField('tomato');
    expect(store.state.tankStoredL, before - tomato.litersPerWatering);
    expect(store.fieldById('tomato')!.lastWateredAt, now);
    expect(store.waterUsedToday, tomato.litersPerWatering);
  });

  test('물탱크가 부족하면 물주기를 거부한다', () async {
    final (store, _) = await fresh();
    // 물탱크를 거의 비운다.
    while (store.state.tankStoredL >= store.fieldById('orchard')!.litersPerWatering) {
      await store.waterField('orchard');
    }
    expect(() => store.waterField('orchard'), throwsA(isA<InsufficientWaterException>()));
  });

  test('스마트 관수는 곧 물이 필요한 밭에만 물을 주고, 보충하면 가득 찬다', () async {
    final (store, _) = await fresh();
    final due = store.state.fields.where((f) => !f.nextWateringAt.isAfter(now.add(const Duration(hours: 2)))).length;
    final (watered, skipped) = await store.smartWatering();
    expect(watered + skipped, due);
    expect(store.fieldsNeedingWater, isEmpty);
    await store.refillTank();
    expect(store.tankRatio, 1);
  });

  test('급이 체크는 오늘 날짜에 토글된다', () async {
    final (store, _) = await fresh();
    // 14:30 기준 예시 데이터는 06시·12시 급이를 마친 상태.
    expect(store.feedingDoneToday, {0, 1});
    expect(store.nextFeeding!.hour, 18);
    await store.toggleFeeding(2);
    expect(store.nextFeeding, isNull);
    await store.toggleFeeding(0);
    expect(store.feedingDoneToday, {1, 2});
  });

  test('수확하고 다시 심으면 생육률이 0부터 시작한다', () async {
    final (store, _) = await fresh();
    final count = store.state.harvests.length;
    await store.harvest(fieldId: 'vegetable', amountKg: 12.5, replant: true);
    expect(store.state.harvests.length, count + 1);
    expect(store.state.harvests.first.amountKg, 12.5);
    expect(store.fieldById('vegetable')!.growthAt(now), 0);
  });

  test('생산 기록은 하루에 하나로 덮어쓴다', () async {
    final (store, _) = await fresh();
    await store.recordProduction(eggs: 9, milkL: 90);
    await store.recordProduction(eggs: 18, milkL: 180);
    expect(store.state.production.where((p) => p.dateKey == dateKeyOf(now)), hasLength(1));
    expect(store.productionRatio, 1);
  });

  test('재고는 0 아래로 내려가지 않고 기준 이하면 부족으로 표시된다', () async {
    final (store, _) = await fresh();
    expect(store.lowInventory.map((i) => i.id), contains('npk'));
    await store.adjustInventory('npk', -100);
    expect(store.state.inventory.firstWhere((i) => i.id == 'npk').quantity, 0);
    await store.adjustInventory('npk', 10);
    expect(store.lowInventory.map((i) => i.id), isNot(contains('npk')));
  });

  test('할 일 추가·완료·삭제', () async {
    final (store, _) = await fresh();
    await store.addTask('  울타리 수리  ');
    final task = store.tasksToday.last;
    expect(task.title, '울타리 수리');
    await store.toggleTask(task.id);
    expect(store.tasksToday.last.done, isTrue);
    await store.deleteTask(task.id);
    expect(store.tasksToday.any((t) => t.id == task.id), isFalse);
    await store.addTask('   ');
    expect(store.tasksToday.any((t) => t.title.isEmpty), isFalse);
  });

  test('저장에 실패하면 오류를 알리고, 다음 저장이 성공하면 지운다', () async {
    final (store, storage) = await fresh();
    storage.failWrites = true;
    await store.addTask('저장 실패 테스트');
    expect(store.saveError, isNotNull);
    storage.failWrites = false;
    await store.addTask('다시 저장');
    expect(store.saveError, isNull);
  });

  test('생육률과 수확까지 남은 날은 파종일 기준으로 계산된다', () {
    final field = CropField(
      id: 'x',
      zone: ZoneId.tomato,
      cropName: '테스트',
      emoji: '🌱',
      plantedAt: now.subtract(const Duration(days: 30)),
      growDays: 60,
      status: CropStatus.good,
      lastWateredAt: now,
      waterIntervalHours: 24,
      litersPerWatering: 10,
    );
    expect(field.growthAt(now), closeTo(0.5, 0.001));
    expect(field.daysToHarvest(now), 30);
    expect(field.growthAt(now.add(const Duration(days: 90))), 1);
    expect(field.daysToHarvest(now.add(const Duration(days: 90))), 0);
  });

  group('가축 입식·제외', () {
    test('새 가축은 다음 번호표를 받고 입식 이력이 남는다', () async {
      final (store, _) = await fresh();
      final expected = store.nextTag(AnimalKind.goat);
      final goat = await store.addAnimal(
        kind: AnimalKind.goat,
        name: ' 흰둥이 ',
        breed: '',
        birthDate: DateTime(2026, 3, 1),
        weightKg: 31.5,
      );
      expect(goat.tag, expected);
      expect(goat.name, '흰둥이');
      // 빈 품종은 그대로 두고 화면에서 "품종 미상"으로 표시한다.
      expect(goat.breed, isEmpty);
      expect(store.countOf(AnimalKind.goat), 5);
      expect(store.state.animalEvents.first.type, AnimalEventType.added);
      expect(store.nextTag(AnimalKind.goat), isNot(expected));
    });

    test('이름이 비었거나 체중이 0 이하면 거부한다', () async {
      final (store, _) = await fresh();
      expect(
        () => store.addAnimal(kind: AnimalKind.cow, name: ' ', breed: '', birthDate: now, weightKg: 100),
        throwsArgumentError,
      );
      expect(
        () => store.addAnimal(kind: AnimalKind.cow, name: '소', breed: '', birthDate: now, weightKg: 0),
        throwsArgumentError,
      );
    });

    test('출하하면 목록에서 빠지고 이력이 남으며, 번호표는 다시 쓰지 않는다', () async {
      final (store, _) = await fresh();
      final last = store
          .animalsOf(AnimalKind.sheep)
          .reduce((a, b) => int.parse(a.tag.split('-').last) > int.parse(b.tag.split('-').last) ? a : b);
      final before = store.nextTag(AnimalKind.sheep);
      await store.removeAnimal(last.id, type: AnimalEventType.sold, note: '시장 출하');
      expect(store.animalById(last.id), isNull);
      expect(store.state.animalEvents.first.tag, last.tag);
      expect(store.state.animalEvents.first.note, '시장 출하');
      expect(store.nextTag(AnimalKind.sheep), before);
    });
  });

  group('급이와 사료 재고', () {
    double qty(FarmStore s, String id) => s.state.inventory.firstWhere((i) => i.id == id).quantity;

    test('급이를 완료하면 하루 사용량 ÷ 급이 횟수만큼 빠지고, 취소하면 되돌아온다', () async {
      final (store, _) = await fresh();
      final hay = qty(store, 'hay');
      final shortages = await store.toggleFeeding(2);
      expect(shortages, isEmpty);
      expect(qty(store, 'hay'), closeTo(hay - 200 / 3, 1e-9));
      await store.toggleFeeding(2);
      expect(qty(store, 'hay'), closeTo(hay, 1e-9));
    });

    test('재고가 모자라면 남은 만큼만 빼고 모자란 사료를 알려 준다', () async {
      final (store, _) = await fresh();
      await store.adjustInventory('layer', -(qty(store, 'layer') - 0.5));
      final shortages = await store.toggleFeeding(2);
      expect(shortages, ['산란계 사료']);
      expect(qty(store, 'layer'), 0);
      await store.toggleFeeding(2);
      expect(qty(store, 'layer'), closeTo(0.5, 1e-9));
    });

    test('차감 기록이 없는 완료(예시 데이터)는 취소해도 재고가 늘지 않는다', () async {
      final (store, _) = await fresh();
      final hay = qty(store, 'hay');
      expect(store.feedingDoneToday, contains(0));
      await store.toggleFeeding(0);
      expect(qty(store, 'hay'), hay);
    });
  });

  group('백업', () {
    test('내보낸 백업을 다시 읽으면 같은 상태가 된다', () async {
      final (store, _) = await fresh();
      await store.addTask('백업 확인');
      final text = store.exportBackup();
      final contents = FarmStore.parseBackup(text);
      expect(jsonEncode(contents.state.toJson()), jsonEncode(store.state.toJson()));
      expect(contents.exportedAt, now);
    });

    test('복원하면 덮어쓰기 전 데이터를 따로 보관한다', () async {
      final (store, storage) = await fresh();
      final backup = FarmStore.parseBackup(store.exportBackup());
      await store.addTask('복원 전에만 있던 일');
      final before = storage.value;
      await store.restoreBackup(backup.state);
      expect(storage.copiesLabeled('before_restore'), [before]);
      expect(store.tasksToday.any((t) => t.title == '복원 전에만 있던 일'), isFalse);
    });

    test('형식이 다른 파일은 이유와 함께 거부한다', () {
      Matcher problem(BackupProblem p) => throwsA(isA<BackupException>().having((e) => e.problem, 'problem', p));
      expect(() => FarmStore.parseBackup('not json'), problem(BackupProblem.notJson));
      expect(() => FarmStore.parseBackup('{"format":"other"}'), problem(BackupProblem.notBackup));
      expect(
        () => FarmStore.parseBackup(
          jsonEncode({
            'format': FarmStore.backupFormat,
            'state': {'schemaVersion': 99},
          }),
        ),
        problem(BackupProblem.newerVersion),
      );
      expect(
        () => FarmStore.parseBackup(
          jsonEncode({
            'format': FarmStore.backupFormat,
            'state': {'schemaVersion': 3},
          }),
        ),
        problem(BackupProblem.damaged),
      );
    });

    test('v1 형식 백업도 복원할 수 있다', () {
      final v1 = buildDemoFarm(now).toJson()
        ..remove('animalEvents')
        ..remove('feedingUsage')
        ..remove('careItems')
        ..['schemaVersion'] = 1;
      final contents = FarmStore.parseBackup(jsonEncode({'format': FarmStore.backupFormat, 'state': v1}));
      expect(contents.state.animals, hasLength(48));
      expect(contents.exportedAt, isNull);
    });
  });

  group('백신·진료 일정', () {
    test('예시 일정은 날짜 순이고, 지난 일정과 7일 안 일정을 고를 수 있다', () async {
      final (store, _) = await fresh();
      final due = store.careDueWithin(7);
      expect(due.map((c) => c.title), ['뉴캐슬병 백신', '정기 검진', '구제역 백신']);
      expect(due.first.daysUntil(now), -1);
    });

    test('반복 일정을 완료하면 완료일 기준 다음 일정이 생긴다', () async {
      final (store, _) = await fresh();
      final next = await store.completeCare('c2');
      expect(next, isNotNull);
      expect(next!.dueDate, DateTime(2027, 1, 5));
      expect(store.state.careItems.firstWhere((c) => c.id == 'c2').isDone, isTrue);
      expect(store.pendingCare.where((c) => c.title == '뉴캐슬병 백신'), hasLength(1));
      expect(await store.completeCare('c2'), isNull);
    });

    test('검진을 완료하면 대상 가축의 마지막 검진일이 오늘이 된다', () async {
      final (store, _) = await fresh();
      await store.completeCare('c3');
      expect(store.animalById('cow-0')!.lastCheckup, now);
      expect(store.animalById('cow-1')!.lastCheckup, isNot(now));
    });

    test('개체 일정에는 종 전체 일정도 함께 나온다', () async {
      final (store, _) = await fresh();
      final bella = store.animalById('cow-0')!;
      expect(store.careFor(bella).map((c) => c.id), ['c3', 'c1']);
    });

    test('가축을 출하하면 그 개체만의 남은 일정은 사라진다', () async {
      final (store, _) = await fresh();
      await store.removeAnimal('cow-0', type: AnimalEventType.sold);
      expect(store.state.careItems.any((c) => c.id == 'c3'), isFalse);
      expect(store.state.careItems.any((c) => c.id == 'c1'), isTrue);
    });

    test('일정 추가 시 이름이 비면 거부하고, 날짜는 자정으로 맞춘다', () async {
      final (store, _) = await fresh();
      expect(
        () => store.addCareItem(kind: AnimalKind.goat, type: CareType.deworm, title: ' ', dueDate: now),
        throwsArgumentError,
      );
      final item = await store.addCareItem(kind: AnimalKind.goat, type: CareType.deworm, title: '구충', dueDate: now);
      expect(item.dueDate, DateTime(2026, 10, 5));
      expect(item.daysUntil(now), 0);
    });

    test('addMonths는 말일을 넘지 않는다', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
    });
  });

  group('백업 알림', () {
    test('한 번도 백업하지 않았으면 첫 실행 7일 뒤부터 권하고, 백업하면 14일간 조용하다', () async {
      var clockNow = now;
      final storage = MemoryStorage();
      final store = await FarmStore.load(storage, clock: () => clockNow);
      expect(store.shouldRemindBackup, isFalse);
      clockNow = now.add(const Duration(days: 7));
      expect(store.shouldRemindBackup, isTrue);
      await store.markBackedUp();
      expect(store.shouldRemindBackup, isFalse);
      clockNow = clockNow.add(const Duration(days: 14));
      expect(store.shouldRemindBackup, isTrue);
      await store.snoozeBackupReminder();
      expect(store.shouldRemindBackup, isFalse);

      // 다시 열어도 기기별 기록이 유지된다.
      final reopened = await FarmStore.load(storage, clock: () => clockNow);
      expect(reopened.lastBackupAt, isNotNull);
      expect(reopened.shouldRemindBackup, isFalse);
    });
  });

  test('기기 언어가 영어면 예시 농장도 영어로 만든다', () async {
    final store = await FarmStore.load(MemoryStorage(), clock: clock, english: true);
    expect(store.state.profile.name, 'Green Valley Farm');
    expect(store.animalById('cow-0')!.name, 'Bella');
    expect(store.state.fields.first.cropName, 'Tomato');
    await store.resetToDemo(english: false);
    expect(store.state.profile.name, '초록골 농장');
  });

  test('언어 설정은 기기별 값으로 저장되고 다시 열어도 유지된다', () async {
    final storage = MemoryStorage();
    final store = await FarmStore.load(storage, clock: clock);
    expect(store.localeOverride, isNull);
    await store.setLocaleOverride('en');
    expect((await FarmStore.load(storage, clock: clock)).localeOverride, 'en');
    await store.setLocaleOverride(null);
    expect((await FarmStore.load(storage, clock: clock)).localeOverride, isNull);
  });
}
