/// 저장 형식 v5(정해진 9구역 시절 개발판) → v6(부지) 옮기기. docs/farm-lots-design.md §9.
///
/// 옮기기 전 원문은 [GameStore]가 'before_v6' 보관본으로 남긴다. 여기서는 진행 상황(밭 작물·동물·번식·물·창고·코인·
/// 기록)을 잃지 않게 부지에 다시 놓기만 한다.
library;

import 'defs.dart';
import 'lots.dart';
import 'state.dart';

/// 처음 땅 밖으로 넘칠 때 넓혀 쓸 칸 순서(앞 칸이 늘 가진 땅에 붙어 있다).
const migrationExpandOrder = [
  LotId(1, 3),
  LotId(2, 3),
  LotId(0, 1),
  LotId(3, 1),
  LotId(0, 2),
  LotId(3, 2),
  LotId(0, 0),
  LotId(3, 0),
  LotId(0, 3),
  LotId(3, 3),
  LotId(1, 4),
  LotId(2, 4),
  LotId(0, 4),
  LotId(3, 4),
];

GameState migrateV5(Map<String, Object?> j) {
  Map<String, Object?> map(String key) => (j[key] as Map).cast<String, Object?>();
  T byName<T extends Enum>(List<T> values, Object? name) =>
      values.asNameMap()[name] ?? (throw FormatException('Unknown ${T.toString()}', name));

  final unlocked = {for (final z in j['unlocked'] as List) z as String};
  final fields = {
    for (final e in map('fields').entries) e.key: FieldState.fromJson((e.value as Map).cast<String, Object?>()),
  };

  final owned = {...GameDefs.startLots};
  final lots = <LotId, Lot>{
    GameDefs.farmhouseLot: const Lot(BuildingId.farmhouse),
    GameDefs.storehouseLot: const Lot(BuildingId.storehouse),
    GameDefs.startFieldLot: Lot(BuildingId.field, field: fields['vegetable'] ?? FieldState.emptyField),
    GameDefs.startCoopLot: const Lot(BuildingId.coop),
  };
  final free = [const LotId(1, 2), const LotId(2, 2)];
  var expansions = 0;
  LotId take() {
    if (free.isNotEmpty) return free.removeAt(0);
    final lot = migrationExpandOrder[expansions++];
    owned.add(lot);
    return lot;
  }

  // 열려 있던 작물 구역을 같은 건물로 짓는다.
  for (final (zone, building) in const [
    ('tomato', BuildingId.field),
    ('corn', BuildingId.field),
    ('greenhouse', BuildingId.greenhouse),
    ('orchard', BuildingId.orchard),
  ]) {
    if (!unlocked.contains(zone)) continue;
    lots[take()] = Lot(building, field: fields[zone] ?? FieldState.emptyField);
  }

  // 동물은 종마다 우리를 지어 옮긴다(Lv1 수용량을 넘으면 같은 우리를 하나 더 짓는다).
  final rawAnimals = [for (final a in j['animals'] as List) (a as Map).cast<String, Object?>()];
  final animals = <GameAnimal>[];
  final firstPen = <Species, LotId>{Species.chicken: GameDefs.startCoopLot};
  for (final species in Species.values) {
    final mine = rawAnimals.where((a) => a['species'] == species.name).toList();
    if (mine.isEmpty) continue;
    final building = GameDefs.penFor(species);
    final cap = GameDefs.buildings[building]!.capacity.first;
    LotId? pen = firstPen[species];
    var inPen = 0;
    for (final a in mine) {
      if (pen == null || inPen >= cap) {
        pen = take();
        lots[pen] = Lot(building);
        firstPen.putIfAbsent(species, () => pen!);
        inPen = 0;
      }
      animals.add(
        GameAnimal(
          id: a['id'] as String,
          species: species,
          home: pen,
          ageMinutes: a['ageMinutes'] as int,
          stored: a['stored'] as int,
          produceProgress: a['produceProgress'] as int,
        ),
      );
      inPen++;
    }
  }

  final breed = <LotId, int>{
    for (final e in map('breedProgress').entries)
      // 우리가 없는(동물이 없는) 종의 번식 진행은 버린다.
      ?firstPen[byName(Species.values, e.key)]: e.value as int,
  };

  return GameState(
    farmName: j['farmName'] as String,
    simTime: DateTime.parse(j['simTime'] as String).toLocal(),
    coins: j['coins'] as int,
    xp: j['xp'] as int,
    barn: {for (final e in map('barn').entries) byName(ItemId.values, e.key): e.value as int},
    feedUnits: j['feedUnits'] as int,
    water: (j['water'] as int).clamp(0, GameDefs.waterCapacity),
    owned: owned,
    lots: lots,
    expansions: expansions,
    animals: animals,
    breedProgress: breed,
    nextAnimalId: j['nextAnimalId'] as int,
    log: [for (final l in j['log'] as List) GameLogEntry.fromJson((l as Map).cast<String, Object?>())],
  );
}
