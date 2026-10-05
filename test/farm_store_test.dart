import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/data/farm_state.dart';
import 'package:my_farm/data/farm_store.dart';
import 'package:my_farm/data/models.dart';
import 'package:my_farm/data/seed.dart';

class MemoryStorage implements FarmStorage {
  MemoryStorage([this.value]);

  String? value;
  final corrupt = <String>[];
  bool failWrites = false;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async {
    if (failWrites) throw StateError('disk full');
    value = json;
  }

  @override
  Future<void> keepCorrupt(String raw) async => corrupt.add(raw);
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
    expect(storage.corrupt, ['{not json']);
    expect(store.loadNotice, isNotNull);
    expect(store.totalAnimals, 48);
  });

  test('지원하지 않는 버전도 손상본으로 취급한다', () async {
    final storage = MemoryStorage(jsonEncode({'schemaVersion': 99}));
    final store = await FarmStore.load(storage, clock: clock);
    expect(storage.corrupt, hasLength(1));
    expect(store.loadNotice, isNotNull);
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
    expect(() => store.waterField('orchard'), throwsStateError);
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

  test('가축을 들이면 개체와 입식 기록이 함께 늘고, 저장 후 다시 읽어도 남는다', () async {
    final (store, storage) = await fresh();
    final tag = store.suggestTag(AnimalKind.goat);
    final goat = await store.addAnimal(
      kind: AnimalKind.goat,
      tag: tag,
      name: '  새봄 ',
      breed: '보어',
      birthDate: DateTime(2026, 4, 5),
      weightKg: 32,
    );
    expect(goat.name, '새봄');
    expect(store.countOf(AnimalKind.goat), 5);
    expect(store.totalAnimals, 49);
    expect(store.recentAnimalEvents().first.type, AnimalEventType.added);
    expect(store.recentAnimalEvents().first.animalId, goat.id);

    final reloaded = await FarmStore.load(MemoryStorage(storage.value), clock: clock);
    expect(reloaded.animalById(goat.id)?.tag, tag);
    expect(reloaded.state.animalEvents, hasLength(1));
  });

  test('이미 쓰는 태그로는 들일 수 없고, 제안 태그는 내보낸 개체 번호도 피한다', () async {
    final (store, _) = await fresh();
    final existing = store.animalsOf(AnimalKind.cow).first;
    await expectLater(
      store.addAnimal(kind: AnimalKind.cow, tag: existing.tag, name: '중복', breed: '', birthDate: now, weightKg: 40),
      throwsStateError,
    );
    // 번호가 가장 큰 소를 출하해도 다음 제안 태그·id는 그 번호를 다시 쓰지 않는다.
    final suggested = store.suggestTag(AnimalKind.cow);
    final last = store.animalsOf(AnimalKind.cow).firstWhere((a) => a.id == 'cow-17');
    await store.removeAnimal(last.id, AnimalEventType.sold);
    expect(store.suggestTag(AnimalKind.cow), suggested);
    final calf = await store.addAnimal(
      kind: AnimalKind.cow,
      tag: store.suggestTag(AnimalKind.cow),
      name: '송아지',
      breed: '한우',
      birthDate: now,
      weightKg: 40,
    );
    expect(calf.id, 'cow-18');
  });

  test('출하·폐사하면 목록에서 빠지고 이름·태그가 기록에 남는다', () async {
    final (store, _) = await fresh();
    final hen = store.animalsOf(AnimalKind.chicken).first;
    final cow = store.animalsOf(AnimalKind.cow).first;
    await store.removeAnimal(hen.id, AnimalEventType.died, note: ' 고열 ');
    await store.removeAnimal(cow.id, AnimalEventType.sold);
    expect(store.animalById(hen.id), isNull);
    expect(store.totalAnimals, 46);
    final events = store.recentAnimalEvents();
    expect(events.map((e) => e.type), [AnimalEventType.sold, AnimalEventType.died]);
    expect(events.last.name, hen.name);
    expect(events.last.tag, hen.tag);
    expect(events.last.note, '고열');
    expect(events.map((e) => e.id).toSet(), hasLength(2));
    expect(store.animalEventCountSince(AnimalEventType.sold, DateTime(now.year, now.month)), 1);
    expect(() => store.removeAnimal(hen.id, AnimalEventType.sold), throwsStateError);
    expect(() => store.removeAnimal(cow.id, AnimalEventType.added), throwsArgumentError);
  });

  test('입식·출하 기록이 없던 이전 저장본도 그대로 읽는다', () async {
    final json = buildDemoFarm(now).toJson()..remove('animalEvents');
    final storage = MemoryStorage(jsonEncode(json));
    final store = await FarmStore.load(storage, clock: clock);
    expect(storage.corrupt, isEmpty);
    expect(store.loadNotice, isNull);
    expect(store.state.animalEvents, isEmpty);
    expect(store.totalAnimals, 48);
  });

  test('개월 수로 생년월일을 거슬러 갈 때 그 달에 없는 날은 마지막 날로 맞춘다', () {
    expect(monthsBefore(DateTime(2026, 3, 31, 9), 1), DateTime(2026, 2, 28));
    expect(monthsBefore(DateTime(2028, 3, 31), 1), DateTime(2028, 2, 29));
    expect(monthsBefore(DateTime(2026, 1, 15), 3), DateTime(2025, 10, 15));
    expect(monthsBefore(DateTime(2026, 10, 5), 0), DateTime(2026, 10, 5));
    final calf = Animal.fromJson({
      'id': 'cow-99',
      'kind': 'cow',
      'tag': 'COW-999',
      'name': '송아지',
      'breed': '',
      'birthDate': monthsBefore(DateTime(2026, 3, 31), 1).toIso8601String(),
      'health': 100,
      'weightKg': 40,
    });
    expect(calf.ageLabel(DateTime(2026, 3, 31)), '1개월');
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
}
