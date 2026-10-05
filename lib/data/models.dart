import 'package:flutter/material.dart';

/// 지도 위 구역. 순서가 칩 순서이자 지도 레이아웃 키다. 이름은 l10n에서 정한다.
enum ZoneId {
  house(Icons.home_outlined),
  tomato(Icons.local_florist_outlined),
  vegetable(Icons.eco_outlined),
  corn(Icons.grass_outlined),
  animals(Icons.pets_outlined),
  water(Icons.water_drop_outlined),
  storage(Icons.warehouse_outlined),
  greenhouse(Icons.wb_sunny_outlined),
  orchard(Icons.park_outlined);

  const ZoneId(this.icon);
  final IconData icon;
}

enum AnimalKind {
  cow('COW'),
  chicken('HEN'),
  sheep('SHP'),
  goat('GOT');

  const AnimalKind(this.tagPrefix);

  /// 번호표 앞자리. 저장 데이터에 들어가므로 언어와 무관하게 고정한다.
  final String tagPrefix;
}

enum CropStatus {
  excellent(Color(0xFF2E7D4F)),
  good(Color(0xFF5B8C3A)),
  attention(Color(0xFFD9822B));

  const CropStatus(this.color);
  final Color color;
}

enum InventoryCategory { feed, seed, fertilizer, supply }

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

DateTime _date(Object? v) => DateTime.parse(v as String);
DateTime? _dateOrNull(Object? v) => v == null ? null : DateTime.parse(v as String);
double _d(Object? v) => (v as num).toDouble();

class FarmProfile {
  const FarmProfile({
    required this.name,
    required this.areaHa,
    required this.locationLabel,
    required this.latitude,
    required this.longitude,
    required this.dailyEggTarget,
    required this.dailyMilkTargetL,
    required this.currency,
  });

  final String name;
  final double areaHa;
  final String locationLabel;
  final double latitude;
  final double longitude;
  final int dailyEggTarget;
  final double dailyMilkTargetL;

  /// 장부 금액의 통화(ISO 4217 코드). 바꿔도 이미 적은 금액은 환산하지 않는다.
  final String currency;

  FarmProfile copyWith({
    String? name,
    double? areaHa,
    String? locationLabel,
    double? latitude,
    double? longitude,
    int? dailyEggTarget,
    double? dailyMilkTargetL,
    String? currency,
  }) => FarmProfile(
    name: name ?? this.name,
    areaHa: areaHa ?? this.areaHa,
    locationLabel: locationLabel ?? this.locationLabel,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    dailyEggTarget: dailyEggTarget ?? this.dailyEggTarget,
    dailyMilkTargetL: dailyMilkTargetL ?? this.dailyMilkTargetL,
    currency: currency ?? this.currency,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'areaHa': areaHa,
    'locationLabel': locationLabel,
    'latitude': latitude,
    'longitude': longitude,
    'dailyEggTarget': dailyEggTarget,
    'dailyMilkTargetL': dailyMilkTargetL,
    'currency': currency,
  };

  factory FarmProfile.fromJson(Map<String, Object?> j) => FarmProfile(
    name: j['name'] as String,
    areaHa: _d(j['areaHa']),
    locationLabel: j['locationLabel'] as String,
    latitude: _d(j['latitude']),
    longitude: _d(j['longitude']),
    dailyEggTarget: j['dailyEggTarget'] as int,
    dailyMilkTargetL: _d(j['dailyMilkTargetL']),
    currency: j['currency'] as String,
  );
}

/// 밭(작물이 자라는 구역). 생육률은 파종일과 재배 기간으로 계산한다.
class CropField {
  const CropField({
    required this.id,
    required this.zone,
    required this.cropName,
    required this.emoji,
    required this.plantedAt,
    required this.growDays,
    required this.status,
    required this.lastWateredAt,
    required this.waterIntervalHours,
    required this.litersPerWatering,
  });

  final String id;
  final ZoneId zone;
  final String cropName;
  final String emoji;
  final DateTime plantedAt;
  final int growDays;
  final CropStatus status;
  final DateTime lastWateredAt;
  final int waterIntervalHours;
  final double litersPerWatering;

  double growthAt(DateTime now) {
    final elapsed = now.difference(plantedAt).inMinutes / (24 * 60);
    return (elapsed / growDays).clamp(0.0, 1.0);
  }

  int daysToHarvest(DateTime now) {
    final harvestAt = plantedAt.add(Duration(days: growDays));
    final d = harvestAt.difference(now).inHours / 24;
    return d <= 0 ? 0 : d.ceil();
  }

  DateTime get nextWateringAt => lastWateredAt.add(Duration(hours: waterIntervalHours));

  bool needsWater(DateTime now) => !nextWateringAt.isAfter(now);

  CropField copyWith({
    String? cropName,
    String? emoji,
    DateTime? plantedAt,
    int? growDays,
    CropStatus? status,
    DateTime? lastWateredAt,
    int? waterIntervalHours,
    double? litersPerWatering,
  }) => CropField(
    id: id,
    zone: zone,
    cropName: cropName ?? this.cropName,
    emoji: emoji ?? this.emoji,
    plantedAt: plantedAt ?? this.plantedAt,
    growDays: growDays ?? this.growDays,
    status: status ?? this.status,
    lastWateredAt: lastWateredAt ?? this.lastWateredAt,
    waterIntervalHours: waterIntervalHours ?? this.waterIntervalHours,
    litersPerWatering: litersPerWatering ?? this.litersPerWatering,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'zone': zone.name,
    'cropName': cropName,
    'emoji': emoji,
    'plantedAt': plantedAt.toIso8601String(),
    'growDays': growDays,
    'status': status.name,
    'lastWateredAt': lastWateredAt.toIso8601String(),
    'waterIntervalHours': waterIntervalHours,
    'litersPerWatering': litersPerWatering,
  };

  factory CropField.fromJson(Map<String, Object?> j) => CropField(
    id: j['id'] as String,
    zone: _enumByName(ZoneId.values, j['zone'], ZoneId.tomato),
    cropName: j['cropName'] as String,
    emoji: j['emoji'] as String,
    plantedAt: _date(j['plantedAt']),
    growDays: j['growDays'] as int,
    status: _enumByName(CropStatus.values, j['status'], CropStatus.good),
    lastWateredAt: _date(j['lastWateredAt']),
    waterIntervalHours: j['waterIntervalHours'] as int,
    litersPerWatering: _d(j['litersPerWatering']),
  );
}

class Animal {
  const Animal({
    required this.id,
    required this.kind,
    required this.tag,
    required this.name,
    required this.breed,
    required this.birthDate,
    required this.health,
    required this.weightKg,
    required this.lastCheckup,
    required this.note,
  });

  final String id;
  final AnimalKind kind;
  final String tag;
  final String name;
  final String breed;
  final DateTime birthDate;

  /// 0~100 건강 점수(검진 때 기록).
  final int health;
  final double weightKg;
  final DateTime? lastCheckup;
  final String note;

  /// 아이콘 무늬를 고르는 안정적인 번호(id 끝 숫자).
  int get variant => int.tryParse(id.split('-').last) ?? 0;

  /// 태어난 뒤 지난 개월 수(0 이상).
  int ageInMonths(DateTime now) {
    final months = (now.year - birthDate.year) * 12 + now.month - birthDate.month - (now.day < birthDate.day ? 1 : 0);
    return months < 0 ? 0 : months;
  }

  Animal copyWith({int? health, double? weightKg, DateTime? lastCheckup, String? note, String? name}) => Animal(
    id: id,
    kind: kind,
    tag: tag,
    name: name ?? this.name,
    breed: breed,
    birthDate: birthDate,
    health: health ?? this.health,
    weightKg: weightKg ?? this.weightKg,
    lastCheckup: lastCheckup ?? this.lastCheckup,
    note: note ?? this.note,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'tag': tag,
    'name': name,
    'breed': breed,
    'birthDate': birthDate.toIso8601String(),
    'health': health,
    'weightKg': weightKg,
    'lastCheckup': lastCheckup?.toIso8601String(),
    'note': note,
  };

  factory Animal.fromJson(Map<String, Object?> j) => Animal(
    id: j['id'] as String,
    kind: _enumByName(AnimalKind.values, j['kind'], AnimalKind.cow),
    tag: j['tag'] as String,
    name: j['name'] as String,
    breed: j['breed'] as String,
    birthDate: _date(j['birthDate']),
    health: j['health'] as int,
    weightKg: _d(j['weightKg']),
    lastCheckup: _dateOrNull(j['lastCheckup']),
    note: j['note'] as String? ?? '',
  );
}

class FeedingSlot {
  const FeedingSlot({required this.hour, required this.minute, required this.label});

  final int hour;
  final int minute;
  final String label;

  String get timeLabel => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, Object?> toJson() => {'hour': hour, 'minute': minute, 'label': label};

  factory FeedingSlot.fromJson(Map<String, Object?> j) =>
      FeedingSlot(hour: j['hour'] as int, minute: j['minute'] as int, label: j['label'] as String);
}

class WaterLog {
  const WaterLog({required this.at, required this.liters, this.note = '', this.fieldId, this.smart = false});

  final DateTime at;

  /// 양수는 사용량, 음수는 보충량.
  final double liters;

  /// 사용자가 남긴 메모(앱이 만든 기록은 비어 있고 화면에서 문구를 만든다).
  final String note;

  /// 물을 준 밭. 보충 기록이나 v1.3.0 이전 기록은 null.
  final String? fieldId;

  /// 스마트 관수로 준 물인지.
  final bool smart;

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'liters': liters,
    'note': note,
    if (fieldId != null) 'fieldId': fieldId,
    if (smart) 'smart': true,
  };

  factory WaterLog.fromJson(Map<String, Object?> j) => WaterLog(
    at: _date(j['at']),
    liters: _d(j['liters']),
    note: j['note'] as String? ?? '',
    fieldId: j['fieldId'] as String?,
    smart: j['smart'] as bool? ?? false,
  );
}

class HarvestRecord {
  const HarvestRecord({
    required this.id,
    required this.cropName,
    required this.emoji,
    required this.amountKg,
    required this.date,
    required this.note,
  });

  final String id;
  final String cropName;
  final String emoji;
  final double amountKg;
  final DateTime date;
  final String note;

  Map<String, Object?> toJson() => {
    'id': id,
    'cropName': cropName,
    'emoji': emoji,
    'amountKg': amountKg,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory HarvestRecord.fromJson(Map<String, Object?> j) => HarvestRecord(
    id: j['id'] as String,
    cropName: j['cropName'] as String,
    emoji: j['emoji'] as String,
    amountKg: _d(j['amountKg']),
    date: _date(j['date']),
    note: j['note'] as String? ?? '',
  );
}

/// 하루 단위 축산 생산량(달걀·우유).
class ProductionRecord {
  const ProductionRecord({required this.dateKey, required this.eggs, required this.milkL});

  final String dateKey;
  final int eggs;
  final double milkL;

  Map<String, Object?> toJson() => {'dateKey': dateKey, 'eggs': eggs, 'milkL': milkL};

  factory ProductionRecord.fromJson(Map<String, Object?> j) =>
      ProductionRecord(dateKey: j['dateKey'] as String, eggs: j['eggs'] as int, milkL: _d(j['milkL']));
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.dailyUse,
    required this.lowThreshold,
  });

  final String id;
  final String name;
  final InventoryCategory category;
  final double quantity;
  final String unit;

  /// 하루 평균 소비량. 0이면 소비 예측을 하지 않는다.
  final double dailyUse;
  final double lowThreshold;

  bool get isLow => quantity <= lowThreshold;

  double? get daysLeft => dailyUse > 0 ? quantity / dailyUse : null;

  InventoryItem copyWith({double? quantity}) => InventoryItem(
    id: id,
    name: name,
    category: category,
    quantity: quantity ?? this.quantity,
    unit: unit,
    dailyUse: dailyUse,
    lowThreshold: lowThreshold,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'quantity': quantity,
    'unit': unit,
    'dailyUse': dailyUse,
    'lowThreshold': lowThreshold,
  };

  factory InventoryItem.fromJson(Map<String, Object?> j) => InventoryItem(
    id: j['id'] as String,
    name: j['name'] as String,
    category: _enumByName(InventoryCategory.values, j['category'], InventoryCategory.supply),
    quantity: _d(j['quantity']),
    unit: j['unit'] as String,
    dailyUse: _d(j['dailyUse']),
    lowThreshold: _d(j['lowThreshold']),
  );
}

class FarmTask {
  const FarmTask({required this.id, required this.title, required this.dateKey, required this.done, this.zone});

  final String id;
  final String title;
  final String dateKey;
  final bool done;
  final ZoneId? zone;

  FarmTask copyWith({bool? done}) =>
      FarmTask(id: id, title: title, dateKey: dateKey, done: done ?? this.done, zone: zone);

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'dateKey': dateKey, 'done': done, 'zone': zone?.name};

  factory FarmTask.fromJson(Map<String, Object?> j) => FarmTask(
    id: j['id'] as String,
    title: j['title'] as String,
    dateKey: j['dateKey'] as String,
    done: j['done'] as bool,
    zone: j['zone'] == null ? null : _enumByName(ZoneId.values, j['zone'], ZoneId.house),
  );
}

String dateKeyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum AnimalEventType { added, sold, died, other }

/// 가축 입식·출하·폐사 이력. 개체가 목록에서 빠져도 기록은 남는다.
class AnimalEvent {
  const AnimalEvent({
    required this.id,
    required this.type,
    required this.kind,
    required this.tag,
    required this.name,
    required this.date,
    required this.note,
  });

  final String id;
  final AnimalEventType type;
  final AnimalKind kind;
  final String tag;
  final String name;
  final DateTime date;
  final String note;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'kind': kind.name,
    'tag': tag,
    'name': name,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory AnimalEvent.fromJson(Map<String, Object?> j) => AnimalEvent(
    id: j['id'] as String,
    type: _enumByName(AnimalEventType.values, j['type'], AnimalEventType.other),
    kind: _enumByName(AnimalKind.values, j['kind'], AnimalKind.cow),
    tag: j['tag'] as String,
    name: j['name'] as String,
    date: _date(j['date']),
    note: j['note'] as String? ?? '',
  );
}

enum CareType {
  vaccine(Icons.vaccines_outlined),
  checkup(Icons.monitor_heart_outlined),
  deworm(Icons.bug_report_outlined),
  other(Icons.medical_services_outlined);

  const CareType(this.icon);
  final IconData icon;
}

/// 백신·검진 같은 가축 관리 일정. [animalId]가 없으면 해당 종 전체가 대상이다.
class CareItem {
  const CareItem({
    required this.id,
    required this.kind,
    required this.animalId,
    required this.type,
    required this.title,
    required this.dueDate,
    required this.repeatMonths,
    required this.doneAt,
    required this.note,
  });

  final String id;
  final AnimalKind kind;
  final String? animalId;
  final CareType type;
  final String title;
  final DateTime dueDate;

  /// 0이면 반복하지 않는다. 완료하면 이 개월 수 뒤로 다음 일정을 만든다.
  final int repeatMonths;
  final DateTime? doneAt;
  final String note;

  bool get isDone => doneAt != null;

  /// 오늘 기준 남은 일수(지났으면 음수).
  int daysUntil(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  CareItem copyWith({DateTime? doneAt}) => CareItem(
    id: id,
    kind: kind,
    animalId: animalId,
    type: type,
    title: title,
    dueDate: dueDate,
    repeatMonths: repeatMonths,
    doneAt: doneAt ?? this.doneAt,
    note: note,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'animalId': animalId,
    'type': type.name,
    'title': title,
    'dueDate': dueDate.toIso8601String(),
    'repeatMonths': repeatMonths,
    'doneAt': doneAt?.toIso8601String(),
    'note': note,
  };

  factory CareItem.fromJson(Map<String, Object?> j) => CareItem(
    id: j['id'] as String,
    kind: _enumByName(AnimalKind.values, j['kind'], AnimalKind.cow),
    animalId: j['animalId'] as String?,
    type: _enumByName(CareType.values, j['type'], CareType.other),
    title: j['title'] as String,
    dueDate: _date(j['dueDate']),
    repeatMonths: j['repeatMonths'] as int? ?? 0,
    doneAt: _dateOrNull(j['doneAt']),
    note: j['note'] as String? ?? '',
  );
}

/// [from]에서 [months]개월 뒤 같은 날(그 달에 없으면 말일).
DateTime addMonths(DateTime from, int months) {
  final total = from.year * 12 + (from.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, from.day > lastDay ? lastDay : from.day);
}

/// 장부에서 고를 수 있는 통화.
const supportedCurrencies = ['KRW', 'USD', 'EUR', 'JPY', 'CNY', 'GBP'];

/// 장부 분류. 매출인지 비용인지는 분류가 정한다.
enum LedgerCategory {
  crops(true, Icons.local_florist_outlined),
  livestock(true, Icons.pets_outlined),
  products(true, Icons.egg_outlined),
  subsidy(true, Icons.account_balance_outlined),
  otherIncome(true, Icons.savings_outlined),
  feed(false, Icons.grass_outlined),
  seeds(false, Icons.spa_outlined),
  fertilizer(false, Icons.science_outlined),
  equipment(false, Icons.agriculture_outlined),
  labor(false, Icons.groups_outlined),
  utilities(false, Icons.bolt_outlined),
  vet(false, Icons.medical_services_outlined),
  otherExpense(false, Icons.receipt_long_outlined);

  const LedgerCategory(this.isIncome, this.icon);
  final bool isIncome;
  final IconData icon;

  static List<LedgerCategory> of({required bool income}) => [
    for (final c in values)
      if (c.isIncome == income) c,
  ];
}

/// 매출·비용 한 건. 금액은 농장 통화 기준 양수이고, 부호는 분류로 정한다.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    required this.note,
  });

  final String id;
  final LedgerCategory category;
  final double amount;

  /// 거래한 날(자정).
  final DateTime date;
  final String note;

  bool get isIncome => category.isIncome;

  Map<String, Object?> toJson() => {
    'id': id,
    'category': category.name,
    'amount': amount,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory LedgerEntry.fromJson(Map<String, Object?> j) => LedgerEntry(
    id: j['id'] as String,
    category: _enumByName(LedgerCategory.values, j['category'], LedgerCategory.otherExpense),
    amount: _d(j['amount']),
    date: _date(j['date']),
    note: j['note'] as String? ?? '',
  );
}
