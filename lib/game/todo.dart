import 'defs.dart';
import 'lots.dart';
import 'state.dart';

enum TodoKind { harvest, collect, craftDone, order, barnFull, feedEmpty, feedLow, plant, craftIdle, build, expand }

/// 지금 할 수 있는(또는 해야 하는) 일 하나. 문구는 화면에서 만든다.
class GameTodo {
  const GameTodo(this.kind, {this.lot, this.species, this.count = 0});

  final TodoKind kind;
  final LotId? lot;
  final Species? species;
  final int count;
}

/// 사료가 이만큼보다 적으면 미리 알린다.
const feedLowThreshold = 10;

/// 홈 "할 수 있는 일" 목록. 급한 것부터.
List<GameTodo> todosFor(GameState s) {
  final out = <GameTodo>[];
  final hasAnimals = s.animals.isNotEmpty;
  if (hasAnimals && s.feedUnits == 0) {
    out.add(const GameTodo(TodoKind.feedEmpty));
  } else if (hasAnimals && s.feed < feedLowThreshold) {
    out.add(const GameTodo(TodoKind.feedLow));
  }
  if (s.barnFree == 0) out.add(const GameTodo(TodoKind.barnFull));
  final built = s.builtLots;
  for (final id in built) {
    if (s.lots[id]!.field?.ready ?? false) out.add(GameTodo(TodoKind.harvest, lot: id));
  }
  for (final id in built) {
    final species = s.lots[id]!.def.species;
    if (species == null) continue;
    final stored = s.animalsIn(id).fold(0, (n, a) => n + a.stored);
    if (stored > 0) out.add(GameTodo(TodoKind.collect, lot: id, species: species, count: stored));
  }
  for (final id in built) {
    if (s.lots[id]!.job?.done ?? false) out.add(GameTodo(TodoKind.craftDone, lot: id));
  }
  // 지금 가진 물건으로 보낼 수 있는 주문([GameTodo.count]는 게시판 칸 번호).
  for (final (i, slot) in s.orders.indexed) {
    final order = slot.order;
    if (order != null && order.items.entries.every((e) => s.countOf(e.key) >= e.value)) {
      out.add(GameTodo(TodoKind.order, count: i));
    }
  }
  for (final id in built) {
    if (s.lots[id]!.field?.empty ?? false) out.add(GameTodo(TodoKind.plant, lot: id));
  }
  // 재료가 모인 쉬는 공방.
  for (final id in built) {
    final lot = s.lots[id]!;
    final recipe = lot.def.recipe;
    if (recipe == null || lot.job != null) continue;
    if (recipe.inputs.entries.every((e) => s.countOf(e.key) >= e.value)) out.add(GameTodo(TodoKind.craftIdle, lot: id));
  }
  // 빈 땅이 있고 지을 수 있는 건물이 하나라도 있으면 알린다(가장 싼 건물을 지을 코인이 있을 때).
  final empty = s.emptyLots;
  final cheapest = GameDefs.buildings.values
      .where((b) => !b.core && b.unlockLevel <= s.level)
      .fold<int?>(null, (m, b) => m == null || b.cost < m ? b.cost : m);
  if (empty.isNotEmpty && cheapest != null && s.coins >= cheapest) {
    out.add(GameTodo(TodoKind.build, lot: empty.first));
  }
  // 넓힐 수 있는 땅(레벨 한도·코인이 되고 가진 땅에 붙은 칸)이 있으면 알린다.
  final cost = s.nextExpansionCost;
  if (s.expansionsLeft > 0 && cost != null && s.coins >= cost) {
    final edge = LotId.all.where(s.touchesOwned).firstOrNull;
    if (edge != null) out.add(GameTodo(TodoKind.expand, lot: edge, count: cost));
  }
  return out;
}

/// 화면 표시용 작물 성장 단계: 0 싹 · 1 잎 · 2 거의 다 자람 · 3 다 자람(빈 밭이면 null).
int? cropStage(FieldState f, {double extraMinutes = 0}) {
  final crop = f.crop;
  if (crop == null) return null;
  if (f.ready) return 3;
  final def = GameDefs.crops[crop]!;
  final total = f.waitingWater || def.perennial && f.minutesLeft <= (def.regrowMinutes ?? 0)
      ? (def.regrowMinutes ?? def.growMinutes)
      : def.growMinutes;
  final done = (total - f.minutesLeft + extraMinutes).clamp(0, total) / total;
  if (f.waitingWater) return 1;
  if (done < 0.3) return 0;
  if (done < 0.75) return 1;
  return 2;
}
