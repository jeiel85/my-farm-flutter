import 'defs.dart';
import 'lots.dart';
import 'sky.dart';
import 'state.dart';

/// 행동을 할 수 없는 이유. 문구는 화면에서 만든다.
enum GameError {
  levelTooLow,
  notEnoughCoins,
  notEnoughWater,
  fieldNotEmpty,
  wrongPlot,
  notReady,
  barnFull,
  penFull,
  notAdult,
  nothingToCollect,
  notEnoughItems,
  siloFull,
  unknownAnimal,

  /// 가진 땅이 아니다.
  notOwned,

  /// 이미 지은 칸이다.
  lotOccupied,

  /// 가진 땅에 붙어 있지 않거나 이미 가진 땅이다.
  cannotExpand,

  /// 지금 레벨에서는 더 넓힐 수 없다.
  expansionLimit,

  /// 그 칸에 맞는 건물이 아니다(예: 우리가 아닌 곳에 동물 들이기).
  wrongBuilding,

  /// 핵심 건물(농가·창고)이거나 비어 있지 않아 철거할 수 없다.
  cannotDemolish,
}

class GameException implements Exception {
  const GameException(this.error);
  final GameError error;
  @override
  String toString() => 'GameException($error)';
}

/// [GameEngine.advance] 동안 일어난 일(자리 비운 동안 요약·알림용).
class AdvanceReport {
  AdvanceReport();

  /// 실제로 계산한 분.
  int minutes = 0;

  /// 오프라인 상한을 넘어 계산하지 않고 버린 분.
  int skippedMinutes = 0;
  final cropsReady = <LotId>{};
  final produced = <Species, int>{};
  final born = <Species, int>{};

  /// 사료가 모자라 성장·생산이 멈춘 적이 있다.
  bool feedRanOut = false;

  bool get eventful => cropsReady.isNotEmpty || produced.isNotEmpty || born.isNotEmpty || feedRanOut;
}

DateTime minuteFloor(DateTime t) => DateTime(t.year, t.month, t.day, t.hour, t.minute);

/// 게임 규칙. 모든 함수는 순수 함수다(상태를 받아 새 상태를 돌려준다).
abstract final class GameEngine {
  /// 새 게임. docs/farm-lots-design.md §3 처음 땅: 농가·창고, 상추가 1분 남은 밭, 성체 닭 2마리가 있는 닭장, 빈 땅 2칸.
  static GameState newGame(DateTime now, {required String farmName}) {
    final lettuce = GameDefs.crops[CropId.lettuce]!;
    final hen = GameDefs.animals[Species.chicken]!;
    return GameState(
      farmName: farmName,
      simTime: minuteFloor(now),
      coins: GameDefs.startCoins,
      xp: 0,
      barn: const {},
      feedUnits: GameDefs.startFeed * GameDefs.feedUnit,
      water: GameDefs.startWater,
      owned: {...GameDefs.startLots},
      lots: {
        GameDefs.farmhouseLot: const Lot(BuildingId.farmhouse),
        GameDefs.storehouseLot: const Lot(BuildingId.storehouse),
        GameDefs.startFieldLot: Lot(
          BuildingId.field,
          field: FieldState(
            crop: CropId.lettuce,
            minutesLeft: lettuce.growMinutes - 1,
            totalMinutes: lettuce.growMinutes,
          ),
        ),
        GameDefs.startCoopLot: const Lot(BuildingId.coop),
      },
      expansions: 0,
      animals: [
        for (var i = 0; i < 2; i++)
          GameAnimal(
            id: 'a$i',
            species: Species.chicken,
            home: GameDefs.startCoopLot,
            ageMinutes: hen.growMinutes,
            stored: i == 0 ? 1 : 0,
          ),
      ],
      breedProgress: const {},
      nextAnimalId: 2,
      log: const [],
    );
  }

  /// [to]까지 시간을 진행한다. 온전한 분만 계산하고, [capMinutes]를 넘는 시간은 버린다.
  static (GameState, AdvanceReport) advance(GameState s, DateTime to, {int capMinutes = GameDefs.offlineCapMinutes}) {
    final report = AdvanceReport();
    final target = minuteFloor(to);
    final total = target.difference(s.simTime).inMinutes;
    if (total <= 0) return (s, report);
    final run = total > capMinutes ? capMinutes : total;
    report.skippedMinutes = total - run;

    var water = s.water;
    var feed = s.feedUnits;
    final lots = Map.of(s.lots);
    final plots = [
      for (final id in s.builtLots)
        if (s.lots[id]!.field != null) id,
    ];
    final pens = [
      for (final id in s.builtLots)
        if (s.lots[id]!.def.species != null) id,
    ];
    final animals = [...s.animals];
    final breed = Map.of(s.breedProgress);
    var nextId = s.nextAnimalId;

    for (var m = 0; m < run; m++) {
      final minute = s.simTime.add(Duration(minutes: m));
      water = (water + GameSky.waterRefillAt(minute)).clamp(0, GameDefs.waterCapacity);

      for (final id in plots) {
        final lot = lots[id]!;
        final f = lot.field!;
        if (f.crop == null || f.ready) continue;
        final def = GameDefs.crops[f.crop]!;
        if (f.waitingWater) {
          if (water >= def.waterL) {
            water -= def.waterL;
            lots[id] = lot.copyWith(
              field: f.copyWith(waitingWater: false, minutesLeft: def.regrowMinutes, totalMinutes: def.regrowMinutes),
            );
          }
          continue;
        }
        final left = f.minutesLeft - 1;
        if (left <= 0) {
          lots[id] = lot.copyWith(field: f.copyWith(minutesLeft: 0, ready: true));
          report.cropsReady.add(id);
        } else {
          lots[id] = lot.copyWith(field: f.copyWith(minutesLeft: left));
        }
      }

      for (var i = 0; i < animals.length; i++) {
        final a = animals[i];
        final def = a.def;
        if (!a.adult) {
          final need = def.feedPerHour ~/ 2; // 자라는 동안은 절반(1/60 단위로 분당 정수)
          if (feed >= need) {
            feed -= need;
            animals[i] = a.copyWith(ageMinutes: a.ageMinutes + 1);
          } else {
            report.feedRanOut = true;
          }
        } else if (a.stored < def.storeCap) {
          final need = def.feedPerHour;
          if (feed >= need) {
            feed -= need;
            final progress = a.produceProgress + 1;
            if (progress >= def.produceEveryMinutes) {
              animals[i] = a.copyWith(stored: a.stored + 1, produceProgress: 0);
              report.produced[a.species] = (report.produced[a.species] ?? 0) + 1;
            } else {
              animals[i] = a.copyWith(produceProgress: progress);
            }
          } else {
            report.feedRanOut = true;
          }
        }
      }

      // 번식: 같은 우리에 성체가 2마리 이상이고 자리가 있으면 진행한다.
      for (final pen in pens) {
        final species = lots[pen]!.def.species!;
        final here = animals.where((a) => a.home == pen);
        if (here.where((a) => a.adult).length < 2) {
          breed.remove(pen);
          continue;
        }
        if (here.length >= _capacity(lots[pen]!)) continue; // 자리가 날 때까지 진행을 멈춘다
        final progress = (breed[pen] ?? 0) + 1;
        if (progress >= GameDefs.animals[species]!.breedEveryMinutes) {
          animals.add(GameAnimal(id: 'a$nextId', species: species, home: pen));
          nextId++;
          breed[pen] = 0;
          report.born[species] = (report.born[species] ?? 0) + 1;
        } else {
          breed[pen] = progress;
        }
      }
    }

    report.minutes = run;
    return (
      s.copyWith(
        simTime: target,
        water: water,
        feedUnits: feed,
        lots: lots,
        animals: animals,
        breedProgress: breed,
        nextAnimalId: nextId,
      ),
      report,
    );
  }

  static int _capacity(Lot lot) {
    final caps = lot.def.capacity;
    return caps.isEmpty ? 0 : caps[(lot.level - 1).clamp(0, caps.length - 1)];
  }

  // ---------------------------------------------------------------- 땅·건물

  /// 가진 땅에 붙은 장애물 칸을 치워 빈 땅으로 만든다.
  static GameState clearLand(GameState s, LotId lot) {
    if (!s.touchesOwned(lot)) throw const GameException(GameError.cannotExpand);
    if (s.expansionsLeft <= 0) throw const GameException(GameError.expansionLimit);
    final cost = s.nextExpansionCost!;
    if (s.coins < cost) throw const GameException(GameError.notEnoughCoins);
    return _log(
      s.copyWith(coins: s.coins - cost, owned: {...s.owned, lot}, expansions: s.expansions + 1),
      LogKind.expand,
      -cost,
      lot.key,
    );
  }

  /// 빈 땅에 [building]을 짓는다. 작물 건물은 빈 밭으로 시작한다.
  static GameState build(GameState s, LotId lot, BuildingId building) {
    final def = GameDefs.buildings[building]!;
    if (def.core) throw const GameException(GameError.wrongBuilding);
    if (!s.owned.contains(lot)) throw const GameException(GameError.notOwned);
    if (s.lots.containsKey(lot)) throw const GameException(GameError.lotOccupied);
    if (s.level < def.unlockLevel) throw const GameException(GameError.levelTooLow);
    if (s.coins < def.cost) throw const GameException(GameError.notEnoughCoins);
    return _log(
      s.copyWith(
        coins: s.coins - def.cost,
        lots: {
          ...s.lots,
          lot: Lot(building, field: def.plot != null ? FieldState.emptyField : null),
        },
      ),
      LogKind.build,
      -def.cost,
      building.name,
    );
  }

  /// 비어 있는 건물(작물이 없는 밭, 동물이 없는 우리)을 헐고 짓기 비용의 절반을 돌려받는다.
  static GameState demolish(GameState s, LotId lot) {
    final l = s.lots[lot];
    if (l == null || l.def.core) throw const GameException(GameError.cannotDemolish);
    if (l.field != null && !l.field!.empty) throw const GameException(GameError.cannotDemolish);
    if (s.animals.any((a) => a.home == lot)) throw const GameException(GameError.cannotDemolish);
    final refund = GameDefs.demolishRefund(l.building);
    return _log(
      s.copyWith(
        coins: s.coins + refund,
        lots: {...s.lots}..remove(lot),
        breedProgress: {...s.breedProgress}..remove(lot),
      ),
      LogKind.demolish,
      refund,
      l.building.name,
    );
  }

  // ---------------------------------------------------------------- 작물

  /// 작물 건물 [lot]에 심을 수 있는 작물(레벨과 무관하게 건물 종류만 맞는 것).
  static List<CropDef> cropsFor(GameState s, LotId lot) {
    final plot = s.lots[lot]?.def.plot;
    return [
      for (final c in GameDefs.crops.values)
        if (plot != null && c.plot == plot) c,
    ];
  }

  static GameState plant(GameState s, LotId lot, CropId crop) {
    final l = s.lots[lot];
    final def = GameDefs.crops[crop]!;
    if (l == null || l.field == null || l.def.plot != def.plot) throw const GameException(GameError.wrongPlot);
    if (!l.field!.empty) throw const GameException(GameError.fieldNotEmpty);
    if (s.level < def.unlockLevel) throw const GameException(GameError.levelTooLow);
    if (s.coins < def.seedCost) throw const GameException(GameError.notEnoughCoins);
    if (s.water < def.waterL) throw const GameException(GameError.notEnoughWater);
    return _log(
      s.copyWith(
        coins: s.coins - def.seedCost,
        water: s.water - def.waterL,
        lots: {
          ...s.lots,
          lot: l.copyWith(
            field: FieldState(crop: crop, minutesLeft: def.growMinutes, totalMinutes: def.growMinutes),
          ),
        },
      ),
      LogKind.seed,
      -def.seedCost,
      crop.name,
    );
  }

  static GameState harvest(GameState s, LotId lot) {
    final l = s.lots[lot];
    final f = l?.field ?? FieldState.emptyField;
    if (l == null || f.crop == null || !f.ready) throw const GameException(GameError.notReady);
    final def = GameDefs.crops[f.crop]!;
    final count = GameSky.yieldAt(def, s.simTime);
    if (s.barnFree < count) throw const GameException(GameError.barnFull);
    final FieldState next;
    var water = s.water;
    if (def.perennial) {
      if (water >= def.waterL) {
        water -= def.waterL;
        next = FieldState(crop: f.crop, minutesLeft: def.regrowMinutes!, totalMinutes: def.regrowMinutes!);
      } else {
        next = FieldState(crop: f.crop, waitingWater: true, totalMinutes: def.regrowMinutes!);
      }
    } else {
      next = FieldState.emptyField;
    }
    return s.copyWith(
      barn: _add(s.barn, def.item, count),
      xp: s.xp + def.xp,
      water: water,
      lots: {
        ...s.lots,
        lot: l.copyWith(field: next),
      },
    );
  }

  // ---------------------------------------------------------------- 가축

  /// 우리 [pen]의 쌓인 생산물을 창고로 옮긴다(창고에 들어가는 만큼). 옮긴 개수를 함께 돌려준다.
  static (GameState, int) collect(GameState s, LotId pen) {
    final species = s.lots[pen]?.def.species;
    if (species == null) throw const GameException(GameError.wrongBuilding);
    final total = s.animals.where((a) => a.home == pen).fold(0, (n, a) => n + a.stored);
    if (total == 0) throw const GameException(GameError.nothingToCollect);
    final take = total < s.barnFree ? total : s.barnFree;
    if (take <= 0) throw const GameException(GameError.barnFull);
    final def = GameDefs.animals[species]!;
    var remaining = take;
    final animals = [
      for (final a in s.animals)
        if (a.home != pen || remaining == 0 || a.stored == 0)
          a
        else
          () {
            final t = a.stored < remaining ? a.stored : remaining;
            remaining -= t;
            return a.copyWith(stored: a.stored - t);
          }(),
    ];
    return (s.copyWith(animals: animals, barn: _add(s.barn, def.product, take), xp: s.xp + def.collectXp * take), take);
  }

  /// 우리 [pen]에 새끼를 들인다(종은 우리가 정한다).
  static GameState buyAnimal(GameState s, LotId pen) {
    final species = s.lots[pen]?.def.species;
    if (species == null) throw const GameException(GameError.wrongBuilding);
    final def = GameDefs.animals[species]!;
    if (s.level < def.unlockLevel) throw const GameException(GameError.levelTooLow);
    if (s.animalsIn(pen).length >= s.penCapacity(pen)) throw const GameException(GameError.penFull);
    if (s.coins < def.buyCost) throw const GameException(GameError.notEnoughCoins);
    return _log(
      s.copyWith(
        coins: s.coins - def.buyCost,
        animals: [
          ...s.animals,
          GameAnimal(id: 'a${s.nextAnimalId}', species: species, home: pen),
        ],
        nextAnimalId: s.nextAnimalId + 1,
      ),
      LogKind.animal,
      -def.buyCost,
      species.name,
    );
  }

  /// 성체를 출하(정육)한다. 쌓여 있던 생산물은 창고로 옮긴다(자리가 없으면 출하하지 않는다).
  static GameState slaughter(GameState s, String animalId) {
    final a = s.animals.where((a) => a.id == animalId).firstOrNull;
    if (a == null) throw const GameException(GameError.unknownAnimal);
    if (!a.adult) throw const GameException(GameError.notAdult);
    if (a.stored > s.barnFree) throw const GameException(GameError.barnFull);
    final def = a.def;
    return _log(
      s.copyWith(
        coins: s.coins + def.sellPrice,
        xp: s.xp + def.sellXp,
        barn: a.stored > 0 ? _add(s.barn, def.product, a.stored) : null,
        animals: [
          for (final x in s.animals)
            if (x.id != animalId) x,
        ],
      ),
      LogKind.slaughter,
      def.sellPrice,
      a.species.name,
    );
  }

  // ---------------------------------------------------------------- 창고

  static GameState sell(GameState s, ItemId item, int count) {
    if (count <= 0 || s.countOf(item) < count) throw const GameException(GameError.notEnoughItems);
    final amount = GameDefs.itemPrice[item]! * count;
    return _log(s.copyWith(coins: s.coins + amount, barn: _add(s.barn, item, -count)), LogKind.sale, amount, item.name);
  }

  static GameState buyFeed(GameState s) {
    if (s.coins < GameDefs.feedPackCost) throw const GameException(GameError.notEnoughCoins);
    final add = GameDefs.feedPackAmount * GameDefs.feedUnit;
    if (s.feedUnits + add > GameDefs.feedCapacity * GameDefs.feedUnit) throw const GameException(GameError.siloFull);
    return _log(
      s.copyWith(coins: s.coins - GameDefs.feedPackCost, feedUnits: s.feedUnits + add),
      LogKind.feed,
      -GameDefs.feedPackCost,
      'feed',
    );
  }

  static GameState cornToFeed(GameState s, int count) {
    if (count <= 0 || s.countOf(ItemId.corn) < count) throw const GameException(GameError.notEnoughItems);
    final add = count * GameDefs.feedPerCorn * GameDefs.feedUnit;
    if (s.feedUnits + add > GameDefs.feedCapacity * GameDefs.feedUnit) throw const GameException(GameError.siloFull);
    return s.copyWith(feedUnits: s.feedUnits + add, barn: _add(s.barn, ItemId.corn, -count));
  }

  static Map<ItemId, int> _add(Map<ItemId, int> barn, ItemId item, int delta) {
    final next = Map.of(barn);
    final n = (next[item] ?? 0) + delta;
    if (n == 0) {
      next.remove(item);
    } else {
      next[item] = n;
    }
    return next;
  }

  static GameState _log(GameState s, LogKind kind, int amount, String subject) {
    final entry = GameLogEntry(at: s.simTime, kind: kind, amount: amount, subject: subject);
    final log = [...s.log, entry];
    return s.copyWith(log: log.length > GameState.maxLog ? log.sublist(log.length - GameState.maxLog) : log);
  }
}
