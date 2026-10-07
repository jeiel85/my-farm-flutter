/// 게임 정의 표. 수치는 docs/game-design.md(수치표 v1)와 같아야 한다.
library;

import 'lots.dart';

/// 창고에 들어가는 물건.
enum ItemId { lettuce, carrot, tomato, corn, strawberry, apple, egg, goatMilk, wool, milk }

enum CropId { lettuce, carrot, tomato, corn, strawberry, apple }

enum Species { chicken, goat, sheep, cow }

/// 작물을 심는 건물 종류.
enum PlotKind { field, greenhouse, orchard }

/// 부지에 짓는 건물. docs/farm-lots-design.md §4. 이름은 저장 형식(v6)에 그대로 들어가므로 바꾸지 않는다.
enum BuildingId { farmhouse, storehouse, field, coop, goatPen, sheepPen, cowBarn, greenhouse, orchard }

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

class BuildingDef {
  const BuildingDef({
    required this.id,
    required this.cost,
    required this.unlockLevel,
    this.plot,
    this.species,
    this.capacity = const [],
    this.upgradeCosts = const [],
    this.core = false,
  });

  final BuildingId id;

  /// 짓는 비용(핵심 건물은 0).
  final int cost;
  final int unlockLevel;

  /// 작물을 심는 건물이면 그 종류.
  final PlotKind? plot;

  /// 가축 우리면 기르는 종.
  final Species? species;

  /// 가축 우리의 레벨별 최대 마릿수(Lv1부터).
  final List<int> capacity;

  /// Lv2·Lv3으로 올리는 비용(올릴 수 없는 건물은 비어 있다).
  final List<int> upgradeCosts;

  /// 처음부터 있고 철거할 수 없는 건물(농가·창고).
  final bool core;

  int get maxLevel => 1 + upgradeCosts.length;
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

  static const buildings = <BuildingId, BuildingDef>{
    BuildingId.farmhouse: BuildingDef(
      id: BuildingId.farmhouse,
      cost: 0,
      unlockLevel: 1,
      core: true,
      upgradeCosts: [300, 1000],
    ),
    BuildingId.storehouse: BuildingDef(
      id: BuildingId.storehouse,
      cost: 0,
      unlockLevel: 1,
      core: true,
      upgradeCosts: [200, 700],
    ),
    BuildingId.field: BuildingDef(
      id: BuildingId.field,
      cost: 25,
      unlockLevel: 1,
      plot: PlotKind.field,
      upgradeCosts: [120, 500],
    ),
    BuildingId.coop: BuildingDef(
      id: BuildingId.coop,
      cost: 40,
      unlockLevel: 1,
      species: Species.chicken,
      capacity: [4, 6, 8],
      upgradeCosts: [150, 500],
    ),
    BuildingId.goatPen: BuildingDef(
      id: BuildingId.goatPen,
      cost: 120,
      unlockLevel: 3,
      species: Species.goat,
      capacity: [3, 5, 6],
      upgradeCosts: [300, 900],
    ),
    BuildingId.sheepPen: BuildingDef(
      id: BuildingId.sheepPen,
      cost: 200,
      unlockLevel: 5,
      species: Species.sheep,
      capacity: [3, 5, 6],
      upgradeCosts: [450, 1200],
    ),
    BuildingId.cowBarn: BuildingDef(
      id: BuildingId.cowBarn,
      cost: 400,
      unlockLevel: 7,
      species: Species.cow,
      capacity: [3, 5, 6],
      upgradeCosts: [800, 2000],
    ),
    BuildingId.greenhouse: BuildingDef(
      id: BuildingId.greenhouse,
      cost: 600,
      unlockLevel: 6,
      plot: PlotKind.greenhouse,
      upgradeCosts: [1200, 2500],
    ),
    BuildingId.orchard: BuildingDef(
      id: BuildingId.orchard,
      cost: 1500,
      unlockLevel: 8,
      plot: PlotKind.orchard,
      upgradeCosts: [2500, 4000],
    ),
  };

  /// 종을 기르는 우리.
  static BuildingId penFor(Species species) => buildings.values.firstWhere((b) => b.species == species).id;

  /// 처음 가진 땅(가운데 2열 × 위 3행)과 처음 지어진 건물.
  static const farmhouseLot = LotId(1, 0);
  static const storehouseLot = LotId(2, 0);
  static const startFieldLot = LotId(1, 1);
  static const startCoopLot = LotId(2, 1);
  static const startLots = [farmhouseLot, storehouseLot, startFieldLot, startCoopLot, LotId(1, 2), LotId(2, 2)];

  /// 몇 번째로 넓히는지에 따른 개간 비용.
  static const expansionCosts = [30, 50, 80, 120, 170, 230, 300, 380, 470, 580, 700, 850, 1000, 1200];

  /// 레벨 L에서 지금까지 넓힐 수 있는 칸 수: (L − 1) × 2, 최대 전부.
  static int expansionsAllowed(int level) => ((level - 1) * 2).clamp(0, expansionCosts.length);

  /// 핵심 건물 레벨별 값(Lv1부터). docs/farm-lots-design.md §4.
  static const offlineCapByLevel = [4 * 60, 6 * 60, 8 * 60];
  static const waterCapacityByLevel = [500, 800, 1200];
  static const waterRefillByLevel = [5, 7, 10];
  static const barnCapacityByLevel = [100, 160, 250];
  static const feedCapacityByLevel = [200, 300, 450];

  /// 작물 건물 Lv2부터 수확량 보너스(%).
  static const yieldBonusLv2 = 25;

  /// 작물 건물·우리가 저절로 돌아가는 레벨(자동 수확·다시 심기·자동 줍기). 창고는 이 레벨에서 자동 출하.
  static const autoLevel = 3;

  /// 철거하면 돌려받는 코인(짓기 비용의 절반).
  static int demolishRefund(BuildingId id) => buildings[id]!.cost ~/ 2;

  /// 레벨 경계(누적 경험치). 인덱스 i는 (i+2)레벨이 되는 경험치. 10레벨 이후는 레벨마다 +500.
  /// 초반은 몇 분 만에 오르고 갈수록 완만해지게, 레벨당 필요량이 대략 두 배씩 늘다가 1.4배 안팎으로 줄어든다.
  static const levelThresholds = [5, 15, 35, 75, 150, 280, 480, 780, 1200];

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
