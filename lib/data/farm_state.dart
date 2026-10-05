import 'models.dart';

/// 앱이 저장하는 전체 상태. JSON 하나로 직렬화한다.
class FarmState {
  const FarmState({
    required this.profile,
    required this.fields,
    required this.animals,
    required this.feedingSlots,
    required this.feedingDone,
    required this.tankCapacityL,
    required this.tankStoredL,
    required this.waterLogs,
    required this.harvests,
    required this.production,
    required this.inventory,
    required this.tasks,
  });

  static const schemaVersion = 1;

  final FarmProfile profile;
  final List<CropField> fields;
  final List<Animal> animals;
  final List<FeedingSlot> feedingSlots;

  /// 날짜 키(yyyy-MM-dd) → 완료한 급이 슬롯 인덱스.
  final Map<String, List<int>> feedingDone;
  final double tankCapacityL;
  final double tankStoredL;
  final List<WaterLog> waterLogs;
  final List<HarvestRecord> harvests;
  final List<ProductionRecord> production;
  final List<InventoryItem> inventory;
  final List<FarmTask> tasks;

  FarmState copyWith({
    FarmProfile? profile,
    List<CropField>? fields,
    List<Animal>? animals,
    Map<String, List<int>>? feedingDone,
    double? tankStoredL,
    List<WaterLog>? waterLogs,
    List<HarvestRecord>? harvests,
    List<ProductionRecord>? production,
    List<InventoryItem>? inventory,
    List<FarmTask>? tasks,
  }) => FarmState(
    profile: profile ?? this.profile,
    fields: fields ?? this.fields,
    animals: animals ?? this.animals,
    feedingSlots: feedingSlots,
    feedingDone: feedingDone ?? this.feedingDone,
    tankCapacityL: tankCapacityL,
    tankStoredL: tankStoredL ?? this.tankStoredL,
    waterLogs: waterLogs ?? this.waterLogs,
    harvests: harvests ?? this.harvests,
    production: production ?? this.production,
    inventory: inventory ?? this.inventory,
    tasks: tasks ?? this.tasks,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'profile': profile.toJson(),
    'fields': [for (final f in fields) f.toJson()],
    'animals': [for (final a in animals) a.toJson()],
    'feedingSlots': [for (final s in feedingSlots) s.toJson()],
    'feedingDone': feedingDone,
    'tankCapacityL': tankCapacityL,
    'tankStoredL': tankStoredL,
    'waterLogs': [for (final w in waterLogs) w.toJson()],
    'harvests': [for (final h in harvests) h.toJson()],
    'production': [for (final p in production) p.toJson()],
    'inventory': [for (final i in inventory) i.toJson()],
    'tasks': [for (final t in tasks) t.toJson()],
  };

  factory FarmState.fromJson(Map<String, Object?> j) {
    final version = j['schemaVersion'];
    if (version != schemaVersion) {
      throw FormatException('지원하지 않는 저장 형식 버전: $version');
    }
    List<Map<String, Object?>> list(String key) => [for (final e in j[key] as List) (e as Map).cast<String, Object?>()];
    final done = (j['feedingDone'] as Map).map((k, v) => MapEntry(k as String, [for (final i in v as List) i as int]));
    return FarmState(
      profile: FarmProfile.fromJson((j['profile'] as Map).cast<String, Object?>()),
      fields: [for (final m in list('fields')) CropField.fromJson(m)],
      animals: [for (final m in list('animals')) Animal.fromJson(m)],
      feedingSlots: [for (final m in list('feedingSlots')) FeedingSlot.fromJson(m)],
      feedingDone: done,
      tankCapacityL: (j['tankCapacityL'] as num).toDouble(),
      tankStoredL: (j['tankStoredL'] as num).toDouble(),
      waterLogs: [for (final m in list('waterLogs')) WaterLog.fromJson(m)],
      harvests: [for (final m in list('harvests')) HarvestRecord.fromJson(m)],
      production: [for (final m in list('production')) ProductionRecord.fromJson(m)],
      inventory: [for (final m in list('inventory')) InventoryItem.fromJson(m)],
      tasks: [for (final m in list('tasks')) FarmTask.fromJson(m)],
    );
  }
}
