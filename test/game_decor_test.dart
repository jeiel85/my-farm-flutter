import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/game/defs.dart';
import 'package:my_farm/game/engine.dart';
import 'package:my_farm/game/lots.dart';
import 'package:my_farm/game/state.dart';

/// L5 꾸미기(연못·허수아비·꽃밭). docs/farm-lots-design.md §10.
void main() {
  // 10월 6일 9시: 영향 없는 날씨(game_sky_test가 확인한다).
  final t0 = DateTime(2026, 10, 6, 9, 0);
  const field = GameDefs.startFieldLot; // (1,1)
  const coop = GameDefs.startCoopLot; // (2,1)
  const belowField = LotId(1, 2);
  const belowCoop = LotId(2, 2);
  GameState rich() => GameEngine.newGame(t0, farmName: 'x').copyWith(coins: 100000, xp: GameDefs.xpForLevel(10));
  Matcher fails(GameError e) => throwsA(isA<GameException>().having((x) => x.error, 'error', e));
  GameState run(GameState s, int minutes) =>
      GameEngine.advance(s, s.simTime.add(Duration(minutes: minutes)), capMinutes: 100000).$1;

  test('꾸미기는 레벨이 되면 짓고, 올릴 수 없고, 헐면 절반을 돌려받는다', () {
    final low = GameEngine.newGame(t0, farmName: 'x').copyWith(coins: 1000);
    expect(() => GameEngine.build(low, belowField, BuildingId.pond), fails(GameError.levelTooLow));
    var s = GameEngine.build(rich(), belowField, BuildingId.pond);
    expect(s.lots[belowField]!.building, BuildingId.pond);
    expect(s.lots[belowField]!.field, isNull);
    expect(() => GameEngine.upgrade(s, belowField), fails(GameError.wrongBuilding));
    final coins = s.coins;
    s = GameEngine.demolish(s, belowField);
    expect(s.lots.containsKey(belowField), isFalse);
    expect(s.coins, coins + GameDefs.demolishRefund(BuildingId.pond));
  });

  test('허수아비가 상하좌우로 붙은 작물 건물만 수확량 +10%, 레벨 보너스와 더해진다', () {
    var s = GameEngine.build(rich(), belowField, BuildingId.scarecrow);
    expect(s.yieldBonus(field), GameDefs.scarecrowBonus);
    s = GameEngine.upgrade(s, field);
    expect(s.yieldBonus(field), GameDefs.yieldBonusLv2 + GameDefs.scarecrowBonus);
    // 대각선은 효과가 없다: (2,2)의 허수아비는 (1,1) 밭에 닿지 않는다.
    final diagonal = GameEngine.build(rich(), belowCoop, BuildingId.scarecrow);
    expect(diagonal.yieldBonus(field), 0);
    // 상추 5개 → +10%는 올림해 6개, Lv2(+25%)까지면 +35% → 7개.
    final lettuce = GameDefs.crops[CropId.lettuce]!;
    expect(GameEngine.baseYield(lettuce, GameDefs.scarecrowBonus), 6);
    expect(GameEngine.baseYield(lettuce, GameDefs.yieldBonusLv2 + GameDefs.scarecrowBonus), 7);
    // 실제로 거두면 그만큼 들어온다.
    final grown = run(GameEngine.build(rich(), belowField, BuildingId.scarecrow), 1);
    expect(GameEngine.harvest(grown, field).countOf(ItemId.lettuce) - grown.countOf(ItemId.lettuce), 6);
  });

  test('꽃밭이 붙은 우리는 생산 주기가 10% 줄어(내림) 닭이 5분마다 낳는다', () {
    expect(GameDefs.flowerProduceMinutes(6), 5);
    expect(GameDefs.flowerProduceMinutes(45), 40);
    expect(GameDefs.flowerProduceMinutes(1), 1);
    const hen = GameAnimal(id: 'h', species: Species.chicken, home: coop, ageMinutes: 10);
    final plain = rich().copyWith(animals: [hen]);
    final flowered = GameEngine.build(plain, belowCoop, BuildingId.flowerBed);
    final chicken = GameDefs.animals[Species.chicken]!;
    expect(plain.produceEvery(coop, chicken), 6);
    expect(flowered.produceEvery(coop, chicken), 5);
    // 15분: 꽃밭 없으면 2개, 있으면 3개.
    expect(run(plain, 15).animals.single.stored, 2);
    expect(run(flowered, 15).animals.single.stored, 3);
  });

  test('연못 하나마다 우물이 분당 1L 더 차고, 3개까지만 센다', () {
    var s = rich();
    final base = s.waterRefillPerMinute;
    final spots = [belowField, belowCoop, const LotId(0, 1), const LotId(3, 1)];
    for (final (i, lot) in spots.indexed) {
      if (!s.owned.contains(lot)) s = GameEngine.clearLand(s, lot);
      s = GameEngine.build(s, lot, BuildingId.pond);
      expect(s.waterRefillPerMinute, base + GameDefs.pondRefill * (i + 1).clamp(0, GameDefs.maxPonds));
    }
    expect(run(s.copyWith(water: 0), 10).water, 10 * (base + GameDefs.maxPonds));
  });

  test('꾸미기가 있어도 나눠 진행한 결과와 한 번에 진행한 결과가 같다', () {
    const hen = GameAnimal(id: 'h', species: Species.chicken, home: coop, ageMinutes: 10);
    var s = rich().copyWith(
      animals: [
        hen,
        const GameAnimal(id: 'h2', species: Species.chicken, home: coop, ageMinutes: 10),
      ],
    );
    s = GameEngine.build(s, belowField, BuildingId.scarecrow);
    s = GameEngine.build(s, belowCoop, BuildingId.flowerBed);
    s = GameEngine.upgrade(GameEngine.upgrade(s, field), field); // Lv3: 자동 수확·다시 심기
    s = GameEngine.upgrade(GameEngine.upgrade(s, coop), coop); // Lv3: 자동 줍기
    final end = s.simTime.add(const Duration(minutes: 90));
    final whole = GameEngine.advance(s, end).$1;
    var split = s;
    for (final m in const [1, 7, 13, 29, 40]) {
      split = GameEngine.advance(split, split.simTime.add(Duration(minutes: m))).$1;
    }
    expect(jsonEncode(split.toJson()), jsonEncode(whole.toJson()));
  });
}
