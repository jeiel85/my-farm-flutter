/// 게임 정의 표. 수치는 docs/game-design.md(수치표 v1)와 같아야 한다.
library;

import '../data/models.dart' show ZoneId;

/// 창고에 들어가는 물건.
enum ItemId { lettuce, carrot, tomato, corn, strawberry, apple, egg, goatMilk, wool, milk }

enum CropId { lettuce, carrot, tomato, corn, strawberry, apple }

enum Species { chicken, goat, sheep, cow }

/// 작물을 심는 구역 종류.
enum PlotKind { field, greenhouse, orchard }

class CropDef {
  const CropDef({
    required this.id,
    required this.item,
    required this.growMinutes,
    required this.seedCost,
    required this.waterL,
    required this.yieldCount,
    required this.xp,
    required this.unlockLevel,
    required this.plot,
    this.regrowMinutes,
  });

  final CropId id;
  final ItemId item;
  final int growMinutes;
  final int seedCost;
  final int waterL;
  final int yieldCount;
  final int xp;
  final int unlockLevel;
  final PlotKind plot;

  /// 한 번 심으면 계속 열리는 작물(사과나무)의 다음 회차까지 시간. 없으면 수확 후 밭이 빈다.
  final int? regrowMinutes;

  bool get perennial => regrowMinutes != null;
}

class AnimalDef {
  const AnimalDef({
    required this.species,
    required this.buyCost,
    required this.growMinutes,
    required this.feedPerHour,
    required this.product,
    required this.produceEveryMinutes,
    required this.storeCap,
    required this.sellPrice,
    required this.collectXp,
    required this.sellXp,
    required this.breedEveryMinutes,
    required this.unlockLevel,
  });

  final Species species;
  final int buyCost;
  final int growMinutes;

  /// 성체가 생산하는 동안 먹는 사료(시간당). 자라는 동안은 절반을 먹는다.
  final int feedPerHour;
  final ItemId product;
  final int produceEveryMinutes;
  final int storeCap;

  /// 출하(정육) 값.
  final int sellPrice;
  final int collectXp;
  final int sellXp;
  final int breedEveryMinutes;
  final int unlockLevel;
}

class ZoneDef {
  const ZoneDef({required this.zone, required this.unlockLevel, required this.unlockCost, this.plot});

  final ZoneId zone;
  final int unlockLevel;
  final int unlockCost;

  /// 작물을 심는 구역이면 그 종류.
  final PlotKind? plot;
}

abstract final class GameDefs {
  /// 사료는 1/60 단위 정수로 다룬다(시간당 사료를 분 단위로 나눠도 정수가 되게).
  static const feedUnit = 60;

  static const startCoins = 100;
  static const startFeed = 60;
  static const startWater = 300;
  static const barnCapacity = 100;
  static const feedCapacity = 200;
  static const waterCapacity = 500;
  static const waterRefillPerMinute = 5;
  static const penCapacity = 6;
  static const offlineCapMinutes = 4 * 60;

  /// 옥수수 1개를 사료로 바꾸면 얻는 사료.
  static const feedPerCorn = 3;

  /// 사료 묶음 구입.
  static const feedPackAmount = 20;
  static const feedPackCost = 12;

  static const itemPrice = <ItemId, int>{
    ItemId.lettuce: 2,
    ItemId.carrot: 4,
    ItemId.tomato: 5,
    ItemId.corn: 4,
    ItemId.strawberry: 12,
    ItemId.apple: 15,
    ItemId.egg: 4,
    ItemId.goatMilk: 9,
    ItemId.wool: 35,
    ItemId.milk: 22,
  };

  static const crops = <CropId, CropDef>{
    CropId.lettuce: CropDef(
      id: CropId.lettuce,
      item: ItemId.lettuce,
      growMinutes: 2,
      seedCost: 4,
      waterL: 10,
      yieldCount: 5,
      xp: 1,
      unlockLevel: 1,
      plot: PlotKind.field,
    ),
    CropId.carrot: CropDef(
      id: CropId.carrot,
      item: ItemId.carrot,
      growMinutes: 6,
      seedCost: 10,
      waterL: 20,
      yieldCount: 6,
      xp: 2,
      unlockLevel: 2,
      plot: PlotKind.field,
    ),
    CropId.tomato: CropDef(
      id: CropId.tomato,
      item: ItemId.tomato,
      growMinutes: 12,
      seedCost: 18,
      waterL: 40,
      yieldCount: 8,
      xp: 4,
      unlockLevel: 3,
      plot: PlotKind.field,
    ),
    CropId.corn: CropDef(
      id: CropId.corn,
      item: ItemId.corn,
      growMinutes: 25,
      seedCost: 20,
      waterL: 60,
      yieldCount: 10,
      xp: 5,
      unlockLevel: 4,
      plot: PlotKind.field,
    ),
    CropId.strawberry: CropDef(
      id: CropId.strawberry,
      item: ItemId.strawberry,
      growMinutes: 60,
      seedCost: 50,
      waterL: 80,
      yieldCount: 12,
      xp: 10,
      unlockLevel: 6,
      plot: PlotKind.greenhouse,
    ),
    CropId.apple: CropDef(
      id: CropId.apple,
      item: ItemId.apple,
      growMinutes: 180,
      seedCost: 300,
      waterL: 60,
      yieldCount: 15,
      xp: 15,
      unlockLevel: 8,
      plot: PlotKind.orchard,
      regrowMinutes: 90,
    ),
  };

  static const animals = <Species, AnimalDef>{
    Species.chicken: AnimalDef(
      species: Species.chicken,
      buyCost: 30,
      growMinutes: 10,
      feedPerHour: 2,
      product: ItemId.egg,
      produceEveryMinutes: 6,
      storeCap: 5,
      sellPrice: 45,
      collectXp: 1,
      sellXp: 2,
      breedEveryMinutes: 40,
      unlockLevel: 1,
    ),
    Species.goat: AnimalDef(
      species: Species.goat,
      buyCost: 80,
      growMinutes: 30,
      feedPerHour: 4,
      product: ItemId.goatMilk,
      produceEveryMinutes: 15,
      storeCap: 4,
      sellPrice: 140,
      collectXp: 1,
      sellXp: 4,
      breedEveryMinutes: 120,
      unlockLevel: 3,
    ),
    Species.sheep: AnimalDef(
      species: Species.sheep,
      buyCost: 120,
      growMinutes: 60,
      feedPerHour: 4,
      product: ItemId.wool,
      produceEveryMinutes: 45,
      storeCap: 2,
      sellPrice: 200,
      collectXp: 3,
      sellXp: 6,
      breedEveryMinutes: 180,
      unlockLevel: 5,
    ),
    Species.cow: AnimalDef(
      species: Species.cow,
      buyCost: 250,
      growMinutes: 180,
      feedPerHour: 8,
      product: ItemId.milk,
      produceEveryMinutes: 30,
      storeCap: 4,
      sellPrice: 520,
      collectXp: 2,
      sellXp: 10,
      breedEveryMinutes: 480,
      unlockLevel: 7,
    ),
  };

  /// 구역을 여는 조건. 표에 없는 구역(농가·가축 우리·물탱크·창고)은 처음부터 열려 있다.
  static const zones = <ZoneId, ZoneDef>{
    ZoneId.vegetable: ZoneDef(zone: ZoneId.vegetable, unlockLevel: 1, unlockCost: 0, plot: PlotKind.field),
    ZoneId.tomato: ZoneDef(zone: ZoneId.tomato, unlockLevel: 2, unlockCost: 50, plot: PlotKind.field),
    ZoneId.corn: ZoneDef(zone: ZoneId.corn, unlockLevel: 3, unlockCost: 150, plot: PlotKind.field),
    ZoneId.greenhouse: ZoneDef(zone: ZoneId.greenhouse, unlockLevel: 6, unlockCost: 600, plot: PlotKind.greenhouse),
    ZoneId.orchard: ZoneDef(zone: ZoneId.orchard, unlockLevel: 8, unlockCost: 1500, plot: PlotKind.orchard),
  };

  /// 작물을 심을 수 있는 구역.
  static Iterable<ZoneId> get plotZones => zones.keys;

  /// 레벨 경계(누적 경험치). 인덱스 i는 (i+2)레벨이 되는 경험치. 10레벨 이후는 레벨마다 +500.
  static const levelThresholds = [15, 45, 100, 190, 330, 530, 800, 1150, 1600];

  static int levelForXp(int xp) {
    var level = 1;
    for (final t in levelThresholds) {
      if (xp >= t) level++;
    }
    if (xp >= levelThresholds.last) level += (xp - levelThresholds.last) ~/ 500;
    return level;
  }

  /// [level]이 되는 데 필요한 누적 경험치(1레벨은 0).
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    if (level - 2 < levelThresholds.length) return levelThresholds[level - 2];
    return levelThresholds.last + (level - 1 - levelThresholds.length) * 500;
  }
}
