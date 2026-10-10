import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/game/defs.dart';
import 'package:my_farm/game/engine.dart';
import 'package:my_farm/game/lots.dart';
import 'package:my_farm/game/state.dart';

/// L3 가공과 새 작물. docs/farm-lots-design.md §10.
void main() {
  final t0 = DateTime(2026, 10, 6, 9, 0);
  const shop = LotId(1, 2);
  GameState fresh() => GameEngine.newGame(t0, farmName: 'x');
  GameState rich(GameState s, {int level = 10}) => s.copyWith(coins: 100000, xp: GameDefs.xpForLevel(level));
  GameState mill(GameState s) => GameEngine.build(rich(s), shop, BuildingId.mill);
  Matcher fails(GameError e) => throwsA(isA<GameException>().having((x) => x.error, 'error', e));
  (GameState, AdvanceReport) run(GameState s, int minutes) =>
      GameEngine.advance(s, s.simTime.add(Duration(minutes: minutes)), capMinutes: 100000);

  test('방앗간은 밀 3개로 10분 뒤 밀가루 하나를 만들고, 꺼내면 창고와 경험치가 는다', () {
    var s = mill(fresh()).copyWith(barn: {ItemId.wheat: 7});
    expect(() => GameEngine.collectCraft(s, shop), fails(GameError.notReady));
    s = GameEngine.startCraft(s, shop);
    expect(s.countOf(ItemId.wheat), 4);
    expect(s.lots[shop]!.job!.minutesLeft, 10);
    expect(() => GameEngine.startCraft(s, shop), fails(GameError.workshopBusy));
    expect(() => GameEngine.demolish(s, shop), fails(GameError.cannotDemolish));
    final (done, r) = run(s, 10);
    expect(done.lots[shop]!.job!.done, isTrue);
    expect(r.craftsDone, {shop});
    final xp = done.xp;
    final out = GameEngine.collectCraft(done, shop);
    expect(out.countOf(ItemId.flour), 1);
    expect(out.xp, xp + 2);
    expect(out.lots[shop]!.job, isNull);
  });

  test('재료가 모자라거나 공방이 아니면 만들 수 없다', () {
    final s = mill(fresh()).copyWith(barn: {ItemId.wheat: 2});
    expect(() => GameEngine.startCraft(s, shop), fails(GameError.notEnoughItems));
    expect(() => GameEngine.startCraft(s, GameDefs.startFieldLot), fails(GameError.wrongBuilding));
    final full = GameEngine.startCraft(s.copyWith(barn: {ItemId.wheat: 3}), shop);
    final done = run(full, 10).$1.copyWith(barn: {ItemId.egg: full.barnCapacity});
    expect(() => GameEngine.collectCraft(done, shop), fails(GameError.barnFull));
  });

  test('공방 Lv2부터 만드는 시간이 25% 줄고(올림), 빵집은 재료 두 가지를 쓴다', () {
    final recipe = GameDefs.buildings[BuildingId.mill]!.recipe!;
    expect(GameDefs.craftMinutes(recipe, 1), 10);
    expect(GameDefs.craftMinutes(recipe, 2), 8); // 7.5 → 8
    var s = GameEngine.build(rich(fresh()), shop, BuildingId.bakery);
    s = s.copyWith(barn: {ItemId.flour: 2, ItemId.egg: 3});
    s = GameEngine.startCraft(s, shop);
    expect(s.barn, {ItemId.egg: 1});
  });

  test('Lv3 공방은 다 되면 저절로 꺼내고 재료가 있으면 다시 만든다', () {
    var s = mill(fresh());
    s = GameEngine.upgrade(GameEngine.upgrade(s, shop), shop).copyWith(barn: {ItemId.wheat: 9});
    s = GameEngine.startCraft(s, shop); // 남은 밀 6 → 두 번 더
    final (after, r) = run(s, 30); // Lv3: 8분마다
    expect(r.autoCrafted, 3);
    expect(after.countOf(ItemId.flour), 3);
    expect(after.countOf(ItemId.wheat), 0);
    expect(after.lots[shop]!.job, isNull); // 재료가 떨어져 쉰다
    expect(r.craftsDone, isEmpty);
  });

  test('새 작물은 레벨에 따라 밭에 심을 수 있다(밀 4·감자 5·호박 7레벨)', () {
    var s = GameEngine.harvest(run(fresh(), 1).$1, GameDefs.startFieldLot).copyWith(coins: 1000);
    expect(() => GameEngine.plant(s, GameDefs.startFieldLot, CropId.wheat), fails(GameError.levelTooLow));
    s = s.copyWith(xp: GameDefs.xpForLevel(4));
    s = GameEngine.plant(s, GameDefs.startFieldLot, CropId.wheat);
    s = run(s, 8).$1;
    expect(GameEngine.harvest(s, GameDefs.startFieldLot).countOf(ItemId.wheat), 6);
    expect(GameDefs.crops[CropId.potato]!.unlockLevel, 5);
    expect(GameDefs.crops[CropId.pumpkin]!.unlockLevel, 7);
  });

  test('만드는 중인 공방도 저장·왕복되고, 나눠 진행한 결과가 한 번에 진행한 결과와 같다', () {
    var s = mill(fresh());
    s = GameEngine.upgrade(GameEngine.upgrade(s, shop), shop).copyWith(barn: {ItemId.wheat: 30});
    s = GameEngine.startCraft(s, shop);
    final back = GameState.fromJson((jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, Object?>());
    expect(jsonEncode(back.toJson()), jsonEncode(s.toJson()));
    final end = s.simTime.add(const Duration(minutes: 77));
    final whole = GameEngine.advance(s, end).$1;
    var split = s;
    for (final m in const [3, 11, 5, 20, 7, 31]) {
      split = GameEngine.advance(split, split.simTime.add(Duration(minutes: m))).$1;
    }
    expect(jsonEncode(split.toJson()), jsonEncode(whole.toJson()));
  });
}
