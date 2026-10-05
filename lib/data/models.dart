import 'package:flutter/material.dart';

/// 지도 위 구역. 순서가 칩 순서이자 지도 레이아웃 키다.
enum ZoneId {
  house('농가', '농가 주택', Icons.home_outlined),
  tomato('토마토', '토마토 밭', Icons.local_florist_outlined),
  vegetable('채소', '채소 밭', Icons.eco_outlined),
  corn('옥수수', '옥수수 밭', Icons.grass_outlined),
  animals('가축', '가축 구역', Icons.pets_outlined),
  water('물탱크', '물탱크', Icons.water_drop_outlined),
  storage('창고', '창고', Icons.warehouse_outlined),
  greenhouse('온실', '온실', Icons.wb_sunny_outlined),
  orchard('과수원', '과수원·양봉', Icons.park_outlined);

  const ZoneId(this.shortLabel, this.label, this.icon);
  final String shortLabel;
  final String label;
  final IconData icon;
}

enum AnimalKind {
  cow('소', '마리', 'COW'),
  chicken('닭', '마리', 'HEN'),
  sheep('양', '마리', 'SHP'),
  goat('염소', '마리', 'GOT');

  const AnimalKind(this.label, this.unit, this.tagPrefix);
  final String label;
  final String unit;
  final String tagPrefix;
}

enum CropStatus {
  excellent('아주 좋음', Color(0xFF2E7D4F)),
  good('좋음', Color(0xFF5B8C3A)),
  attention('관리 필요', Color(0xFFD9822B));

  const CropStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum InventoryCategory {
  feed('사료'),
  seed('종자'),
  fertilizer('비료'),
  supply('자재');

  const InventoryCategory(this.label);
  final String label;
}

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
  });

  final String name;
  final double areaHa;
  final String locationLabel;
  final double latitude;
  final double longitude;
  final int dailyEggTarget;
  final double dailyMilkTargetL;

  FarmProfile copyWith({
    String? name,
    double? areaHa,
    String? locationLabel,
    double? latitude,
    double? longitude,
    int? dailyEggTarget,
    double? dailyMilkTargetL,
  }) => FarmProfile(
    name: name ?? this.name,
    areaHa: areaHa ?? this.areaHa,
    locationLabel: locationLabel ?? this.locationLabel,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    dailyEggTarget: dailyEggTarget ?? this.dailyEggTarget,
    dailyMilkTargetL: dailyMilkTargetL ?? this.dailyMilkTargetL,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'areaHa': areaHa,
    'locationLabel': locationLabel,
    'latitude': latitude,
    'longitude': longitude,
    'dailyEggTarget': dailyEggTarget,
    'dailyMilkTargetL': dailyMilkTargetL,
  };

  factory FarmProfile.fromJson(Map<String, Object?> j) => FarmProfile(
    name: j['name'] as String,
    areaHa: _d(j['areaHa']),
    locationLabel: j['locationLabel'] as String,
    latitude: _d(j['latitude']),
    longitude: _d(j['longitude']),
    dailyEggTarget: j['dailyEggTarget'] as int,
    dailyMilkTargetL: _d(j['dailyMilkTargetL']),
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

  String ageLabel(DateTime now) {
    final months = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
    if (months < 12) return '${months.clamp(0, 11)}개월';
    final years = months / 12;
    return years == years.roundToDouble() ? '${years.toInt()}살' : '${years.toStringAsFixed(1)}살';
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

/// 가축 수가 바뀐 이유. 출하·폐사한 개체는 목록에서 빠지므로 이 기록이 유일한 이력이다.
enum AnimalEventType {
  added('입식', Icons.add_circle_outline_rounded, Color(0xFF2E7D4F)),
  sold('출하', Icons.local_shipping_outlined, Color(0xFF3D8ED8)),
  died('폐사', Icons.heart_broken_outlined, Color(0xFF7C837D));

  const AnimalEventType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

/// 입식·출하·폐사 기록. 개체가 목록에서 사라진 뒤에도 읽을 수 있도록 이름·태그를 함께 남긴다.
class AnimalEvent {
  const AnimalEvent({
    required this.id,
    required this.type,
    required this.animalId,
    required this.kind,
    required this.tag,
    required this.name,
    required this.date,
    required this.note,
  });

  final String id;
  final AnimalEventType type;
  final String animalId;
  final AnimalKind kind;
  final String tag;
  final String name;
  final DateTime date;
  final String note;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'animalId': animalId,
    'kind': kind.name,
    'tag': tag,
    'name': name,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory AnimalEvent.fromJson(Map<String, Object?> j) => AnimalEvent(
    id: j['id'] as String,
    type: _enumByName(AnimalEventType.values, j['type'], AnimalEventType.added),
    animalId: j['animalId'] as String,
    kind: _enumByName(AnimalKind.values, j['kind'], AnimalKind.cow),
    tag: j['tag'] as String,
    name: j['name'] as String,
    date: _date(j['date']),
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
  const WaterLog({required this.at, required this.liters, required this.note});

  final DateTime at;

  /// 양수는 사용량, 음수는 보충량.
  final double liters;
  final String note;

  Map<String, Object?> toJson() => {'at': at.toIso8601String(), 'liters': liters, 'note': note};

  factory WaterLog.fromJson(Map<String, Object?> j) =>
      WaterLog(at: _date(j['at']), liters: _d(j['liters']), note: j['note'] as String);
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

/// [d]의 날짜에서 [months]개월 앞선 날(시각은 버림).
/// `DateTime(y, m - n, 31)`처럼 그 달에 없는 날이면 다음 달로 넘어가 나이가 어긋나므로, 그 달의 마지막 날로 맞춘다.
DateTime monthsBefore(DateTime d, int months) {
  final first = DateTime(d.year, d.month - months);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, d.day < lastDay ? d.day : lastDay);
}
