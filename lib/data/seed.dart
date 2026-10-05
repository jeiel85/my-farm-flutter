import 'dart:math';

import 'farm_state.dart';
import 'models.dart';

/// 처음 실행하거나 "예시 농장으로 초기화"를 누를 때 쓰는 예시 데이터.
/// 날짜는 모두 [now] 기준 상대값이라 언제 열어도 그럴듯한 상태가 된다.
/// 이름 같은 내용은 사용자 데이터가 되므로 만들 때의 언어([english])로 채운다.
FarmState buildDemoFarm(DateTime now, {bool english = false}) {
  final rng = Random(42);
  final today = DateTime(now.year, now.month, now.day);
  String t(String ko, String en) => english ? en : ko;

  final cowNames = english
      ? const [
          'Bella',
          'Daisy',
          'Moose',
          'Cocoa',
          'Latte',
          'Cloud',
          'Barley',
          'Bean',
          'Bambi',
          'Nora',
          'Rainy',
          'Happy',
          'Mocha',
          'Tofu',
          'Cotton',
          'Sunny',
          'Star',
          'Pearl',
        ]
      : const [
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
  final cowBreeds = english ? const ['Holstein', 'Jersey', 'Hanwoo', 'Angus'] : const ['홀스타인', '저지', '한우', '앵거스'];
  final henNames = english
      ? const [
          'Clucky',
          'Peep',
          'Pepper',
          'Sesame',
          'Goldie',
          'Luna',
          'Peanut',
          'Jelly',
          'Spring',
          'Summer',
          'Autumn',
          'Winter',
          'Ginger',
          'Nutmeg',
          'Jade',
          'Fluffy',
          'Toby',
          'Poppy',
          'Lily',
          'Mimi',
        ]
      : const [
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
  final henBreeds = english ? const ['Rhode Island Red', 'Leghorn', 'Silkie'] : const ['로드아일랜드 레드', '레그혼', '오골계'];
  final sheepNames = english
      ? const ['Woolly', 'Puff', 'Snuggle', 'Candy', 'Cloudy', 'Snowflake']
      : const ['양털이', '몽실', '포근', '솜사탕', '구르미', '눈송이'];
  final goatNames = english ? const ['Inky', 'Horny', 'Breeze', 'Rocky'] : const ['깜순', '뿔이', '산들', '바위'];

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
  addHerd(AnimalKind.sheep, sheepNames, [t('코리데일', 'Corriedale'), t('메리노', 'Merino')], 70, 84);
  addHerd(AnimalKind.goat, goatNames, [t('보어', 'Boer'), t('자넨', 'Saanen')], 55, 80);

  final fields = [
    CropField(
      id: 'tomato',
      zone: ZoneId.tomato,
      cropName: t('토마토', 'Tomato'),
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
      cropName: t('상추·당근', 'Lettuce & Carrot'),
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
      cropName: t('옥수수', 'Corn'),
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
      cropName: t('딸기', 'Strawberry'),
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
      cropName: t('사과', 'Apple'),
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
      WaterLog(
        at: day.add(const Duration(hours: 7)),
        liters: 900 + rng.nextInt(700).toDouble(),
        note: t('정기 관수', 'Scheduled irrigation'),
      ),
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
  final tomato = t('토마토', 'Tomato');
  final veg = t('상추·당근', 'Lettuce & Carrot');
  final harvestPlan = [
    (veg, '🥬', 38.0),
    (tomato, '🍅', 52.5),
    (t('딸기', 'Strawberry'), '🍓', 12.0),
    (veg, '🥬', 41.0),
    (tomato, '🍅', 47.0),
    (t('옥수수', 'Corn'), '🌽', 120.0),
    (t('사과', 'Apple'), '🍎', 85.0),
    (veg, '🥬', 35.5),
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

  // 장부: 최근 여섯 달의 매출·비용. 금액은 만들 때의 언어에 맞는 통화로 적는다.
  final currency = english ? 'USD' : 'KRW';
  final ledger = <LedgerEntry>[];
  void book(int daysAgo, LedgerCategory category, int krw, String note) => ledger.add(
    LedgerEntry(
      id: 'l${ledger.length.toString().padLeft(3, '0')}',
      category: category,
      amount: english ? (krw / 1350).roundToDouble() : krw.toDouble(),
      date: today.subtract(Duration(days: daysAgo)),
      note: note,
    ),
  );
  for (var m = 0; m < 6; m++) {
    final base = m * 30;
    book(base + 2, LedgerCategory.products, 1850000 + rng.nextInt(30) * 10000, t('우유 납유 대금', 'Milk payment'));
    book(base + 6, LedgerCategory.products, 420000 + rng.nextInt(8) * 10000, t('달걀 직거래', 'Egg sales'));
    book(base + 9, LedgerCategory.feed, 980000 + rng.nextInt(15) * 10000, t('곡물 사료 구입', 'Grain mix'));
    book(base + 15, LedgerCategory.utilities, 210000 + rng.nextInt(6) * 10000, t('전기·수도 요금', 'Power & water'));
    book(base + 20, LedgerCategory.labor, 600000, t('일손 인건비', 'Farm helpers'));
  }
  book(4, LedgerCategory.crops, 960000, t('토마토 공판장 출하', 'Tomatoes to market'));
  book(11, LedgerCategory.vet, 180000, t('구제역 백신', 'FMD vaccine'));
  book(17, LedgerCategory.crops, 540000, t('상추·당근 로컬푸드', 'Greens to local market'));
  book(26, LedgerCategory.fertilizer, 320000, t('복합비료 20포', 'NPK fertilizer, 20 bags'));
  book(38, LedgerCategory.livestock, 4200000, t('한우 1두 출하', 'Sold one Hanwoo steer'));
  book(45, LedgerCategory.equipment, 750000, t('트랙터 정비', 'Tractor service'));
  book(52, LedgerCategory.seeds, 260000, t('딸기 모종', 'Strawberry seedlings'));
  book(70, LedgerCategory.subsidy, 1500000, t('친환경 직불금', 'Eco-farming subsidy'));
  book(88, LedgerCategory.crops, 1250000, t('옥수수 계약 출하', 'Contract corn sale'));

  final todayKey = dateKeyOf(today);
  return FarmState(
    profile: FarmProfile(
      name: t('초록골 농장', 'Green Valley Farm'),
      areaHa: 12.5,
      locationLabel: t('경기 이천', 'Icheon, Korea'),
      latitude: 37.272,
      longitude: 127.435,
      dailyEggTarget: 18,
      dailyMilkTargetL: 180,
      currency: currency,
    ),
    fields: fields,
    animals: animals,
    animalEvents: const [],
    careItems: [
      CareItem(
        id: 'c1',
        kind: AnimalKind.cow,
        animalId: null,
        type: CareType.vaccine,
        title: t('구제역 백신', 'FMD vaccine'),
        dueDate: today.add(const Duration(days: 5)),
        repeatMonths: 6,
        doneAt: null,
        note: '',
      ),
      CareItem(
        id: 'c2',
        kind: AnimalKind.chicken,
        animalId: null,
        type: CareType.vaccine,
        title: t('뉴캐슬병 백신', 'Newcastle disease vaccine'),
        dueDate: today.subtract(const Duration(days: 1)),
        repeatMonths: 3,
        doneAt: null,
        note: t('음수 투여', 'In drinking water'),
      ),
      CareItem(
        id: 'c3',
        kind: AnimalKind.cow,
        animalId: 'cow-0',
        type: CareType.checkup,
        title: t('정기 검진', 'Routine checkup'),
        dueDate: today.add(const Duration(days: 2)),
        repeatMonths: 0,
        doneAt: null,
        note: '',
      ),
      CareItem(
        id: 'c4',
        kind: AnimalKind.sheep,
        animalId: null,
        type: CareType.deworm,
        title: t('구충제 투여', 'Deworming'),
        dueDate: today.add(const Duration(days: 20)),
        repeatMonths: 6,
        doneAt: null,
        note: '',
      ),
    ],
    feedingSlots: [
      FeedingSlot(hour: 6, minute: 0, label: t('건초·사일리지', 'Hay & silage')),
      FeedingSlot(hour: 12, minute: 0, label: t('곡물 사료', 'Grain mix')),
      FeedingSlot(hour: 18, minute: 0, label: t('저녁 급이', 'Evening feed')),
    ],
    feedingDone: {
      todayKey: [if (now.hour >= 6) 0, if (now.hour >= 12) 1],
    },
    // 예시 데이터의 오늘 급이 완료분은 재고 차감 기록이 없으므로 체크를 풀어도 재고가 늘지 않는다.
    feedingUsage: const {},
    tankCapacityL: 10000,
    tankStoredL: 8200,
    waterLogs: waterLogs,
    harvests: harvests,
    production: production,
    inventory: [
      InventoryItem(
        id: 'hay',
        name: t('건초', 'Hay'),
        category: InventoryCategory.feed,
        quantity: 2400,
        unit: 'kg',
        dailyUse: 200,
        lowThreshold: 600,
      ),
      InventoryItem(
        id: 'grain',
        name: t('곡물 사료', 'Grain mix'),
        category: InventoryCategory.feed,
        quantity: 960,
        unit: 'kg',
        dailyUse: 80,
        lowThreshold: 240,
      ),
      InventoryItem(
        id: 'layer',
        name: t('산란계 사료', 'Layer feed'),
        category: InventoryCategory.feed,
        quantity: 54,
        unit: 'kg',
        dailyUse: 3,
        lowThreshold: 15,
      ),
      InventoryItem(
        id: 'seed-lettuce',
        name: t('상추 종자', 'Lettuce seeds'),
        category: InventoryCategory.seed,
        quantity: 6,
        unit: t('봉', 'packs'),
        dailyUse: 0,
        lowThreshold: 2,
      ),
      InventoryItem(
        id: 'compost',
        name: t('퇴비', 'Compost'),
        category: InventoryCategory.fertilizer,
        quantity: 14,
        unit: t('포대', 'bags'),
        dailyUse: 0,
        lowThreshold: 10,
      ),
      InventoryItem(
        id: 'npk',
        name: t('복합비료', 'NPK fertilizer'),
        category: InventoryCategory.fertilizer,
        quantity: 3,
        unit: t('포대', 'bags'),
        dailyUse: 0,
        lowThreshold: 4,
      ),
      InventoryItem(
        id: 'twine',
        name: t('유인끈', 'Garden twine'),
        category: InventoryCategory.supply,
        quantity: 9,
        unit: t('롤', 'rolls'),
        dailyUse: 0,
        lowThreshold: 2,
      ),
    ],
    tasks: [
      FarmTask(
        id: 't1',
        title: t('토마토 곁순 정리', 'Prune tomato suckers'),
        dateKey: todayKey,
        done: false,
        zone: ZoneId.tomato,
      ),
      FarmTask(
        id: 't2',
        title: t('온실 환기창 점검', 'Check greenhouse vents'),
        dateKey: todayKey,
        done: false,
        zone: ZoneId.greenhouse,
      ),
      FarmTask(
        id: 't3',
        title: t('달걀 수거', 'Collect eggs'),
        dateKey: todayKey,
        done: now.hour >= 10,
        zone: ZoneId.animals,
      ),
      FarmTask(
        id: 't4',
        title: t('복합비료 주문', 'Order NPK fertilizer'),
        dateKey: todayKey,
        done: false,
        zone: ZoneId.storage,
      ),
    ],
    ledger: ledger,
  );
}
