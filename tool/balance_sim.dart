// 명령줄 도구라 결과를 표준 출력으로 낸다.
// ignore_for_file: avoid_print

// 밸런스 시뮬레이션(5단계 준비). 단순한 욕심쟁이 봇이 정해진 접속 일정대로 7일을 플레이하고
// 레벨업 시각과 하루 끝 상태를 찍는다. 실행: dart run tool/balance_sim.dart
//
// Input: 없음(봇 정책과 접속 일정은 아래 상수).
// Output: 표준 출력에 레벨업 표, 하루 끝 요약, 접속마다 "할 게 없던" 확인 비율.
// 핵심 로직: 매 확인 때 GameEngine 행동을 정해진 순서로 되는 만큼 반복한다.
//   거두기 → 주문 → 공방 → 팔기(주문·공방 재료는 남김) → 사료 → 심기 → 새끼 → 짓기 → 넓히기 → 올리기.
// 왜 이렇게 짰나: 사람 플레이를 흉내 내려는 게 아니라, 같은 정책으로 수치만 바꿔 돌려 비교하려는 것이다.
//   그래서 정책은 단순하게 두고(출하·꾸미기·주문 넘기기는 하지 않음), 결과는 "이 봇 기준"으로만 읽는다.
import 'package:my_farm/game/defs.dart';
import 'package:my_farm/game/engine.dart';
import 'package:my_farm/game/lots.dart';
import 'package:my_farm/game/state.dart';

/// 하루 접속 일정: (시작 시각 분, 접속 길이 분). 나머지 시간은 앱을 닫아 둔다.
/// 기본은 하루 네 번, `casual` 인자를 주면 저녁 한 번만 접속한다.
const busy = [(8 * 60, 20), (12 * 60 + 30, 15), (18 * 60 + 30, 30), (22 * 60, 15)];
const casual = [(20 * 60, 20)];
var sessions = busy;

/// 접속 중 확인 간격(분).
const checkEvery = 2;
const days = 7;

GameState? attempt(GameState Function() f) {
  try {
    return f();
  } on GameException {
    return null;
  }
}

/// 남겨 둘 물건: 지금 주문에 든 것과 지어 둔 공방의 재료 한 번 분량.
Map<ItemId, int> keep(GameState s) {
  final k = <ItemId, int>{};
  for (final slot in s.orders) {
    for (final e in slot.order?.items.entries ?? const <MapEntry<ItemId, int>>[]) {
      k[e.key] = (k[e.key] ?? 0) + e.value;
    }
  }
  for (final l in s.lots.values) {
    for (final e in l.def.recipe?.inputs.entries ?? const <MapEntry<ItemId, int>>[]) {
      k[e.key] = (k[e.key] ?? 0) + e.value;
    }
  }
  return k;
}

/// [horizon]분 안에 다시 볼 때 가장 이득인 작물(분당 순이익).
CropDef? bestCrop(GameState s, LotId lot, int horizon) {
  CropDef? best;
  var bestScore = -1.0;
  for (final c in GameEngine.cropsFor(s, lot)) {
    if (c.unlockLevel > s.level || c.seedCost > s.coins || c.waterL > s.water) continue;
    final value = GameEngine.baseYield(c, s.yieldBonus(lot)) * GameDefs.itemPrice[c.item]! - c.seedCost;
    final score = value / (c.growMinutes > horizon ? c.growMinutes : horizon);
    if (score > bestScore) {
      bestScore = score;
      best = c;
    }
  }
  return best;
}

/// 빈 땅에 지을 것: 아직 없는 종류(해금 순)를 먼저, 그다음 밭.
BuildingId? nextBuilding(GameState s) {
  final have = s.lots.values.map((l) => l.building).toSet();
  final candidates = GameDefs.buildings.values.where((d) => !d.core && !d.decor && d.unlockLevel <= s.level).toList()
    ..sort((a, b) => a.unlockLevel.compareTo(b.unlockLevel));
  for (final d in candidates) {
    if (!have.contains(d.id) && d.cost <= s.coins) return d.id;
  }
  return GameDefs.buildings[BuildingId.field]!.cost <= s.coins ? BuildingId.field : null;
}

/// 한 번 확인할 때 되는 행동을 모두 한다. 무언가 했으면 true.
(GameState, bool) check(GameState s, int horizon) {
  var acted = false;
  bool step(GameState? next) {
    if (next == null) return false;
    s = next;
    acted = true;
    return true;
  }

  for (final lot in s.builtLots) {
    final l = s.lots[lot]!;
    if (l.field?.ready ?? false) step(attempt(() => GameEngine.harvest(s, lot)));
    if (l.def.species != null) step(attempt(() => GameEngine.collect(s, lot).$1));
    if (l.job?.done ?? false) step(attempt(() => GameEngine.collectCraft(s, lot)));
  }
  for (var i = 0; i < s.orders.length; i++) {
    step(attempt(() => GameEngine.deliverOrder(s, i)));
  }
  for (final lot in s.builtLots) {
    if (s.lots[lot]!.def.recipe != null) step(attempt(() => GameEngine.startCraft(s, lot)));
  }
  final k = keep(s);
  for (final e in [...s.barn.entries]) {
    if (e.key == ItemId.corn && s.feed < s.feedCapacity * 0.6) {
      step(attempt(() => GameEngine.cornToFeed(s, e.value)));
      continue;
    }
    final extra = e.value - (k[e.key] ?? 0);
    if (extra > 0) step(attempt(() => GameEngine.sell(s, e.key, extra)));
  }
  if (s.animals.isNotEmpty) {
    while (s.feed < s.feedCapacity * 0.3 && step(attempt(() => GameEngine.buyFeed(s)))) {}
  }
  for (final lot in s.builtLots) {
    final f = s.lots[lot]!.field;
    if (f == null || !f.empty) continue;
    final crop = bestCrop(s, lot, horizon);
    if (crop != null) step(attempt(() => GameEngine.plant(s, lot, crop.id)));
  }
  for (final lot in s.builtLots) {
    while (s.lots[lot]!.def.species != null && step(attempt(() => GameEngine.buyAnimal(s, lot)))) {}
  }
  for (final lot in s.emptyLots) {
    final b = nextBuilding(s);
    if (b != null) step(attempt(() => GameEngine.build(s, lot, b)));
  }
  if (s.emptyLots.isEmpty && s.expansionsLeft > 0) {
    final target = LotId.all.where(s.touchesOwned).firstOrNull;
    if (target != null) step(attempt(() => GameEngine.clearLand(s, target)));
  }
  // 올리기는 남는 돈으로만: 가장 싼 것부터, 올린 뒤에도 50코인은 남게.
  final ups = [
    for (final lot in s.builtLots)
      if (s.lots[lot]!.def.upgradeCosts.isNotEmpty && s.lots[lot]!.level < s.lots[lot]!.def.maxLevel) lot,
  ]..sort((a, b) => cost(s, a).compareTo(cost(s, b)));
  for (final lot in ups) {
    if (s.coins - cost(s, lot) >= 50) step(attempt(() => GameEngine.upgrade(s, lot)));
  }
  return (s, acted);
}

int cost(GameState s, LotId lot) => s.lots[lot]!.def.upgradeCosts[s.lots[lot]!.level - 1];

String hm(int minutes) =>
    '${minutes ~/ 1440 + 1}일째 ${(minutes % 1440 ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

void main(List<String> args) {
  if (args.contains('casual')) sessions = casual;
  final start = DateTime.utc(2026, 10, 6); // 0일 00:00. 날씨는 날짜·시각으로 정해지므로 고정한다.
  var s = GameEngine.newGame(start.add(Duration(minutes: sessions.first.$1)), farmName: 'sim');
  var level = s.level;
  var activeMinutes = 0;
  print(
    '정책: $checkEvery분마다 확인, 접속 ${sessions.map((x) => '${x.$1 ~/ 60}:${(x.$1 % 60).toString().padLeft(2, '0')}(${x.$2}분)').join(' · ')}',
  );
  print('\n| 레벨 | 도달 시각 | 접속한 시간 누계 | 코인 |');
  print('| --- | --- | --- | --- |');
  final daily = <String>[];
  for (var day = 0; day < days; day++) {
    for (var i = 0; i < sessions.length; i++) {
      final (begin, length) = sessions[i];
      final nextGap = i + 1 < sessions.length
          ? sessions[i + 1].$1 - (begin + length)
          : 1440 - (begin + length) + sessions.first.$1;
      var idleChecks = 0;
      var checks = 0;
      for (var m = 0; m <= length; m += checkEvery) {
        final now = start.add(Duration(minutes: day * 1440 + begin + m));
        s = GameEngine.advance(s, now).$1;
        final last = m + checkEvery > length;
        final (next, acted) = check(s, last ? nextGap : checkEvery);
        s = next;
        checks++;
        if (!acted) idleChecks++;
        if (m > 0) activeMinutes += checkEvery;
        while (s.level > level) {
          level++;
          print('| $level | ${hm(day * 1440 + begin + m)} | $activeMinutes분 | ${s.coins} |');
        }
      }
      if (idleChecks * 2 > checks) {
        daily.add('  - ${day + 1}일째 ${begin ~/ 60}시 접속: 확인 $checks번 중 $idleChecks번은 할 게 없었음');
      }
    }
    final built =
        s.lots.values
            .where((l) => !l.def.core)
            .map((l) => '${l.building.name}${l.level > 1 ? ' Lv${l.level}' : ''}')
            .toList()
          ..sort();
    daily.add(
      '${day + 1}일째 끝: 레벨 ${s.level}(경험치 ${s.xp}), 코인 ${s.coins}, 땅 ${s.owned.length}칸, 동물 ${s.animals.length}, '
      '농가 Lv${s.farmhouseLevel}·창고 Lv${s.storehouseLevel}, 건물: ${built.join(', ')}',
    );
  }
  print('\n하루 끝 요약(할 게 없던 접속은 확인의 절반 넘게 빈손인 경우만):');
  daily.forEach(print);
}
