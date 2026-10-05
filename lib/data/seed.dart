import 'dart:math';

import 'farm_state.dart';
import 'models.dart';

/// 처음 실행하거나 "예시 농장으로 초기화"를 누를 때 쓰는 예시 데이터.
/// 날짜는 모두 [now] 기준 상대값이라 언제 열어도 그럴듯한 상태가 된다.
FarmState buildDemoFarm(DateTime now) {
  final rng = Random(42);
  final today = DateTime(now.year, now.month, now.day);

  const cowNames = [
    '벨라',
    '데이지',
    '무스',
    '초코',
    '라떼',
    '구름',
    '보리',
    '콩이',
    '밤비',
    '누리',
    '단비',
    '해피',
    '모카',
    '두부',
    '솜이',
    '하루',
    '별이',
    '진주',
  ];
  const cowBreeds = ['홀스타인', '저지', '한우', '앵거스'];
  const henNames = [
    '꼬꼬',
    '삐약',
    '후추',
    '깨순',
    '노랑',
    '달님',
    '알콩',
    '달콩',
    '봄이',
    '여름',
    '가을',
    '겨울',
    '참깨',
    '들깨',
    '옥이',
    '복실',
    '토리',
    '보미',
    '나리',
    '미미',
  ];
  const henBreeds = ['로드아일랜드 레드', '레그혼', '오골계'];
  const sheepNames = ['양털이', '몽실', '포근', '솜사탕', '구르미', '눈송이'];
  const goatNames = ['깜순', '뿔이', '산들', '바위'];

  final animals = <Animal>[];
  void addHerd(AnimalKind kind, List<String> names, List<String> breeds, double baseWeight, int minHealth) {
    for (var i = 0; i < names.length; i++) {
      final ageDays = 240 + rng.nextInt(1600);
      animals.add(
        Animal(
          id: '${kind.name}-$i',
          kind: kind,
          tag: '${kind.tagPrefix}-${(i * 7 + 3).toString().padLeft(3, '0')}',
          name: names[i],
          breed: breeds[i % breeds.length],
          birthDate: today.subtract(Duration(days: ageDays)),
          health: minHealth + rng.nextInt(100 - minHealth),
          weightKg: double.parse((baseWeight * (0.8 + rng.nextDouble() * 0.4)).toStringAsFixed(1)),
          lastCheckup: today.subtract(Duration(days: 3 + rng.nextInt(40))),
          note: '',
        ),
      );
    }
  }

  addHerd(AnimalKind.cow, cowNames, cowBreeds, 560, 82);
  addHerd(AnimalKind.chicken, henNames, henBreeds, 2.3, 85);
  addHerd(AnimalKind.sheep, sheepNames, const ['코리데일', '메리노'], 70, 84);
  addHerd(AnimalKind.goat, goatNames, const ['보어', '자넨'], 55, 80);

  final fields = [
    CropField(
      id: 'tomato',
      zone: ZoneId.tomato,
      cropName: '토마토',
      emoji: '🍅',
      plantedAt: today.subtract(const Duration(days: 56)),
      growDays: 72,
      status: CropStatus.excellent,
      lastWateredAt: now.subtract(const Duration(hours: 20)),
      waterIntervalHours: 24,
      litersPerWatering: 420,
    ),
    CropField(
      id: 'vegetable',
      zone: ZoneId.vegetable,
      cropName: '상추·당근',
      emoji: '🥬',
      plantedAt: today.subtract(const Duration(days: 40)),
      growDays: 46,
      status: CropStatus.excellent,
      lastWateredAt: now.subtract(const Duration(hours: 13)),
      waterIntervalHours: 12,
      litersPerWatering: 260,
    ),
    CropField(
      id: 'corn',
      zone: ZoneId.corn,
      cropName: '옥수수',
      emoji: '🌽',
      plantedAt: today.subtract(const Duration(days: 63)),
      growDays: 90,
      status: CropStatus.good,
      lastWateredAt: now.subtract(const Duration(hours: 30)),
      waterIntervalHours: 48,
      litersPerWatering: 640,
    ),
    CropField(
      id: 'greenhouse',
      zone: ZoneId.greenhouse,
      cropName: '딸기',
      emoji: '🍓',
      plantedAt: today.subtract(const Duration(days: 30)),
      growDays: 80,
      status: CropStatus.attention,
      lastWateredAt: now.subtract(const Duration(hours: 9)),
      waterIntervalHours: 8,
      litersPerWatering: 180,
    ),
    CropField(
      id: 'orchard',
      zone: ZoneId.orchard,
      cropName: '사과',
      emoji: '🍎',
      plantedAt: today.subtract(const Duration(days: 150)),
      growDays: 180,
      status: CropStatus.good,
      lastWateredAt: now.subtract(const Duration(hours: 50)),
      waterIntervalHours: 72,
      litersPerWatering: 900,
    ),
  ];

  final waterLogs = <WaterLog>[];
  final production = <ProductionRecord>[];
  for (var d = 13; d >= 1; d--) {
    final day = today.subtract(Duration(days: d));
    waterLogs.add(
      WaterLog(at: day.add(const Duration(hours: 7)), liters: 900 + rng.nextInt(700).toDouble(), note: '정기 관수'),
    );
    production.add(
      ProductionRecord(
        dateKey: dateKeyOf(day),
        eggs: 13 + rng.nextInt(6),
        milkL: double.parse((150 + rng.nextDouble() * 40).toStringAsFixed(1)),
      ),
    );
  }

  final harvests = <HarvestRecord>[];
  const harvestPlan = [
    ('상추·당근', '🥬', 38.0),
    ('토마토', '🍅', 52.5),
    ('딸기', '🍓', 12.0),
    ('상추·당근', '🥬', 41.0),
    ('토마토', '🍅', 47.0),
    ('옥수수', '🌽', 120.0),
    ('사과', '🍎', 85.0),
    ('상추·당근', '🥬', 35.5),
  ];
  for (var i = 0; i < harvestPlan.length; i++) {
    final (name, emoji, kg) = harvestPlan[i];
    harvests.add(
      HarvestRecord(
        id: 'h$i',
        cropName: name,
        emoji: emoji,
        amountKg: kg,
        date: today.subtract(Duration(days: 4 + i * 6)),
        note: '',
      ),
    );
  }

  final todayKey = dateKeyOf(today);
  return FarmState(
    profile: const FarmProfile(
      name: '초록골 농장',
      areaHa: 12.5,
      locationLabel: '경기 이천',
      latitude: 37.272,
      longitude: 127.435,
      dailyEggTarget: 18,
      dailyMilkTargetL: 180,
    ),
    fields: fields,
    animals: animals,
    feedingSlots: const [
      FeedingSlot(hour: 6, minute: 0, label: '건초·사일리지'),
      FeedingSlot(hour: 12, minute: 0, label: '곡물 사료'),
      FeedingSlot(hour: 18, minute: 0, label: '저녁 급이'),
    ],
    feedingDone: {
      todayKey: [if (now.hour >= 6) 0, if (now.hour >= 12) 1],
    },
    tankCapacityL: 10000,
    tankStoredL: 8200,
    waterLogs: waterLogs,
    harvests: harvests,
    production: production,
    inventory: const [
      InventoryItem(
        id: 'hay',
        name: '건초',
        category: InventoryCategory.feed,
        quantity: 2400,
        unit: 'kg',
        dailyUse: 200,
        lowThreshold: 600,
      ),
      InventoryItem(
        id: 'grain',
        name: '곡물 사료',
        category: InventoryCategory.feed,
        quantity: 960,
        unit: 'kg',
        dailyUse: 80,
        lowThreshold: 240,
      ),
      InventoryItem(
        id: 'layer',
        name: '산란계 사료',
        category: InventoryCategory.feed,
        quantity: 54,
        unit: 'kg',
        dailyUse: 3,
        lowThreshold: 15,
      ),
      InventoryItem(
        id: 'seed-lettuce',
        name: '상추 종자',
        category: InventoryCategory.seed,
        quantity: 6,
        unit: '봉',
        dailyUse: 0,
        lowThreshold: 2,
      ),
      InventoryItem(
        id: 'compost',
        name: '퇴비',
        category: InventoryCategory.fertilizer,
        quantity: 14,
        unit: '포대',
        dailyUse: 0,
        lowThreshold: 10,
      ),
      InventoryItem(
        id: 'npk',
        name: '복합비료',
        category: InventoryCategory.fertilizer,
        quantity: 3,
        unit: '포대',
        dailyUse: 0,
        lowThreshold: 4,
      ),
      InventoryItem(
        id: 'twine',
        name: '유인끈',
        category: InventoryCategory.supply,
        quantity: 9,
        unit: '롤',
        dailyUse: 0,
        lowThreshold: 2,
      ),
    ],
    tasks: [
      FarmTask(id: 't1', title: '토마토 곁순 정리', dateKey: todayKey, done: false, zone: ZoneId.tomato),
      FarmTask(id: 't2', title: '온실 환기창 점검', dateKey: todayKey, done: false, zone: ZoneId.greenhouse),
      FarmTask(id: 't3', title: '달걀 수거', dateKey: todayKey, done: now.hour >= 10, zone: ZoneId.animals),
      FarmTask(id: 't4', title: '복합비료 주문', dateKey: todayKey, done: false, zone: ZoneId.storage),
    ],
  );
}
