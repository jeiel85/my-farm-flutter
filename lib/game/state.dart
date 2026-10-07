import 'zone.dart';
import 'defs.dart';

T _enum<T extends Enum>(List<T> values, Object? name) =>
    values.asNameMap()[name] ?? (throw FormatException('Unknown ${T.toString()}', name));

/// 작물 구역 한 곳의 상태.
class FieldState {
  const FieldState({
    this.crop,
    this.minutesLeft = 0,
    this.totalMinutes = 0,
    this.ready = false,
    this.waitingWater = false,
  });

  /// 심은 작물. 비어 있으면 null.
  final CropId? crop;

  /// 다 자랄 때까지 남은 분.
  final int minutesLeft;

  /// 이번 회차(심은 뒤 또는 사과나무의 다음 열매까지) 전체 분. 성장 단계를 그릴 때 쓴다.
  final int totalMinutes;

  /// 다 자라 수확을 기다린다.
  final bool ready;

  /// 계속 열리는 작물(사과)이 다음 회차에 쓸 물을 기다린다.
  final bool waitingWater;

  bool get empty => crop == null;

  FieldState copyWith({CropId? crop, int? minutesLeft, int? totalMinutes, bool? ready, bool? waitingWater}) =>
      FieldState(
        crop: crop ?? this.crop,
        minutesLeft: minutesLeft ?? this.minutesLeft,
        totalMinutes: totalMinutes ?? this.totalMinutes,
        ready: ready ?? this.ready,
        waitingWater: waitingWater ?? this.waitingWater,
      );

  static const emptyField = FieldState();

  Map<String, Object?> toJson() => {
    'crop': crop?.name,
    'minutesLeft': minutesLeft,
    'totalMinutes': totalMinutes,
    'ready': ready,
    'waitingWater': waitingWater,
  };

  factory FieldState.fromJson(Map<String, Object?> j) => FieldState(
    crop: j['crop'] == null ? null : _enum(CropId.values, j['crop']),
    minutesLeft: j['minutesLeft'] as int,
    totalMinutes: j['totalMinutes'] as int,
    ready: j['ready'] as bool,
    waitingWater: j['waitingWater'] as bool? ?? false,
  );
}

class GameAnimal {
  const GameAnimal({
    required this.id,
    required this.species,
    this.ageMinutes = 0,
    this.stored = 0,
    this.produceProgress = 0,
  });

  final String id;
  final Species species;

  /// 사료를 먹으며 자란 분. 성체까지 자란 뒤로는 늘지 않는다.
  final int ageMinutes;

  /// 우리에 쌓인 생산물 개수.
  final int stored;

  /// 다음 생산물까지 진행한 분.
  final int produceProgress;

  AnimalDef get def => GameDefs.animals[species]!;
  bool get adult => ageMinutes >= def.growMinutes;

  GameAnimal copyWith({int? ageMinutes, int? stored, int? produceProgress}) => GameAnimal(
    id: id,
    species: species,
    ageMinutes: ageMinutes ?? this.ageMinutes,
    stored: stored ?? this.stored,
    produceProgress: produceProgress ?? this.produceProgress,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'species': species.name,
    'ageMinutes': ageMinutes,
    'stored': stored,
    'produceProgress': produceProgress,
  };

  factory GameAnimal.fromJson(Map<String, Object?> j) => GameAnimal(
    id: j['id'] as String,
    species: _enum(Species.values, j['species']),
    ageMinutes: j['ageMinutes'] as int,
    stored: j['stored'] as int,
    produceProgress: j['produceProgress'] as int,
  );
}

enum LogKind { sale, slaughter, seed, animal, feed, unlock }

/// 수입·지출 기록 한 건(기록 탭 차트용). [amount]는 수입이면 양수, 지출이면 음수.
class GameLogEntry {
  const GameLogEntry({required this.at, required this.kind, required this.amount, required this.subject});

  final DateTime at;
  final LogKind kind;
  final int amount;

  /// 무엇을 사고팔았는지(ItemId·CropId·Species 이름 등). 문구는 화면에서 만든다.
  final String subject;

  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'kind': kind.name,
    'amount': amount,
    'subject': subject,
  };

  factory GameLogEntry.fromJson(Map<String, Object?> j) => GameLogEntry(
    at: DateTime.parse(j['at'] as String).toLocal(),
    kind: _enum(LogKind.values, j['kind']),
    amount: j['amount'] as int,
    subject: j['subject'] as String,
  );
}

/// 게임 전체 상태. JSON 하나로 저장한다(저장 형식 v5).
class GameState {
  const GameState({
    required this.farmName,
    required this.simTime,
    required this.coins,
    required this.xp,
    required this.barn,
    required this.feedUnits,
    required this.water,
    required this.unlocked,
    required this.fields,
    required this.animals,
    required this.breedProgress,
    required this.nextAnimalId,
    required this.log,
  });

  static const schemaVersion = 5;

  /// 기록은 최근 이만큼만 남긴다.
  static const maxLog = 400;

  final String farmName;

  /// 마지막으로 계산한 시각(분 경계). 이 시각까지의 일이 상태에 반영되어 있다.
  final DateTime simTime;
  final int coins;
  final int xp;
  final Map<ItemId, int> barn;

  /// 사료(1/60 단위). 화면에는 [feed]로 보인다.
  final int feedUnits;
  final int water;
  final Set<ZoneId> unlocked;
  final Map<ZoneId, FieldState> fields;
  final List<GameAnimal> animals;

  /// 종별 번식 진행(분).
  final Map<Species, int> breedProgress;
  final int nextAnimalId;
  final List<GameLogEntry> log;

  int get level => GameDefs.levelForXp(xp);
  int get barnUsed => barn.values.fold(0, (s, n) => s + n);
  int get barnFree => GameDefs.barnCapacity - barnUsed;
  double get feed => feedUnits / GameDefs.feedUnit;

  /// 지금 있는 동물이 모두 먹는다고 칠 때 시간당 사료. 생산물이 가득 찬 성체는 실제로는
  /// 먹지 않으므로, 사료가 가장 빨리 줄어드는 경우의 값이다.
  int get feedPerHourAll => animals.fold(0, (sum, a) => sum + (a.adult ? a.def.feedPerHour : a.def.feedPerHour ~/ 2));

  int countOf(ItemId item) => barn[item] ?? 0;

  GameState copyWith({
    DateTime? simTime,
    int? coins,
    int? xp,
    Map<ItemId, int>? barn,
    int? feedUnits,
    int? water,
    Set<ZoneId>? unlocked,
    Map<ZoneId, FieldState>? fields,
    List<GameAnimal>? animals,
    Map<Species, int>? breedProgress,
    int? nextAnimalId,
    List<GameLogEntry>? log,
    String? farmName,
  }) => GameState(
    farmName: farmName ?? this.farmName,
    simTime: simTime ?? this.simTime,
    coins: coins ?? this.coins,
    xp: xp ?? this.xp,
    barn: barn ?? this.barn,
    feedUnits: feedUnits ?? this.feedUnits,
    water: water ?? this.water,
    unlocked: unlocked ?? this.unlocked,
    fields: fields ?? this.fields,
    animals: animals ?? this.animals,
    breedProgress: breedProgress ?? this.breedProgress,
    nextAnimalId: nextAnimalId ?? this.nextAnimalId,
    log: log ?? this.log,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'farmName': farmName,
    // 시간대 없는 현지 시각으로 적으면 앱을 닫은 동안 시간대를 바꿨을 때 다른 순간으로 읽힌다. UTC로 적고 현지 시각으로 읽는다.
    'simTime': simTime.toUtc().toIso8601String(),
    'coins': coins,
    'xp': xp,
    'barn': {for (final e in barn.entries) e.key.name: e.value},
    'feedUnits': feedUnits,
    'water': water,
    'unlocked': [for (final z in unlocked) z.name],
    'fields': {for (final e in fields.entries) e.key.name: e.value.toJson()},
    'animals': [for (final a in animals) a.toJson()],
    'breedProgress': {for (final e in breedProgress.entries) e.key.name: e.value},
    'nextAnimalId': nextAnimalId,
    'log': [for (final l in log) l.toJson()],
  };

  /// 다른 버전은 읽지 않는다. 관리 앱 시절(v1~v4) 저장본은 [GameStore]가 따로 보관하고 새 게임을 만든다.
  /// 전환 방법·실패 시 동작·되돌리기는 docs/save-format-v5.md.
  factory GameState.fromJson(Map<String, Object?> j) {
    final version = j['schemaVersion'];
    if (version != schemaVersion) throw UnsupportedGameSchema(version);
    Map<String, Object?> map(String key) => (j[key] as Map).cast<String, Object?>();
    return GameState(
      farmName: j['farmName'] as String,
      simTime: DateTime.parse(j['simTime'] as String).toLocal(),
      coins: j['coins'] as int,
      xp: j['xp'] as int,
      barn: {for (final e in map('barn').entries) _enum(ItemId.values, e.key): e.value as int},
      feedUnits: j['feedUnits'] as int,
      water: j['water'] as int,
      unlocked: {for (final z in j['unlocked'] as List) _enum(ZoneId.values, z)},
      fields: {
        for (final e in map('fields').entries)
          _enum(ZoneId.values, e.key): FieldState.fromJson((e.value as Map).cast<String, Object?>()),
      },
      animals: [for (final a in j['animals'] as List) GameAnimal.fromJson((a as Map).cast<String, Object?>())],
      breedProgress: {for (final e in map('breedProgress').entries) _enum(Species.values, e.key): e.value as int},
      nextAnimalId: j['nextAnimalId'] as int,
      log: [for (final l in j['log'] as List) GameLogEntry.fromJson((l as Map).cast<String, Object?>())],
    );
  }
}

class UnsupportedGameSchema implements Exception {
  const UnsupportedGameSchema(this.version);
  final Object? version;

  /// 관리 앱 시절(v1~v4) 저장본인지.
  bool get legacy => version is int && (version as int) >= 1 && (version as int) < GameState.schemaVersion;

  bool get newer => version is int && (version as int) > GameState.schemaVersion;

  @override
  String toString() => 'UnsupportedGameSchema($version)';
}
