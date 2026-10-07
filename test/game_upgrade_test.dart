import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/game/defs.dart';
import 'package:my_farm/game/engine.dart';
import 'package:my_farm/game/lots.dart';
import 'package:my_farm/game/sky.dart';
import 'package:my_farm/game/state.dart';

/// L2 업그레이드·자동화. docs/farm-lots-design.md §4.
void main() {
  // 10월 6일 9시: 영향 없는 날씨(game_sky_test가 확인한다).
  final t0 = DateTime(2026, 10, 6, 9, 0);
  const field = GameDefs.startFieldLot;
  const coop = GameDefs.startCoopLot;
  GameState fresh() => GameEngine.newGame(t0, farmName: 'x');
  GameState rich(GameState s) => s.copyWith(coins: 100000, xp: GameDefs.xpForLevel(10));
  GameState up(GameState s, LotId lot, int times) {
    for (var i = 0; i < times; i++) {
      s = GameEngine.upgrade(s, lot);
    }
    return s;
  }

  Matcher fails(GameError e) => throwsA(isA<GameException>().having((x) => x.error, 'error', e));
  (GameState, AdvanceReport) run(GameState s, int minutes) =>
      GameEngine.advance(s, s.simTime.add(Duration(minutes: minutes)), capMinutes: 100000);

  /// 상추를 다 거둔 빈 밭에서 시작한다.
  GameState emptyField(GameState s) => GameEngine.harvest(run(s, 1).$1, field).copyWith(barn: const {});

  test('업그레이드는 Lv3까지, 레벨마다 정해진 비용을 내고 기록에 남는다', () {
    final s = fresh().copyWith(coins: 1000);
    final lv2 = GameEngine.upgrade(s, field);
    expect(lv2.lots[field]!.level, 2);
    expect(lv2.coins, 1000 - 120);
    expect(lv2.log.last.kind, LogKind.upgrade);
    final lv3 = GameEngine.upgrade(lv2, field);
    expect(lv3.coins, 1000 - 120 - 500);
    expect(() => GameEngine.upgrade(lv3, field), fails(GameError.maxLevel));
    expect(() => GameEngine.upgrade(s.copyWith(coins: 50), field), fails(GameError.notEnoughCoins));
    expect(() => GameEngine.upgrade(s, const LotId(1, 2)), fails(GameError.wrongBuilding)); // 빈 땅
  });

  test('농가·창고 레벨이 자리 비운 시간·우물·창고·사료통 한도를 정한다', () {
    var s = rich(fresh());
    expect((s.offlineCapMinutes, s.waterCapacity, s.waterRefillPerMinute), (240, 500, 5));
    expect((s.barnCapacity, s.feedCapacity), (100, 200));
    s = up(s, GameDefs.farmhouseLot, 1);
    s = up(s, GameDefs.storehouseLot, 2);
    expect((s.offlineCapMinutes, s.waterCapacity, s.waterRefillPerMinute), (360, 800, 7));
    expect((s.barnCapacity, s.feedCapacity, s.autoShip), (250, 450, true));
    // 6시간 비우면 6시간을 다 계산한다(Lv1이면 4시간).
    final (_, r) = GameEngine.advance(s, t0.add(const Duration(hours: 8)));
    expect((r.minutes, r.skippedMinutes), (360, 120));
    expect(run(s.copyWith(water: 0), 10).$1.water, 70);
    // 사료통이 커지면 더 살 수 있다.
    expect(GameEngine.buyFeed(s.copyWith(feedUnits: 400 * GameDefs.feedUnit)).feed, 420);
  });

  test('비·폭염은 농가 레벨의 충전량을 기준으로 바뀐다', () {
    expect(GameSky.waterRefillAt(t0, base: 7), 7);
    final rain = DateTime(2026, 10, 7, 12, 30); // 비 블록(game_sky_test의 분포 확인 참고)
    if (GameSky.kindAt(rain) == SkyKind.rain) {
      expect(GameSky.waterRefillAt(rain, base: 7), 14);
    }
  });

  test('작물 건물 Lv2부터 수확량 +25%(올림)', () {
    var s = up(emptyField(rich(fresh())), field, 1);
    s = GameEngine.plant(s, field, CropId.lettuce);
    s = run(s, 2).$1;
    expect(GameEngine.harvest(s, field).countOf(ItemId.lettuce), 7); // 5 × 1.25 = 6.25 → 7
    expect(GameEngine.baseYield(GameDefs.crops[CropId.lettuce]!, 1), 5);
  });

  test('Lv3 밭은 다 자라면 저절로 거두고 같은 작물을 다시 심는다(씨앗값·물을 쓴다)', () {
    var s = up(emptyField(rich(fresh())), field, 2);
    s = GameEngine.plant(s, field, CropId.lettuce);
    final coins = s.coins;
    final xp = s.xp;
    final (after, r) = run(s, 10); // 2분마다 다 자람: 1·3·5·7·9분째
    expect(r.autoHarvests, 5);
    expect(after.countOf(ItemId.lettuce), 5 * 7);
    expect(after.xp, xp + 5);
    expect(after.coins, coins - 5 * 4); // 다시 심을 때마다 씨앗값
    expect(after.lots[field]!.field!.crop, CropId.lettuce);
    expect(r.cropsReady, isEmpty); // 저절로 거둔 것은 '다 자람'으로 알리지 않는다
    expect(after.log.where((e) => e.kind == LogKind.seed), hasLength(1 + 5));
  });

  test('씨앗값이 모자라면 거둔 뒤 그 밭만 비워 두고 멈춘다', () {
    var s = up(emptyField(rich(fresh())), field, 2);
    s = GameEngine.plant(s, field, CropId.lettuce).copyWith(coins: 0);
    final (after, r) = run(s, 10);
    expect(r.autoHarvests, 1);
    expect(after.lots[field]!.field!.empty, isTrue);
  });

  test('창고가 차면 Lv3 밭은 기다리고, 창고 Lv3이면 들어가지 못한 몫을 판다', () {
    var s = up(emptyField(rich(fresh())), field, 2);
    s = GameEngine.plant(s, field, CropId.lettuce).copyWith(barn: {ItemId.egg: s.barnCapacity - 3});
    final (waiting, r1) = run(s, 3);
    expect(r1.autoHarvests, 0);
    expect(waiting.lots[field]!.field!.ready, isTrue);

    s = up(s, GameDefs.storehouseLot, 2).copyWith(barn: {ItemId.egg: 250 - 3});
    final coins = s.coins;
    final (shipped, r2) = run(s, 2);
    expect(r2.autoHarvests, 1);
    expect(shipped.barnUsed, shipped.barnCapacity); // 3개는 창고에
    expect(r2.autoSoldCoins, 4 * 2); // 나머지 4개는 상추 값(2)으로 판다
    expect(shipped.coins, coins + 8 - 4); // 판 값 - 다시 심은 씨앗값
    expect(shipped.log.last.kind, LogKind.seed);
    expect(shipped.log.where((e) => e.kind == LogKind.sale).single.amount, 8);
  });

  test('Lv3 우리는 생산물을 저절로 거둔다(창고에 들어가는 만큼)', () {
    var s = up(rich(fresh()), coop, 2);
    s = s.copyWith(feedUnits: 200 * GameDefs.feedUnit);
    final eggs0 = s.countOf(ItemId.egg);
    final (after, r) = run(s, 12); // 2마리 × 6분마다 → 12분에 4개(+처음 쌓여 있던 1개)
    expect(r.autoCollected, 5);
    expect(after.countOf(ItemId.egg), eggs0 + 5);
    expect(after.animalsIn(coop).every((a) => a.stored == 0), isTrue);
    expect(after.penCapacity(coop), 8);
  });

  test('손대지 않아도 코인이 쌓인다: Lv3 밭·우리와 Lv3 창고(가득 찬 상태)', () {
    // 첫 상추를 손으로 거둔 뒤 올린다(먼저 올리면 Lv3 밭이 저절로 거둔다).
    var s = emptyField(rich(fresh()));
    s = up(s, field, 2);
    s = up(s, coop, 2);
    s = up(s, GameDefs.storehouseLot, 2);
    s = GameEngine.plant(s, field, CropId.lettuce);
    s = s.copyWith(coins: 50, barn: {ItemId.wool: s.barnCapacity}, feedUnits: 400 * GameDefs.feedUnit);
    final (after, r) = GameEngine.advance(s, s.simTime.add(const Duration(hours: 4)));
    expect(r.autoSoldCoins, greaterThan(0));
    expect(after.coins, greaterThan(s.coins + 300));
  });

  test('자동화가 섞여도 나눠 진행한 결과와 한 번에 진행한 결과가 같다', () {
    // 첫 상추를 손으로 거둔 뒤 올린다(먼저 올리면 Lv3 밭이 저절로 거둔다).
    var s = emptyField(rich(fresh()));
    s = up(s, field, 2);
    s = up(s, coop, 2);
    s = up(s, GameDefs.storehouseLot, 2);
    s = GameEngine.plant(s, field, CropId.lettuce);
    s = s.copyWith(coins: 30, barn: {ItemId.wool: s.barnCapacity - 20}, feedUnits: 100 * GameDefs.feedUnit);
    final end = s.simTime.add(const Duration(minutes: 150));
    final whole = GameEngine.advance(s, end).$1;
    var split = s;
    var t = s.simTime;
    var step = 1;
    while (t.isBefore(end)) {
      t = t.add(Duration(minutes: step));
      if (t.isAfter(end)) t = end;
      split = GameEngine.advance(split, t).$1;
      step = step % 17 + 3;
    }
    expect(jsonEncode(split.toJson()), jsonEncode(whole.toJson()));
  });
}
