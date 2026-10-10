import 'defs.dart';
import 'lots.dart';
import 'orders.dart';
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

  /// 이미 최고 레벨이다.
  maxLevel,

  /// 공방이 이미 만드는 중이다(다 만든 것을 꺼내야 다시 만들 수 있다).
  workshopBusy,

  /// 그 칸에 주문이 없다(새 주문을 기다리는 중).
  noOrder,
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

  /// Lv3 건물이 저절로 수확한 횟수, 저절로 거둔 생산물 개수, 창고에 못 들어가 판 코인(자동 출하).
  int autoHarvests = 0;
  int autoCollected = 0;
  int autoSoldCoins = 0;

  /// 공방에서 다 만든 것(손으로 꺼내야 하는 것 포함)과 Lv3 공방이 저절로 꺼낸 개수.
  final craftsDone = <LotId>{};
  int autoCrafted = 0;

  bool get eventful =>
      cropsReady.isNotEmpty ||
      produced.isNotEmpty ||
      born.isNotEmpty ||
      feedRanOut ||
      autoHarvests > 0 ||
      autoCollected > 0 ||
      craftsDone.isNotEmpty ||
      autoCrafted > 0;
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
      orders: [for (var i = 0; i < OrderBook.slotsFor(1); i++) OrderSlot.order(OrderBook.make(i, 1))],
      orderSeq: OrderBook.slotsFor(1),
    );
  }

  /// [to]까지 시간을 진행한다. 온전한 분만 계산하고, [capMinutes](없으면 농가 레벨에 따른 자리 비운 시간)를 넘는
  /// 시간은 버린다.
  ///
  /// 분마다 같은 순서로 처리한다: 물 충전 → 작물 성장 → Lv3 작물 건물 자동 수확·다시 심기 → 가축 성장·생산 →
  /// Lv3 우리 자동 줍기 → 공방(진행, Lv3 자동 꺼내기·다시 만들기) → 번식 → 주문 게시판(칸 늘리기, 새 주문). 그래서 나눠 진행한 결과와 한 번에 진행한 결과가 같다. 자동 판매·씨앗 기록도
  /// 그 분의 시각으로 남는다.
  static (GameState, AdvanceReport) advance(GameState s, DateTime to, {int? capMinutes}) {
    final report = AdvanceReport();
    final target = minuteFloor(to);
    final total = target.difference(s.simTime).inMinutes;
    if (total <= 0) return (s, report);
    final cap = capMinutes ?? s.offlineCapMinutes;
    final run = total > cap ? cap : total;
    report.skippedMinutes = total - run;

    var water = s.water;
    var feed = s.feedUnits;
    var coins = s.coins;
    var xp = s.xp;
    final barn = Map.of(s.barn);
    var barnUsed = s.barnUsed;
    final barnCap = s.barnCapacity;
    final autoShip = s.autoShip;
    final log = [...s.log];
    final lots = Map.of(s.lots);
    final plots = [
      for (final id in s.builtLots)
        if (s.lots[id]!.field != null) id,
    ];
    final pens = [
      for (final id in s.builtLots)
        if (s.lots[id]!.def.species != null) id,
    ];
    final workshops = [
      for (final id in s.builtLots)
        if (s.lots[id]!.def.recipe != null) id,
    ];
    // 꾸미기 효과는 진행 중에 바뀌지 않으므로(짓기·철거는 행동) 미리 계산한다.
    final yieldBonus = {for (final id in plots) id: s.yieldBonus(id)};
    final produceEvery = {for (final id in pens) id: s.produceEvery(id, GameDefs.animals[s.lots[id]!.def.species!]!)};
    final animals = [...s.animals];
    final breed = Map.of(s.breedProgress);
    var nextId = s.nextAnimalId;
    final orders = [...s.orders];
    var orderSeq = s.orderSeq;

    /// 자동 판매·자동 다시 심기 기록을 남긴다. Lv3 건물은 몇 분마다 기록을 만들어 [GameState.maxLog]를 금방 채우고,
    /// 그러면 기록 화면의 오늘·7일 합계가 실제보다 작아진다(#32 리뷰). 그래서 같은 날 같은 종류·대상의 기록이 있으면
    /// 그 금액에 더해 맨 뒤로 옮긴다. 날마다 합계는 그대로이고, 나눠 진행해도 한 번에 진행한 것과 같다.
    void addAuto(GameLogEntry e) {
      for (var i = log.length - 1; i >= 0; i--) {
        final o = log[i];
        if (!_sameDay(o.at, e.at)) break;
        if (o.kind != e.kind || o.subject != e.subject) continue;
        log
          ..removeAt(i)
          ..add(GameLogEntry(at: e.at, kind: e.kind, amount: o.amount + e.amount, subject: e.subject));
        return;
      }
      log.add(e);
    }

    /// 자동으로 거둔 [count]개를 창고에 넣는다. 다 들어가지 않으면 창고 Lv3은 남는 몫을 팔고, 아니면 들어가는
    /// 만큼만 넣는다. 넣거나 판 개수를 돌려준다.
    int store(ItemId item, int count, DateTime at, {required bool partial}) {
      final free = barnCap - barnUsed;
      if (count <= free) {
        barn[item] = (barn[item] ?? 0) + count;
        barnUsed += count;
        return count;
      }
      if (!autoShip && !partial) return 0;
      final kept = free < 0 ? 0 : free;
      if (kept > 0) {
        barn[item] = (barn[item] ?? 0) + kept;
        barnUsed += kept;
      }
      if (!autoShip) return kept;
      final sold = count - kept;
      final amount = GameDefs.itemPrice[item]! * sold;
      coins += amount;
      report.autoSoldCoins += amount;
      addAuto(GameLogEntry(at: at, kind: LogKind.sale, amount: amount, subject: item.name));
      return count;
    }

    for (var m = 0; m < run; m++) {
      final minute = s.simTime.add(Duration(minutes: m));
      water = (water + GameSky.waterRefillAt(minute, base: s.waterRefillPerMinute)).clamp(0, s.waterCapacity);

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

      // Lv3 작물 건물: 다 자랐으면 거두고(창고가 차면 기다리거나 창고 Lv3이면 판다), 다시 심는다.
      for (final id in plots) {
        final lot = lots[id]!;
        final f = lot.field!;
        if (lot.level < GameDefs.autoLevel || !f.ready || f.crop == null) continue;
        final def = GameDefs.crops[f.crop]!;
        final count = yieldFor(def, yieldBonus[id]!, minute);
        if (store(def.item, count, minute, partial: false) == 0) continue;
        xp += def.xp;
        report.autoHarvests++;
        report.cropsReady.remove(id);
        final FieldState next;
        if (def.perennial) {
          if (water >= def.waterL) {
            water -= def.waterL;
            next = FieldState(crop: f.crop, minutesLeft: def.regrowMinutes!, totalMinutes: def.regrowMinutes!);
          } else {
            next = FieldState(crop: f.crop, waitingWater: true, totalMinutes: def.regrowMinutes!);
          }
        } else if (coins >= def.seedCost && water >= def.waterL) {
          coins -= def.seedCost;
          water -= def.waterL;
          addAuto(GameLogEntry(at: minute, kind: LogKind.seed, amount: -def.seedCost, subject: f.crop!.name));
          next = FieldState(crop: f.crop, minutesLeft: def.growMinutes, totalMinutes: def.growMinutes);
        } else {
          next = FieldState.emptyField; // 씨앗값·물이 모자라면 그 칸만 멈춘다
        }
        lots[id] = lot.copyWith(field: next);
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
            if (progress >= (produceEvery[a.home] ?? def.produceEveryMinutes)) {
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

      // Lv3 우리: 쌓인 생산물을 저절로 거둔다(창고에 들어가는 만큼, 창고 Lv3이면 남는 몫은 판다).
      for (var i = 0; i < animals.length; i++) {
        final a = animals[i];
        if (a.stored == 0 || (lots[a.home]?.level ?? 1) < GameDefs.autoLevel) continue;
        final def = a.def;
        final took = store(def.product, a.stored, minute, partial: true);
        if (took == 0) continue;
        animals[i] = a.copyWith(stored: a.stored - took);
        xp += def.collectXp * took;
        report.autoCollected += took;
      }

      // 공방: 만드는 중이면 진행하고, 다 되면 Lv3은 꺼내고(창고가 차면 기다리거나 창고 Lv3이면 판다) 재료가
      // 있으면 다시 만든다.
      for (final id in workshops) {
        final lot = lots[id]!;
        final job = lot.job;
        if (job == null) continue;
        final recipe = lot.def.recipe!;
        if (!job.done) {
          final next = WorkshopJob(minutesLeft: job.minutesLeft - 1, totalMinutes: job.totalMinutes);
          lots[id] = lot.copyWith(job: next);
          if (!next.done) continue;
          report.craftsDone.add(id);
        }
        if (lot.level < GameDefs.autoLevel) continue;
        if (store(recipe.output, 1, minute, partial: false) == 0) continue;
        xp += recipe.xp;
        report.autoCrafted++;
        report.craftsDone.remove(id);
        if (recipe.inputs.entries.every((e) => (barn[e.key] ?? 0) >= e.value)) {
          for (final e in recipe.inputs.entries) {
            barn[e.key] = barn[e.key]! - e.value;
            barnUsed -= e.value;
          }
          final minutes = GameDefs.craftMinutes(recipe, lot.level);
          lots[id] = lots[id]!.copyWith(
            job: WorkshopJob(minutesLeft: minutes, totalMinutes: minutes),
          );
        } else {
          lots[id] = lots[id]!.copyWith(clearJob: true);
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

      // 주문 게시판: 레벨이 오르면 칸을 늘리고, 기다리던 칸에는 새 주문을 붙인다.
      final level = GameDefs.levelForXp(xp);
      while (orders.length < OrderBook.slotsFor(level)) {
        orders.add(const OrderSlot.waiting(0));
      }
      for (var i = 0; i < orders.length; i++) {
        final slot = orders[i];
        if (slot.order != null) continue;
        if (slot.wait > 1) {
          orders[i] = OrderSlot.waiting(slot.wait - 1);
        } else {
          orders[i] = OrderSlot.order(OrderBook.make(orderSeq++, level));
        }
      }
    }

    barn.removeWhere((_, n) => n == 0);
    report.minutes = run;
    return (
      s.copyWith(
        simTime: target,
        coins: coins,
        xp: xp,
        barn: barn,
        water: water,
        feedUnits: feed,
        lots: lots,
        animals: animals,
        breedProgress: breed,
        nextAnimalId: nextId,
        log: log.length > GameState.maxLog ? log.sublist(log.length - GameState.maxLog) : log,
        orders: orders,
        orderSeq: orderSeq,
      ),
      report,
    );
  }

  /// [def]를 보너스 [bonus]%(건물 레벨·허수아비, [GameState.yieldBonus])인 칸에서 [t]에 거두면 얻는 개수.
  /// 무지개가 떠 있으면 +20%를 더한다(합쳐서, 올림).
  static int yieldFor(CropDef def, int bonus, DateTime t) => baseYield(def, bonus + (GameSky.rainbowAt(t) ? 20 : 0));

  /// 무지개 없이 [bonus]%만 더해 거두는 개수.
  static int baseYield(CropDef def, int bonus) => (def.yieldCount * (100 + bonus) + 99) ~/ 100;

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

  /// 건물을 한 단계 올린다(Lv3까지). docs/farm-lots-design.md §4.
  static GameState upgrade(GameState s, LotId lot) {
    final l = s.lots[lot];
    if (l == null || l.def.upgradeCosts.isEmpty) throw const GameException(GameError.wrongBuilding);
    if (l.level >= l.def.maxLevel) throw const GameException(GameError.maxLevel);
    final cost = l.def.upgradeCosts[l.level - 1];
    if (s.coins < cost) throw const GameException(GameError.notEnoughCoins);
    return _log(
      s.copyWith(
        coins: s.coins - cost,
        lots: {
          ...s.lots,
          lot: l.copyWith(level: l.level + 1),
        },
      ),
      LogKind.upgrade,
      -cost,
      l.building.name,
    );
  }

  /// 비어 있는 건물(작물이 없는 밭, 동물이 없는 우리)을 헐고 짓기 비용의 절반을 돌려받는다.
  static GameState demolish(GameState s, LotId lot) {
    final l = s.lots[lot];
    if (l == null || l.def.core || l.job != null) throw const GameException(GameError.cannotDemolish);
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
    final count = yieldFor(def, s.yieldBonus(lot), s.simTime);
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

  // ---------------------------------------------------------------- 공방

  /// 공방 [lot]에서 레시피대로 만들기 시작한다(재료를 창고에서 꺼낸다).
  static GameState startCraft(GameState s, LotId lot) {
    final l = s.lots[lot];
    final recipe = l?.def.recipe;
    if (l == null || recipe == null) throw const GameException(GameError.wrongBuilding);
    if (l.job != null) throw const GameException(GameError.workshopBusy);
    if (!recipe.inputs.entries.every((e) => s.countOf(e.key) >= e.value)) {
      throw const GameException(GameError.notEnoughItems);
    }
    var barn = s.barn;
    for (final e in recipe.inputs.entries) {
      barn = _add(barn, e.key, -e.value);
    }
    final minutes = GameDefs.craftMinutes(recipe, l.level);
    return s.copyWith(
      barn: barn,
      lots: {
        ...s.lots,
        lot: l.copyWith(
          job: WorkshopJob(minutesLeft: minutes, totalMinutes: minutes),
        ),
      },
    );
  }

  /// 다 만든 가공품을 창고로 꺼낸다.
  static GameState collectCraft(GameState s, LotId lot) {
    final l = s.lots[lot];
    final recipe = l?.def.recipe;
    if (l == null || recipe == null) throw const GameException(GameError.wrongBuilding);
    if (l.job == null || !l.job!.done) throw const GameException(GameError.notReady);
    if (s.barnFree < 1) throw const GameException(GameError.barnFull);
    return s.copyWith(
      barn: _add(s.barn, recipe.output, 1),
      xp: s.xp + recipe.xp,
      lots: {...s.lots, lot: l.copyWith(clearJob: true)},
    );
  }

  // ---------------------------------------------------------------- 주문

  /// [index]번 칸의 주문을 보낸다(물건을 창고에서 꺼내고 코인·경험치를 받는다). 새 주문은 조금 뒤 온다.
  static GameState deliverOrder(GameState s, int index) {
    final order = index < s.orders.length ? s.orders[index].order : null;
    if (order == null) throw const GameException(GameError.noOrder);
    if (!order.items.entries.every((e) => s.countOf(e.key) >= e.value)) {
      throw const GameException(GameError.notEnoughItems);
    }
    var barn = s.barn;
    for (final e in order.items.entries) {
      barn = _add(barn, e.key, -e.value);
    }
    final orders = [...s.orders]..[index] = const OrderSlot.waiting(OrderBook.refillAfterDelivery);
    return _log(
      s.copyWith(barn: barn, coins: s.coins + order.coins, xp: s.xp + order.xp, orders: orders),
      LogKind.order,
      order.coins,
      'order',
    );
  }

  /// [index]번 칸의 주문을 넘긴다. 새 주문은 더 오래 기다린다.
  static GameState skipOrder(GameState s, int index) {
    if (index >= s.orders.length || s.orders[index].order == null) throw const GameException(GameError.noOrder);
    final orders = [...s.orders]..[index] = const OrderSlot.waiting(OrderBook.refillAfterSkip);
    return s.copyWith(orders: orders);
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
    if (s.feedUnits + add > s.feedCapacity * GameDefs.feedUnit) throw const GameException(GameError.siloFull);
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
    if (s.feedUnits + add > s.feedCapacity * GameDefs.feedUnit) throw const GameException(GameError.siloFull);
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

  /// 기록 화면은 기기 시간대의 날짜로 묶으므로(records_screen.dart) 같은 기준으로 비교한다.
  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  static GameState _log(GameState s, LogKind kind, int amount, String subject) {
    final entry = GameLogEntry(at: s.simTime, kind: kind, amount: amount, subject: subject);
    final log = [...s.log, entry];
    return s.copyWith(log: log.length > GameState.maxLog ? log.sublist(log.length - GameState.maxLog) : log);
  }
}
