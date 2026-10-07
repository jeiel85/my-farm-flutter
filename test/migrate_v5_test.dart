import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/game/defs.dart';
import 'package:my_farm/game/game_store.dart';
import 'package:my_farm/game/lots.dart';
import 'package:my_farm/game/state.dart';

import 'support/memory_storage.dart';

/// v5(정해진 9구역 시절 개발판) 저장본. docs/farm-lots-design.md §9.
Map<String, Object?> v5({
  List<String> unlocked = const ['house', 'vegetable', 'animals', 'water', 'storage'],
  Map<String, Object?> fields = const {},
  List<(String, String)> animals = const [('a0', 'chicken'), ('a1', 'chicken')],
  Map<String, int> breed = const {},
  int water = 300,
}) => {
  'schemaVersion': 5,
  'farmName': '초록골 농장',
  'simTime': DateTime(2026, 10, 6, 9).toUtc().toIso8601String(),
  'coins': 321,
  'xp': 40,
  'barn': {'egg': 3, 'lettuce': 5},
  'feedUnits': 3600,
  'water': water,
  'unlocked': unlocked,
  'fields': {
    'vegetable': {'crop': 'lettuce', 'minutesLeft': 1, 'totalMinutes': 2, 'ready': false, 'waitingWater': false},
    'tomato': {'crop': null, 'minutesLeft': 0, 'totalMinutes': 0, 'ready': false, 'waitingWater': false},
    'corn': {'crop': null, 'minutesLeft': 0, 'totalMinutes': 0, 'ready': false, 'waitingWater': false},
    'greenhouse': {'crop': null, 'minutesLeft': 0, 'totalMinutes': 0, 'ready': false, 'waitingWater': false},
    'orchard': {'crop': null, 'minutesLeft': 0, 'totalMinutes': 0, 'ready': false, 'waitingWater': false},
    ...fields,
  },
  'animals': [
    for (final (id, species) in animals)
      {'id': id, 'species': species, 'ageMinutes': 999, 'stored': 1, 'produceProgress': 2},
  ],
  'breedProgress': breed,
  'nextAnimalId': 50,
  'log': [
    {'at': DateTime(2026, 10, 6, 8).toUtc().toIso8601String(), 'kind': 'unlock', 'amount': -30, 'subject': 'tomato'},
  ],
};

void main() {
  test('처음 땅에 농가·창고·밭·닭장을 두고 진행 상황(작물·동물·코인·창고·기록)을 그대로 옮긴다', () {
    final s = GameState.fromJson(v5(breed: {'chicken': 12}));
    expect(s.owned, {...GameDefs.startLots});
    expect(s.expansions, 0);
    expect(s.lots[GameDefs.farmhouseLot]!.building, BuildingId.farmhouse);
    expect(s.lots[GameDefs.storehouseLot]!.building, BuildingId.storehouse);
    expect(s.lots[GameDefs.startFieldLot]!.field!.crop, CropId.lettuce);
    expect(s.lots[GameDefs.startFieldLot]!.field!.minutesLeft, 1);
    expect(s.lots[GameDefs.startCoopLot]!.building, BuildingId.coop);
    expect(s.emptyLots, [const LotId(1, 2), const LotId(2, 2)]);
    expect(
      [for (final a in s.animals) (a.id, a.home, a.stored, a.produceProgress)],
      [('a0', GameDefs.startCoopLot, 1, 2), ('a1', GameDefs.startCoopLot, 1, 2)],
    );
    expect(s.breedProgress, {GameDefs.startCoopLot: 12});
    expect((s.coins, s.xp, s.feedUnits, s.water, s.nextAnimalId), (321, 40, 3600, 300, 50));
    expect(s.barn, {ItemId.egg: 3, ItemId.lettuce: 5});
    expect(s.log.single.kind, LogKind.unlock);
    // 옮긴 결과는 v6으로 저장·왕복된다.
    final back = GameState.fromJson((jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, Object?>());
    expect(jsonEncode(back.toJson()), jsonEncode(s.toJson()));
  });

  test('열린 밭·온실은 빈 땅부터 짓고, 넘치면 붙은 칸을 넓혀 쓴다. 동물은 종마다 우리를 짓고 넘치면 하나 더', () {
    final s = GameState.fromJson(
      v5(
        unlocked: const ['house', 'vegetable', 'animals', 'water', 'storage', 'tomato', 'corn', 'greenhouse'],
        fields: const {
          'tomato': {'crop': 'tomato', 'minutesLeft': 5, 'totalMinutes': 12, 'ready': false, 'waitingWater': false},
        },
        animals: const [
          ('c1', 'chicken'),
          ('c2', 'chicken'),
          ('c3', 'chicken'),
          ('c4', 'chicken'),
          ('c5', 'chicken'),
          ('g1', 'goat'),
          ('w1', 'cow'),
          ('w2', 'cow'),
          ('w3', 'cow'),
          ('w4', 'cow'),
        ],
        breed: const {'cow': 7},
      ),
    );
    Lot at(int c, int r) => s.lots[LotId(c, r)]!;
    expect(at(1, 2).building, BuildingId.field);
    expect(at(1, 2).field!.crop, CropId.tomato);
    expect(at(1, 2).field!.minutesLeft, 5);
    expect(at(2, 2).building, BuildingId.field); // 옥수수 밭 자리
    expect(at(1, 3).building, BuildingId.greenhouse); // 넘쳐서 넓힌 첫 칸
    expect(at(2, 3).building, BuildingId.coop); // 닭 다섯째 → 닭장 하나 더
    expect(at(0, 1).building, BuildingId.goatPen);
    expect(at(3, 1).building, BuildingId.cowBarn);
    expect(at(0, 2).building, BuildingId.cowBarn); // 소 넷째
    expect(s.expansions, 5);
    expect(s.owned, containsAll(const [LotId(1, 3), LotId(2, 3), LotId(0, 1), LotId(3, 1), LotId(0, 2)]));
    for (final pen in s.lots.keys.where((l) => s.lots[l]!.def.species != null)) {
      expect(s.animalsIn(pen).length, lessThanOrEqualTo(s.penCapacity(pen)), reason: '$pen');
    }
    expect(s.breedProgress, {const LotId(3, 1): 7});
    // 넓힌 땅은 모두 가진 땅에 붙어 이어진다.
    for (final l in s.owned) {
      expect(l.neighbors.any(s.owned.contains), isTrue, reason: '$l');
    }
  });

  test('불러올 때 v5 원문을 before_v6 보관본으로 남긴다', () async {
    final raw = jsonEncode(v5());
    final storage = MemoryStorage(raw);
    final store = await GameStore.load(storage, clock: () => DateTime(2026, 10, 6, 9), defaultFarmName: 'x');
    expect(storage.copiesLabeled('before_v6').single, raw);
    expect(store.state.farmName, '초록골 농장');
    expect(store.recoveredFromCorruptData, isFalse);
  });
}
