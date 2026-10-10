import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/game/defs.dart';
import 'package:my_farm/game/engine.dart';
import 'package:my_farm/game/lots.dart';
import 'package:my_farm/game/state.dart';

void main() {
  final t0 = DateTime(2026, 10, 6, 9, 0);
  const field = GameDefs.startFieldLot;
  const coop = GameDefs.startCoopLot;
  const emptyA = LotId(1, 2);
  const emptyB = LotId(2, 2);
  GameState fresh() => GameEngine.newGame(t0, farmName: '초록골 농장');
  GameState after(GameState s, int minutes) => GameEngine.advance(s, s.simTime.add(Duration(minutes: minutes))).$1;
  Matcher fails(GameError e) => throwsA(isA<GameException>().having((x) => x.error, 'error', e));

  /// 레벨·코인을 넉넉하게 준 상태(행동 검사용).
  GameState rich(GameState s, {int level = 10}) => s.copyWith(coins: 100000, xp: GameDefs.xpForLevel(level));

  group('처음 상태', () {
    test('처음 땅 6칸: 농가·창고, 상추가 1분 남은 밭, 성체 닭 2마리가 있는 닭장, 빈 땅 2칸', () {
      final s = fresh();
      expect((s.coins, s.level, s.feed, s.water), (100, 1, 60.0, 300));
      expect(s.owned, {...GameDefs.startLots});
      expect(s.lots[GameDefs.farmhouseLot]!.building, BuildingId.farmhouse);
      expect(s.lots[GameDefs.storehouseLot]!.building, BuildingId.storehouse);
      expect(s.lots[field]!.field!.crop, CropId.lettuce);
      expect(s.lots[field]!.field!.minutesLeft, 1);
      expect(s.lots[coop]!.building, BuildingId.coop);
      expect(s.animalsIn(coop).where((a) => a.adult), hasLength(2));
      expect(s.emptyLots, [emptyA, emptyB]);
      expect(s.expansions, 0);
    });

    test('사료 소비량은 성체는 시간당 전부, 새끼는 절반으로 센다', () {
      final s = fresh();
      expect(s.feedPerHourAll, 4); // 성체 닭 2마리 × 2
      final withChick = GameEngine.buyAnimal(s, coop);
      expect(withChick.feedPerHourAll, 5); // 병아리는 2의 절반
      expect(s.copyWith(animals: []).feedPerHourAll, 0);
    });

    test('2레벨은 첫 몇 분 안에 오른다: 상추 수확 3번과 달걀 2개', () {
      expect(GameDefs.xpForLevel(2), lessThanOrEqualTo(3 * GameDefs.crops[CropId.lettuce]!.xp + 2));
    });

    test('1분 뒤 상추가 다 자라고 수확하면 창고에 5개, 경험치 1', () {
      final (s, report) = GameEngine.advance(fresh(), t0.add(const Duration(minutes: 1)));
      expect(s.lots[field]!.field!.ready, isTrue);
      expect(report.cropsReady, {field});
      final h = GameEngine.harvest(s, field);
      expect(h.countOf(ItemId.lettuce), 5);
      expect(h.xp, 1);
      expect(h.lots[field]!.field!.empty, isTrue);
    });
  });

  group('땅·건물', () {
    test('빈 땅에 레벨·코인이 되면 지을 수 있고, 작물 건물은 빈 밭으로 시작한다', () {
      final s = fresh();
      final built = GameEngine.build(s, emptyA, BuildingId.field);
      expect(built.lots[emptyA]!.building, BuildingId.field);
      expect(built.lots[emptyA]!.field!.empty, isTrue);
      expect(built.coins, s.coins - 25);
      expect(built.log.last.kind, LogKind.build);
      expect(() => GameEngine.build(built, emptyA, BuildingId.coop), fails(GameError.lotOccupied));
      expect(() => GameEngine.build(s, emptyB, BuildingId.goatPen), fails(GameError.levelTooLow));
      expect(() => GameEngine.build(s.copyWith(coins: 10), emptyB, BuildingId.field), fails(GameError.notEnoughCoins));
      expect(() => GameEngine.build(s, const LotId(0, 0), BuildingId.field), fails(GameError.notOwned));
      expect(() => GameEngine.build(s, emptyB, BuildingId.farmhouse), fails(GameError.wrongBuilding));
    });

    test('같은 건물을 여러 개 지을 수 있다', () {
      var s = rich(fresh());
      s = GameEngine.build(s, emptyA, BuildingId.coop);
      s = GameEngine.build(s, emptyB, BuildingId.coop);
      expect([for (final l in s.lots.values) l.building].where((b) => b == BuildingId.coop), hasLength(3));
    });

    test('비어 있는 건물만 철거하고 짓기 비용의 절반을 돌려받는다. 핵심 건물은 철거할 수 없다', () {
      var s = GameEngine.build(fresh(), emptyA, BuildingId.coop);
      final demolished = GameEngine.demolish(s, emptyA);
      expect(demolished.lots.containsKey(emptyA), isFalse);
      expect(demolished.coins, s.coins + 20);
      expect(demolished.log.last.kind, LogKind.demolish);
      expect(() => GameEngine.demolish(s, coop), fails(GameError.cannotDemolish)); // 닭이 있다
      expect(() => GameEngine.demolish(s, field), fails(GameError.cannotDemolish)); // 상추가 자란다
      expect(() => GameEngine.demolish(s, GameDefs.farmhouseLot), fails(GameError.cannotDemolish));
      expect(() => GameEngine.demolish(s, emptyB), fails(GameError.cannotDemolish)); // 빈 땅
      s = GameEngine.harvest(after(s, 1), field);
      expect(GameEngine.demolish(s, field).lots.containsKey(field), isFalse);
    });

    test('땅 넓히기는 붙은 칸만, 레벨 한도 안에서, 횟수에 따라 오르는 비용으로 한다', () {
      final s = fresh();
      expect(() => GameEngine.clearLand(s, const LotId(0, 1)), fails(GameError.expansionLimit)); // 1레벨은 0칸
      final lv2 = rich(s, level: 2);
      expect(() => GameEngine.clearLand(lv2, const LotId(0, 4)), fails(GameError.cannotExpand)); // 붙어 있지 않다
      expect(() => GameEngine.clearLand(lv2, field), fails(GameError.cannotExpand)); // 이미 가졌다
      final one = GameEngine.clearLand(lv2, const LotId(0, 1));
      expect(one.owned.contains(const LotId(0, 1)), isTrue);
      expect(one.coins, lv2.coins - 30);
      expect(one.expansions, 1);
      final two = GameEngine.clearLand(one, const LotId(0, 2)); // 방금 넓힌 칸에 붙은 칸
      expect(two.coins, one.coins - 50);
      expect(() => GameEngine.clearLand(two, const LotId(3, 1)), fails(GameError.expansionLimit)); // 2레벨은 2칸
      expect(GameDefs.expansionsAllowed(8), GameDefs.expansionCosts.length);
      expect(() => GameEngine.clearLand(lv2.copyWith(coins: 10), const LotId(0, 1)), fails(GameError.notEnoughCoins));
    });
  });

  group('시간 진행', () {
    test('나눠서 진행해도 한 번에 진행한 결과와 똑같다(무작위 분할, 초 단위 포함)', () {
      final rng = math.Random(42);
      var base = rich(fresh(), level: 8);
      base = GameEngine.build(base, emptyA, BuildingId.orchard);
      base = GameEngine.build(base, emptyB, BuildingId.cowBarn);
      base = GameEngine.clearLand(base, const LotId(1, 3));
      base = GameEngine.build(base, const LotId(1, 3), BuildingId.goatPen);
      base = GameEngine.clearLand(base, const LotId(0, 1));
      base = GameEngine.build(base, const LotId(0, 1), BuildingId.field);
      base = GameEngine.plant(base, const LotId(0, 1), CropId.tomato);
      base = GameEngine.plant(base, emptyA, CropId.apple);
      base = GameEngine.buyAnimal(base, emptyB);
      base = GameEngine.buyAnimal(base, const LotId(1, 3));
      base = GameEngine.buyAnimal(base, const LotId(1, 3));
      base = base.copyWith(feedUnits: 90 * GameDefs.feedUnit);
      final end = base.simTime.add(const Duration(minutes: 230, seconds: 40));
      final whole = GameEngine.advance(base, end).$1;
      for (var trial = 0; trial < 5; trial++) {
        var s = base;
        var t = base.simTime;
        while (t.isBefore(end)) {
          t = t.add(Duration(seconds: 1 + rng.nextInt(1500)));
          if (t.isAfter(end)) t = end;
          s = GameEngine.advance(s, t).$1;
        }
        expect(jsonEncode(s.toJson()), jsonEncode(whole.toJson()), reason: 'trial $trial');
      }
    });

    test('온전한 분만 계산하고 남는 초는 다음으로 넘긴다', () {
      final (s, r) = GameEngine.advance(fresh(), t0.add(const Duration(seconds: 59)));
      expect(r.minutes, 0);
      expect(s.simTime, t0);
    });

    test('오프라인 상한(4시간)을 넘는 시간은 버리고, 시각은 지금으로 맞춘다', () {
      final to = t0.add(const Duration(hours: 6));
      final (s, r) = GameEngine.advance(fresh(), to);
      expect(r.minutes, 240);
      expect(r.skippedMinutes, 120);
      expect(s.simTime, to);
    });

    test('기기 시계가 거꾸로 가면 진행하지 않는다', () {
      final s = fresh();
      final (back, r) = GameEngine.advance(s, t0.subtract(const Duration(hours: 1)));
      expect(identical(back, s), isTrue);
      expect(r.minutes, 0);
    });

    test('물은 매분 5L씩 차고 한도에서 멈춘다', () {
      expect(after(fresh(), 10).water, 350);
      expect(after(fresh(), 200).water, GameDefs.waterCapacity);
    });
  });

  group('가축', () {
    test('병아리는 사료를 절반만 먹으며 10분 뒤 성체가 된다', () {
      var s = GameEngine.buyAnimal(fresh().copyWith(animals: const []), coop);
      final feed0 = s.feedUnits;
      s = after(s, 10);
      final chick = s.animals.single;
      expect(chick.adult, isTrue);
      expect(chick.home, coop);
      expect(feed0 - s.feedUnits, 10 * 1); // 시간당 2 → 자라는 동안 분당 1/60 단위 1
    });

    test('성체는 6분마다 달걀을 낳고, 한도(5)에 차면 생산과 사료 소비를 멈춘다', () {
      const hen = GameAnimal(id: 'h', species: Species.chicken, home: coop, ageMinutes: 10);
      var s = fresh().copyWith(animals: [hen]);
      s = after(s, 12);
      expect(s.animals.single.stored, 2);
      s = after(s, 60);
      expect(s.animals.single.stored, 5);
      final feed = s.feedUnits;
      s = after(s, 30);
      expect(s.feedUnits, feed);
    });

    test('사료가 떨어지면 성장·생산이 멈추고 보고서에 남는다', () {
      const hen = GameAnimal(id: 'h', species: Species.chicken, home: coop, ageMinutes: 10);
      final (s, r) = GameEngine.advance(
        fresh().copyWith(animals: [hen], feedUnits: 3),
        t0.add(const Duration(minutes: 30)),
      );
      expect(r.feedRanOut, isTrue);
      expect(s.animals.single.stored, 0);
      expect(s.feedUnits, 1); // 분당 2단위를 먹는데 3단위뿐 → 한 번만 먹고 1이 남는다
    });

    test('같은 우리에 성체가 2마리면 번식 주기마다 새끼가 태어나고, 우리가 차면 멈춘다', () {
      final s = fresh().copyWith(feedUnits: 200 * GameDefs.feedUnit);
      final (born, r) = GameEngine.advance(s, t0.add(const Duration(minutes: 40)));
      expect(r.born[Species.chicken], 1);
      expect(born.animals, hasLength(3));
      expect(born.animals.last.adult, isFalse);
      expect(born.animals.last.home, coop);

      final cap = s.penCapacity(coop);
      final full = s.copyWith(
        animals: [
          for (var i = 0; i < cap; i++) GameAnimal(id: 'x$i', species: Species.chicken, home: coop, ageMinutes: 10),
        ],
      );
      final (still, r2) = GameEngine.advance(full, t0.add(const Duration(minutes: 120)));
      expect(still.animals, hasLength(cap));
      expect(r2.born, isEmpty);
    });

    test('번식은 우리마다 따로 센다: 다른 닭장의 닭과는 짝이 되지 않는다', () {
      var s = GameEngine.build(fresh(), emptyA, BuildingId.coop).copyWith(feedUnits: 200 * GameDefs.feedUnit);
      s = s.copyWith(
        animals: const [
          GameAnimal(id: 'p', species: Species.chicken, home: coop, ageMinutes: 10),
          GameAnimal(id: 'q', species: Species.chicken, home: emptyA, ageMinutes: 10),
        ],
      );
      final (_, r) = GameEngine.advance(s, t0.add(const Duration(minutes: 60)));
      expect(r.born, isEmpty);
    });

    test('짜기·줍기는 그 우리 것만, 창고에 들어가는 만큼만 옮기고 개당 경험치를 준다', () {
      var s = fresh().copyWith(
        animals: const [
          GameAnimal(id: 'a', species: Species.chicken, home: coop, ageMinutes: 10, stored: 4),
          GameAnimal(id: 'b', species: Species.chicken, home: coop, ageMinutes: 10, stored: 3),
        ],
        barn: {ItemId.lettuce: GameDefs.barnCapacity - 5},
      );
      final (after1, took) = GameEngine.collect(s, coop);
      expect(took, 5);
      expect(after1.countOf(ItemId.egg), 5);
      expect(after1.xp, 5);
      expect([for (final a in after1.animals) a.stored], [0, 2]);
      expect(() => GameEngine.collect(after1, coop), fails(GameError.barnFull));
      expect(() => GameEngine.collect(after1, field), fails(GameError.wrongBuilding));
      s = s.copyWith(animals: const []);
      expect(() => GameEngine.collect(s, coop), fails(GameError.nothingToCollect));
    });

    test('출하는 성체만, 쌓인 생산물은 창고로 옮기고 값과 경험치를 받는다', () {
      final s = fresh();
      final hen = s.animals.first; // 달걀 1개가 쌓여 있다
      final sold = GameEngine.slaughter(s, hen.id);
      expect(sold.coins, s.coins + 45);
      expect(sold.countOf(ItemId.egg), 1);
      expect(sold.animals, hasLength(1));
      expect(sold.log.last.kind, LogKind.slaughter);

      final withChick = GameEngine.buyAnimal(s, coop);
      expect(() => GameEngine.slaughter(withChick, withChick.animals.last.id), fails(GameError.notAdult));
      expect(() => GameEngine.slaughter(s, 'nope'), fails(GameError.unknownAnimal));
    });

    test('새끼 들이기는 우리 종류·레벨·우리 자리·코인을 확인한다', () {
      expect(() => GameEngine.buyAnimal(fresh(), field), fails(GameError.wrongBuilding));
      final barn = GameEngine.build(rich(fresh()), emptyA, BuildingId.cowBarn).copyWith(xp: 0);
      expect(() => GameEngine.buyAnimal(barn, emptyA), fails(GameError.levelTooLow));
      final poor = fresh().copyWith(coins: 10);
      expect(() => GameEngine.buyAnimal(poor, coop), fails(GameError.notEnoughCoins));
      var s = rich(fresh());
      for (var i = s.animalsIn(coop).length; i < s.penCapacity(coop); i++) {
        s = GameEngine.buyAnimal(s, coop);
      }
      expect(s.penCapacity(coop), 4);
      expect(() => GameEngine.buyAnimal(s, coop), fails(GameError.penFull));
    });
  });

  group('작물', () {
    test('심기는 건물 종류·빈 밭·레벨·코인·물을 확인한다', () {
      final s = after(fresh(), 1); // 밭의 상추가 다 자람
      expect(() => GameEngine.plant(s, field, CropId.lettuce), fails(GameError.fieldNotEmpty));
      final empty = GameEngine.harvest(s, field);
      expect(() => GameEngine.plant(empty, field, CropId.carrot), fails(GameError.levelTooLow));
      expect(() => GameEngine.plant(empty, field, CropId.strawberry), fails(GameError.wrongPlot));
      expect(() => GameEngine.plant(empty, coop, CropId.lettuce), fails(GameError.wrongPlot));
      expect(() => GameEngine.plant(empty.copyWith(water: 5), field, CropId.lettuce), fails(GameError.notEnoughWater));
      final planted = GameEngine.plant(empty, field, CropId.lettuce);
      expect(planted.coins, empty.coins - 4);
      expect(planted.water, empty.water - 10);
      expect(planted.lots[field]!.field!.minutesLeft, 2);
    });

    test('창고에 자리가 없으면 수확하지 않고 밭에서 기다린다', () {
      final s = after(fresh(), 1).copyWith(barn: {ItemId.egg: GameDefs.barnCapacity - 2});
      expect(() => GameEngine.harvest(s, field), fails(GameError.barnFull));
      expect(after(s, 600).lots[field]!.field!.ready, isTrue);
    });

    test('사과나무는 수확 뒤 물이 있으면 다음 회차가 시작되고, 없으면 물을 기다렸다 시작한다', () {
      var s = GameEngine.build(rich(fresh()), emptyA, BuildingId.orchard);
      s = GameEngine.plant(s, emptyA, CropId.apple);
      s = after(s, 180);
      expect(s.lots[emptyA]!.field!.ready, isTrue);
      final regrow = GameEngine.harvest(s, emptyA);
      expect(regrow.countOf(ItemId.apple), 15);
      expect(regrow.lots[emptyA]!.field!.minutesLeft, 90);

      final dry = GameEngine.harvest(s.copyWith(water: 0), emptyA);
      expect(dry.lots[emptyA]!.field!.waitingWater, isTrue);
      final resumed = after(dry, 12); // 매분 5L → 12분째에 60L
      expect(resumed.lots[emptyA]!.field!.waitingWater, isFalse);
      expect(resumed.lots[emptyA]!.field!.minutesLeft, 90);
    });
  });

  group('창고·사료', () {
    test('팔면 개당 값만큼 코인이 늘고 기록에 남는다', () {
      final s = fresh().copyWith(barn: {ItemId.milk: 3});
      final sold = GameEngine.sell(s, ItemId.milk, 2);
      expect(sold.coins, s.coins + 44);
      expect(sold.countOf(ItemId.milk), 1);
      expect(sold.log.last.amount, 44);
      expect(() => GameEngine.sell(sold, ItemId.milk, 2), fails(GameError.notEnoughItems));
    });

    test('사료 사기와 옥수수 → 사료는 사료통 한도를 지킨다', () {
      final s = fresh();
      final bought = GameEngine.buyFeed(s);
      expect(bought.feed, 80);
      expect(bought.coins, s.coins - 12);
      final full = s.copyWith(feedUnits: (GameDefs.feedCapacity - 10) * GameDefs.feedUnit);
      expect(() => GameEngine.buyFeed(full), fails(GameError.siloFull));

      final corn = s.copyWith(barn: {ItemId.corn: 4});
      final fed = GameEngine.cornToFeed(corn, 4);
      expect(fed.feed, 72);
      expect(fed.countOf(ItemId.corn), 0);
      expect(() => GameEngine.cornToFeed(corn, 5), fails(GameError.notEnoughItems));
    });
  });

  group('저장 형식', () {
    test('JSON으로 왕복해도 같다', () {
      var s = rich(fresh(), level: 8);
      s = GameEngine.build(s, emptyA, BuildingId.orchard);
      s = GameEngine.plant(s, emptyA, CropId.apple);
      s = GameEngine.build(s, emptyB, BuildingId.sheepPen);
      s = GameEngine.buyAnimal(s, emptyB);
      s = GameEngine.clearLand(s, const LotId(3, 1));
      s = after(s, 77);
      final back = GameState.fromJson((jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, Object?>());
      expect(jsonEncode(back.toJson()), jsonEncode(s.toJson()));
    });

    test('관리 앱 시절(v4) 저장본은 legacy, 더 새로운 버전은 newer로 거부한다', () {
      expect(
        () => GameState.fromJson({'schemaVersion': 4}),
        throwsA(isA<UnsupportedGameSchema>().having((e) => e.legacy, 'legacy', isTrue)),
      );
      expect(
        () => GameState.fromJson({'schemaVersion': 7}),
        throwsA(isA<UnsupportedGameSchema>().having((e) => e.newer, 'newer', isTrue)),
      );
    });

    test('레벨 경계', () {
      expect([0, 4, 5, 14, 15, 1199, 1200, 1699, 1700].map(GameDefs.levelForXp), [1, 1, 2, 2, 3, 9, 10, 10, 11]);
      for (var level = 1; level < 15; level++) {
        expect(GameDefs.levelForXp(GameDefs.xpForLevel(level)), level, reason: '$level');
      }
    });
  });
}
