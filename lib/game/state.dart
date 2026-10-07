import 'defs.dart';
import 'lots.dart';
import 'migrate_v5.dart';

T _enum<T extends Enum>(List<T> values, Object? name) =>
    values.asNameMap()[name] ?? (throw FormatException('Unknown ${T.toString()}', name));

/// 작물을 심는 건물(밭·온실·과수원) 한 곳의 상태.
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
    required this.home,
    this.ageMinutes = 0,
    this.stored = 0,
    this.produceProgress = 0,
  });

  final String id;
  final Species species;

  /// 사는 우리(부지).
  final LotId home;

  /// 사료를 먹으며 자란 분. 성체까지 자란 뒤로는 늘지 않는다.
  final int ageMinutes;

  /// 우리에 쌓인 생산물 개수.
  final int stored;

  /// 다음 생산물까지 진행한 분.
  final int produceProgress;

  AnimalDef get def => GameDefs.animals[species]!;
  bool get adult => ageMinutes >= def.growMinutes;

  GameAnimal copyWith({int? ageMinutes, int? stored, int? produceProgress, LotId? home}) => GameAnimal(
    id: id,
    species: species,
    home: home ?? this.home,
    ageMinutes: ageMinutes ?? this.ageMinutes,
    stored: stored ?? this.stored,
    produceProgress: produceProgress ?? this.produceProgress,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'species': species.name,
    'home': home.key,
    'ageMinutes': ageMinutes,
    'stored': stored,
    'produceProgress': produceProgress,
  };

  factory GameAnimal.fromJson(Map<String, Object?> j) => GameAnimal(
    id: j['id'] as String,
    species: _enum(Species.values, j['species']),
    home: LotId.parse(j['home'] as String),
    ageMinutes: j['ageMinutes'] as int,
    stored: j['stored'] as int,
    produceProgress: j['produceProgress'] as int,
  );
}

/// 기록 종류. [unlock]은 v5(정해진 구역을 열던 때) 기록이다.
enum LogKind { sale, slaughter, seed, animal, feed, unlock, build, expand, demolish, upgrade }

/// 수입·지출 기록 한 건(기록 탭 차트용). [amount]는 수입이면 양수, 지출이면 음수.
class GameLogEntry {
  const GameLogEntry({required this.at, required this.kind, required this.amount, required this.subject});

  final DateTime at;
  final LogKind kind;
  final int amount;

  /// 무엇을 사고팔았는지(ItemId·CropId·Species·BuildingId 이름 등). 문구는 화면에서 만든다.
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

/// 지은 건물 한 칸.
class Lot {
  const Lot(this.building, {this.level = 1, this.field});

  final BuildingId building;
  final int level;

  /// 작물 건물(밭·온실·과수원)의 작물 상태. 그 밖의 건물은 null.
  final FieldState? field;

  BuildingDef get def => GameDefs.buildings[building]!;

  Lot copyWith({int? level, FieldState? field}) =>
      Lot(building, level: level ?? this.level, field: field ?? this.field);

  Map<String, Object?> toJson() => {'building': building.name, 'level': level, 'field': ?field?.toJson()};

  factory Lot.fromJson(Map<String, Object?> j) => Lot(
    _enum(BuildingId.values, j['building']),
    level: j['level'] as int? ?? 1,
    field: j['field'] == null ? null : FieldState.fromJson((j['field'] as Map).cast<String, Object?>()),
  );
}

/// 게임 전체 상태. JSON 하나로 저장한다(저장 형식 v6, docs/farm-lots-design.md §9).
class GameState {
  const GameState({
    required this.farmName,
    required this.simTime,
    required this.coins,
    required this.xp,
    required this.barn,
    required this.feedUnits,
    required this.water,
    required this.owned,
    required this.lots,
    required this.expansions,
    required this.animals,
    required this.breedProgress,
    required this.nextAnimalId,
    required this.log,
  });

  static const schemaVersion = 6;

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

  /// 가진 땅. 그중 [lots]에 없는 칸은 빈 땅이다. 가지지 않은 칸은 장애물(덤불·돌 등)이 있다.
  final Set<LotId> owned;
  final Map<LotId, Lot> lots;

  /// 지금까지 넓힌(개간한) 칸 수. 다음 개간 비용과 레벨별 한도에 쓴다.
  final int expansions;
  final List<GameAnimal> animals;

  /// 우리별 번식 진행(분).
  final Map<LotId, int> breedProgress;
  final int nextAnimalId;
  final List<GameLogEntry> log;

  int get level => GameDefs.levelForXp(xp);
  int get barnUsed => barn.values.fold(0, (s, n) => s + n);
  int get barnFree => barnCapacity - barnUsed;

  int _level(LotId core) => lots[core]?.level ?? 1;

  /// 농가 레벨: 자리 비운 동안 계산하는 시간, 우물 용량·충전 속도.
  int get farmhouseLevel => _level(GameDefs.farmhouseLot);

  /// 창고 레벨: 창고·사료통 용량, Lv3 자동 출하.
  int get storehouseLevel => _level(GameDefs.storehouseLot);
  int get offlineCapMinutes => GameDefs.offlineCapByLevel[farmhouseLevel - 1];
  int get waterCapacity => GameDefs.waterCapacityByLevel[farmhouseLevel - 1];
  int get waterRefillPerMinute => GameDefs.waterRefillByLevel[farmhouseLevel - 1];
  int get barnCapacity => GameDefs.barnCapacityByLevel[storehouseLevel - 1];
  int get feedCapacity => GameDefs.feedCapacityByLevel[storehouseLevel - 1];

  /// 창고 Lv3: 자동으로 거둔 몫이 창고에 다 들어가지 않으면 그 자리에서 판다.
  bool get autoShip => storehouseLevel >= GameDefs.autoLevel;
  double get feed => feedUnits / GameDefs.feedUnit;

  /// 지금 있는 동물이 모두 먹는다고 칠 때 시간당 사료. 생산물이 가득 찬 성체는 실제로는
  /// 먹지 않으므로, 사료가 가장 빨리 줄어드는 경우의 값이다.
  int get feedPerHourAll => animals.fold(0, (sum, a) => sum + (a.adult ? a.def.feedPerHour : a.def.feedPerHour ~/ 2));

  int countOf(ItemId item) => barn[item] ?? 0;

  /// 지은 건물이 있는 칸(위에서 아래, 왼쪽에서 오른쪽 순서. 계산 순서를 늘 같게 한다).
  List<LotId> get builtLots => lots.keys.toList()..sort();

  /// 가졌지만 아무것도 짓지 않은 칸.
  List<LotId> get emptyLots => [
    for (final l in LotId.all)
      if (owned.contains(l) && !lots.containsKey(l)) l,
  ];

  List<GameAnimal> animalsIn(LotId pen) => [
    for (final a in animals)
      if (a.home == pen) a,
  ];

  /// 우리 [pen]의 최대 마릿수(우리가 아니면 0).
  int penCapacity(LotId pen) {
    final lot = lots[pen];
    if (lot == null || lot.def.species == null) return 0;
    final caps = lot.def.capacity;
    return caps[(lot.level - 1).clamp(0, caps.length - 1)];
  }

  /// 지금 넓힐 수 있는 자리인지(가지지 않았고 가진 땅에 붙어 있다). 레벨·코인은 따로 본다.
  bool touchesOwned(LotId lot) => lot.inLand && !owned.contains(lot) && lot.neighbors.any(owned.contains);

  /// 레벨 한도 안에서 더 넓힐 수 있는 칸 수.
  int get expansionsLeft => GameDefs.expansionsAllowed(level) - expansions;

  /// 다음 개간 비용(땅을 다 넓혔으면 null).
  int? get nextExpansionCost =>
      expansions < GameDefs.expansionCosts.length ? GameDefs.expansionCosts[expansions] : null;

  GameState copyWith({
    DateTime? simTime,
    int? coins,
    int? xp,
    Map<ItemId, int>? barn,
    int? feedUnits,
    int? water,
    Set<LotId>? owned,
    Map<LotId, Lot>? lots,
    int? expansions,
    List<GameAnimal>? animals,
    Map<LotId, int>? breedProgress,
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
    owned: owned ?? this.owned,
    lots: lots ?? this.lots,
    expansions: expansions ?? this.expansions,
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
    'owned': [for (final l in owned.toList()..sort()) l.key],
    'lots': {for (final l in builtLots) l.key: lots[l]!.toJson()},
    'expansions': expansions,
    'animals': [for (final a in animals) a.toJson()],
    'breedProgress': {for (final e in breedProgress.entries) e.key.key: e.value},
    'nextAnimalId': nextAnimalId,
    'log': [for (final l in log) l.toJson()],
  };

  /// v6을 읽는다. v5(정해진 구역 시절 개발판)는 부지로 옮긴다(migrate_v5.dart). 관리 앱 시절(v1~v4) 저장본은
  /// [GameStore]가 따로 보관하고 새 게임을 만든다. 전환 기록은 docs/save-format-v5.md, docs/farm-lots-design.md §9.
  factory GameState.fromJson(Map<String, Object?> j) {
    final version = j['schemaVersion'];
    if (version == 5) return migrateV5(j);
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
      owned: {for (final l in j['owned'] as List) LotId.parse(l as String)},
      lots: {
        for (final e in map('lots').entries) LotId.parse(e.key): Lot.fromJson((e.value as Map).cast<String, Object?>()),
      },
      expansions: j['expansions'] as int,
      animals: [for (final a in j['animals'] as List) GameAnimal.fromJson((a as Map).cast<String, Object?>())],
      breedProgress: {for (final e in map('breedProgress').entries) LotId.parse(e.key): e.value as int},
      nextAnimalId: j['nextAnimalId'] as int,
      log: [for (final l in j['log'] as List) GameLogEntry.fromJson((l as Map).cast<String, Object?>())],
    );
  }
}

class UnsupportedGameSchema implements Exception {
  const UnsupportedGameSchema(this.version);
  final Object? version;

  /// 관리 앱 시절(v1~v4) 저장본인지. v5(정해진 구역 시절 게임)는 옮겨 읽으므로 여기에 들지 않는다.
  bool get legacy => version is int && (version as int) >= 1 && (version as int) < 5;

  bool get newer => version is int && (version as int) > GameState.schemaVersion;

  @override
  String toString() => 'UnsupportedGameSchema($version)';
}
