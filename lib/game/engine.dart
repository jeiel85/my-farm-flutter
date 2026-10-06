import '../data/models.dart' show ZoneId;
import 'defs.dart';
import 'state.dart';

/// 행동을 할 수 없는 이유. 문구는 화면에서 만든다.
enum GameError {
  zoneLocked,
  alreadyUnlocked,
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
  final cropsReady = <ZoneId>{};
  final produced = <Species, int>{};
  final born = <Species, int>{};

  /// 사료가 모자라 성장·생산이 멈춘 적이 있다.
  bool feedRanOut = false;

  bool get eventful => cropsReady.isNotEmpty || produced.isNotEmpty || born.isNotEmpty || feedRanOut;
}

DateTime minuteFloor(DateTime t) => DateTime(t.year, t.month, t.day, t.hour, t.minute);

/// 게임 규칙. 모든 함수는 순수 함수다(상태를 받아 새 상태를 돌려준다).
abstract final class GameEngine {
  /// 새 게임. docs/game-design.md §6 처음 상태.
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
      unlocked: {ZoneId.house, ZoneId.vegetable, ZoneId.animals, ZoneId.water, ZoneId.storage},
      fields: {
        for (final z in GameDefs.plotZones) z: FieldState.emptyField,
        ZoneId.vegetable: FieldState(crop: CropId.lettuce, minutesLeft: lettuce.growMinutes - 1),
      },
      animals: [
        for (var i = 0; i < 2; i++)
          GameAnimal(id: 'a$i', species: Species.chicken, ageMinutes: hen.growMinutes, stored: i == 0 ? 1 : 0),
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
    final fields = Map.of(s.fields);
    final animals = [...s.animals];
    final breed = Map.of(s.breedProgress);
    var nextId = s.nextAnimalId;

    for (var m = 0; m < run; m++) {
      water = (water + GameDefs.waterRefillPerMinute).clamp(0, GameDefs.waterCapacity);

      for (final e in fields.entries.toList()) {
        final f = e.value;
        if (f.crop == null || f.ready) continue;
        final def = GameDefs.crops[f.crop]!;
        if (f.waitingWater) {
          if (water >= def.waterL) {
            water -= def.waterL;
            fields[e.key] = f.copyWith(waitingWater: false, minutesLeft: def.regrowMinutes);
          }
          continue;
        }
        final left = f.minutesLeft - 1;
        if (left <= 0) {
          fields[e.key] = f.copyWith(minutesLeft: 0, ready: true);
          report.cropsReady.add(e.key);
        } else {
          fields[e.key] = f.copyWith(minutesLeft: left);
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

      for (final species in Species.values) {
        final adults = animals.where((a) => a.species == species && a.adult).length;
        if (adults < 2) {
          breed.remove(species);
          continue;
        }
        if (animals.length >= GameDefs.penCapacity) continue; // 자리가 날 때까지 진행을 멈춘다
        final progress = (breed[species] ?? 0) + 1;
        if (progress >= GameDefs.animals[species]!.breedEveryMinutes) {
          animals.add(GameAnimal(id: 'a$nextId', species: species));
          nextId++;
          breed[species] = 0;
          report.born[species] = (report.born[species] ?? 0) + 1;
        } else {
          breed[species] = progress;
        }
      }
    }

    report.minutes = run;
    return (
      s.copyWith(
        simTime: target,
        water: water,
        feedUnits: feed,
        fields: fields,
        animals: animals,
        breedProgress: breed,
        nextAnimalId: nextId,
      ),
      report,
    );
  }

  // ---------------------------------------------------------------- 행동

  static GameState unlockZone(GameState s, ZoneId zone) {
    final def = GameDefs.zones[zone];
    if (def == null || s.unlocked.contains(zone)) throw const GameException(GameError.alreadyUnlocked);
    if (s.level < def.unlockLevel) throw const GameException(GameError.levelTooLow);
    if (s.coins < def.unlockCost) throw const GameException(GameError.notEnoughCoins);
    return _log(
      s.copyWith(coins: s.coins - def.unlockCost, unlocked: {...s.unlocked, zone}),
      LogKind.unlock,
      -def.unlockCost,
      zone.name,
    );
  }

  /// 작물 구역 [zone]에 심을 수 있는 작물(레벨과 무관하게 구역 종류만 맞는 것).
  static List<CropDef> cropsFor(ZoneId zone) {
    final plot = GameDefs.zones[zone]?.plot;
    return [
      for (final c in GameDefs.crops.values)
        if (c.plot == plot) c,
    ];
  }

  static GameState plant(GameState s, ZoneId zone, CropId crop) {
    final zoneDef = GameDefs.zones[zone];
    final def = GameDefs.crops[crop]!;
    if (zoneDef == null || zoneDef.plot != def.plot) throw const GameException(GameError.wrongPlot);
    if (!s.unlocked.contains(zone)) throw const GameException(GameError.zoneLocked);
    if (!(s.fields[zone] ?? FieldState.emptyField).empty) throw const GameException(GameError.fieldNotEmpty);
    if (s.level < def.unlockLevel) throw const GameException(GameError.levelTooLow);
    if (s.coins < def.seedCost) throw const GameException(GameError.notEnoughCoins);
    if (s.water < def.waterL) throw const GameException(GameError.notEnoughWater);
    return _log(
      s.copyWith(
        coins: s.coins - def.seedCost,
        water: s.water - def.waterL,
        fields: {
          ...s.fields,
          zone: FieldState(crop: crop, minutesLeft: def.growMinutes),
        },
      ),
      LogKind.seed,
      -def.seedCost,
      crop.name,
    );
  }

  static GameState harvest(GameState s, ZoneId zone) {
    final f = s.fields[zone] ?? FieldState.emptyField;
    if (f.crop == null || !f.ready) throw const GameException(GameError.notReady);
    final def = GameDefs.crops[f.crop]!;
    if (s.barnFree < def.yieldCount) throw const GameException(GameError.barnFull);
    final FieldState next;
    var water = s.water;
    if (def.perennial) {
      if (water >= def.waterL) {
        water -= def.waterL;
        next = FieldState(crop: f.crop, minutesLeft: def.regrowMinutes!);
      } else {
        next = FieldState(crop: f.crop, waitingWater: true);
      }
    } else {
      next = FieldState.emptyField;
    }
    return s.copyWith(
      barn: _add(s.barn, def.item, def.yieldCount),
      xp: s.xp + def.xp,
      water: water,
      fields: {...s.fields, zone: next},
    );
  }

  /// [species]의 쌓인 생산물을 창고로 옮긴다(창고에 들어가는 만큼). 옮긴 개수를 함께 돌려준다.
  static (GameState, int) collect(GameState s, Species species) {
    final total = s.animals.where((a) => a.species == species).fold(0, (n, a) => n + a.stored);
    if (total == 0) throw const GameException(GameError.nothingToCollect);
    final take = total < s.barnFree ? total : s.barnFree;
    if (take <= 0) throw const GameException(GameError.barnFull);
    final def = GameDefs.animals[species]!;
    var remaining = take;
    final animals = [
      for (final a in s.animals)
        if (a.species != species || remaining == 0 || a.stored == 0)
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

  static GameState buyAnimal(GameState s, Species species) {
    final def = GameDefs.animals[species]!;
    if (s.level < def.unlockLevel) throw const GameException(GameError.levelTooLow);
    if (s.animals.length >= GameDefs.penCapacity) throw const GameException(GameError.penFull);
    if (s.coins < def.buyCost) throw const GameException(GameError.notEnoughCoins);
    return _log(
      s.copyWith(
        coins: s.coins - def.buyCost,
        animals: [
          ...s.animals,
          GameAnimal(id: 'a${s.nextAnimalId}', species: species),
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
