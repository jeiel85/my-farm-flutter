import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/game/zone.dart';
import 'package:my_farm/game/defs.dart';
import 'package:my_farm/game/engine.dart';
import 'package:my_farm/game/game_store.dart';
import 'package:my_farm/game/state.dart';

import 'support/memory_storage.dart';

void main() {
  var now = DateTime(2026, 10, 6, 9, 0, 30);
  DateTime clock() => now;
  setUp(() => now = DateTime(2026, 10, 6, 9, 0, 30));

  Future<GameStore> load(MemoryStorage storage) => GameStore.load(storage, clock: clock, defaultFarmName: '새 농장');

  test('저장본이 없으면 새 게임을 만들어 v5로 저장한다', () async {
    final storage = MemoryStorage();
    final store = await load(storage);
    expect(store.state.farmName, '새 농장');
    expect((jsonDecode(storage.value!) as Map)['schemaVersion'], 5);
    expect(store.migratedFromManagement, isFalse);
  });

  test('관리 앱(v4) 저장본은 지우지 않고 보관하고, 농장 이름만 이어받아 새 게임을 시작한다', () async {
    // 관리 앱(1.7.x) 저장본의 앞부분. 새 게임은 농장 이름만 읽는다.
    final legacy = jsonEncode({
      'schemaVersion': 4,
      'profile': {'name': '초록골 농장', 'currency': 'KRW'},
      'ledger': [],
    });
    final storage = MemoryStorage(legacy);
    final store = await load(storage);
    expect(store.migratedFromManagement, isTrue);
    expect(store.state.farmName, '초록골 농장');
    expect(storage.meta[GameStore.managementArchiveKey], legacy);
    expect(await store.managementArchive(), legacy);
    expect((jsonDecode(storage.value!) as Map)['schemaVersion'], 5);
    // 다음 실행에서는 그냥 게임을 읽는다.
    final again = await load(storage);
    expect(again.migratedFromManagement, isFalse);
    expect(storage.meta[GameStore.managementArchiveKey], legacy);
  });

  test('읽을 수 없거나 더 새로운 저장본은 보관본으로 남기고 새 게임으로 시작한다', () async {
    final broken = MemoryStorage('{oops');
    final s1 = await load(broken);
    expect(s1.recoveredFromCorruptData, isTrue);
    expect(broken.copiesLabeled('corrupt'), ['{oops']);

    final newer = jsonEncode({'schemaVersion': 9});
    final future = MemoryStorage(newer);
    await load(future);
    expect(future.copiesLabeled('newer_v9'), [newer]);
  });

  test('다시 열면 비운 시간만큼 진행하고, 일이 있었으면 요약을 남긴다', () async {
    final storage = MemoryStorage();
    final store = await load(storage);
    now = now.add(const Duration(hours: 3));
    await store.resume();
    expect(store.awayReport, isNotNull);
    expect(store.awayReport!.cropsReady, {ZoneId.vegetable});
    expect(store.state.fields[ZoneId.vegetable]!.ready, isTrue);
    store.dismissReport();
    now = now.add(const Duration(minutes: 2));
    await store.resume();
    expect(store.awayReport, isNull);
  });

  test('행동은 지금까지 진행한 뒤 적용·저장하고, 할 수 없으면 상태를 바꾸지 않는다', () async {
    final storage = MemoryStorage();
    final store = await load(storage);
    now = now.add(const Duration(minutes: 1));
    await store.act((s) => GameEngine.harvest(s, ZoneId.vegetable));
    expect(store.state.countOf(ItemId.lettuce), 5);
    expect(GameState.fromJson((jsonDecode(storage.value!) as Map).cast()).countOf(ItemId.lettuce), 5);

    final before = storage.value;
    await expectLater(store.act((s) => GameEngine.harvest(s, ZoneId.vegetable)), throwsA(isA<GameException>()));
    expect(store.state.countOf(ItemId.lettuce), 5);
    expect(storage.value, before);

    final took = await store.actWith((s) => GameEngine.collect(s, Species.chicken));
    expect(took, greaterThan(0));
  });

  test('tick은 분이 바뀌었을 때만 진행·저장한다', () async {
    final storage = MemoryStorage();
    final store = await load(storage);
    final saved = storage.value;
    now = now.add(const Duration(seconds: 20));
    await store.tick();
    expect(storage.value, saved);
    now = now.add(const Duration(seconds: 20));
    await store.tick();
    expect(storage.value, isNot(saved));
  });

  test('새로 시작하면 지금 게임을 보관본으로 남긴다', () async {
    final storage = MemoryStorage();
    final store = await load(storage);
    await store.act((s) => GameEngine.buyAnimal(s, Species.chicken));
    await store.restart(farmName: '두 번째 농장');
    expect(store.state.farmName, '두 번째 농장');
    expect(store.state.animals, hasLength(2));
    expect(storage.copiesLabeled('before_restart'), hasLength(1));
  });
}
