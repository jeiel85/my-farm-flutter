import 'defs.dart';
import 'state.dart';
import 'zone.dart';

enum TodoKind { harvest, collect, barnFull, feedEmpty, feedLow, plant, unlock }

/// 지금 할 수 있는(또는 해야 하는) 일 하나. 문구는 화면에서 만든다.
class GameTodo {
  const GameTodo(this.kind, {this.zone, this.species, this.count = 0});

  final TodoKind kind;
  final ZoneId? zone;
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
  for (final zone in GameDefs.plotZones) {
    if (s.fields[zone]?.ready ?? false) out.add(GameTodo(TodoKind.harvest, zone: zone));
  }
  for (final species in Species.values) {
    final stored = s.animals.where((a) => a.species == species).fold(0, (n, a) => n + a.stored);
    if (stored > 0) out.add(GameTodo(TodoKind.collect, species: species, count: stored));
  }
  for (final zone in GameDefs.plotZones) {
    if (s.unlocked.contains(zone) && (s.fields[zone]?.empty ?? true)) out.add(GameTodo(TodoKind.plant, zone: zone));
  }
  for (final e in GameDefs.zones.entries) {
    if (!s.unlocked.contains(e.key) && s.level >= e.value.unlockLevel && s.coins >= e.value.unlockCost) {
      out.add(GameTodo(TodoKind.unlock, zone: e.key));
    }
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
