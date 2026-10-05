import 'models.dart';

/// 급이 한 번에 실제로 차감한 사료량: 날짜 키 → 슬롯 → 재고 id → 양.
typedef FeedingUsage = Map<String, Map<int, Map<String, double>>>;

/// 앱이 저장하는 전체 상태. JSON 하나로 직렬화한다.
class FarmState {
  const FarmState({
    required this.profile,
    required this.fields,
    required this.animals,
    required this.animalEvents,
    required this.careItems,
    required this.feedingSlots,
    required this.feedingDone,
    required this.feedingUsage,
    required this.tankCapacityL,
    required this.tankStoredL,
    required this.waterLogs,
    required this.harvests,
    required this.production,
    required this.inventory,
    required this.tasks,
  });

  /// 저장 형식 버전.
  /// - 1: 최초 형식(v1.0.0~v1.1.0)
  /// - 2: 가축 이력(`animalEvents`)과 급이별 사료 차감량(`feedingUsage`) 추가(v1.2.0)
  /// - 3: 백신·진료 일정(`careItems`) 추가(v1.3.0)
  static const schemaVersion = 3;

  final FarmProfile profile;
  final List<CropField> fields;
  final List<Animal> animals;
  final List<AnimalEvent> animalEvents;
  final List<CareItem> careItems;
  final List<FeedingSlot> feedingSlots;

  /// 날짜 키(yyyy-MM-dd) → 완료한 급이 슬롯 인덱스.
  final Map<String, List<int>> feedingDone;
  final FeedingUsage feedingUsage;
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
    List<AnimalEvent>? animalEvents,
    List<CareItem>? careItems,
    Map<String, List<int>>? feedingDone,
    FeedingUsage? feedingUsage,
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
    animalEvents: animalEvents ?? this.animalEvents,
    careItems: careItems ?? this.careItems,
    feedingSlots: feedingSlots,
    feedingDone: feedingDone ?? this.feedingDone,
    feedingUsage: feedingUsage ?? this.feedingUsage,
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
    'animalEvents': [for (final e in animalEvents) e.toJson()],
    'careItems': [for (final c in careItems) c.toJson()],
    'feedingSlots': [for (final s in feedingSlots) s.toJson()],
    'feedingDone': feedingDone,
    'feedingUsage': {
      for (final day in feedingUsage.entries)
        day.key: {for (final slot in day.value.entries) '${slot.key}': slot.value},
    },
    'tankCapacityL': tankCapacityL,
    'tankStoredL': tankStoredL,
    'waterLogs': [for (final w in waterLogs) w.toJson()],
    'harvests': [for (final h in harvests) h.toJson()],
    'production': [for (final p in production) p.toJson()],
    'inventory': [for (final i in inventory) i.toJson()],
    'tasks': [for (final t in tasks) t.toJson()],
  };

  /// 이전 버전 저장본은 [migrate]로 올린 뒤 읽는다.
  /// 더 새로운 버전(새 앱에서 만든 백업 등)은 데이터를 잃지 않도록 거부한다.
  factory FarmState.fromJson(Map<String, Object?> raw) {
    final j = migrate(raw);
    List<Map<String, Object?>> list(String key) => [for (final e in j[key] as List) (e as Map).cast<String, Object?>()];
    final done = (j['feedingDone'] as Map).map((k, v) => MapEntry(k as String, [for (final i in v as List) i as int]));
    final usage = (j['feedingUsage'] as Map).map(
      (day, slots) => MapEntry(
        day as String,
        (slots as Map).map(
          (slot, items) => MapEntry(
            int.parse(slot as String),
            (items as Map).map((id, amount) => MapEntry(id as String, (amount as num).toDouble())),
          ),
        ),
      ),
    );
    return FarmState(
      profile: FarmProfile.fromJson((j['profile'] as Map).cast<String, Object?>()),
      fields: [for (final m in list('fields')) CropField.fromJson(m)],
      animals: [for (final m in list('animals')) Animal.fromJson(m)],
      animalEvents: [for (final m in list('animalEvents')) AnimalEvent.fromJson(m)],
      careItems: [for (final m in list('careItems')) CareItem.fromJson(m)],
      feedingSlots: [for (final m in list('feedingSlots')) FeedingSlot.fromJson(m)],
      feedingDone: done,
      feedingUsage: usage,
      tankCapacityL: (j['tankCapacityL'] as num).toDouble(),
      tankStoredL: (j['tankStoredL'] as num).toDouble(),
      waterLogs: [for (final m in list('waterLogs')) WaterLog.fromJson(m)],
      harvests: [for (final m in list('harvests')) HarvestRecord.fromJson(m)],
      production: [for (final m in list('production')) ProductionRecord.fromJson(m)],
      inventory: [for (final m in list('inventory')) InventoryItem.fromJson(m)],
      tasks: [for (final m in list('tasks')) FarmTask.fromJson(m)],
    );
  }

  /// 저장본 JSON을 현재 [schemaVersion]으로 올린다. 원본 맵은 바꾸지 않는다.
  static Map<String, Object?> migrate(Map<String, Object?> raw) {
    final version = raw['schemaVersion'];
    if (version is! int || version < 1) {
      throw FormatException('저장 형식 버전을 알 수 없습니다: $version');
    }
    if (version > schemaVersion) {
      throw FormatException('더 새로운 앱에서 만든 데이터입니다(형식 $version). 앱을 업데이트한 뒤 다시 시도하세요.');
    }
    final j = Map<String, Object?>.of(raw);
    if (version < 2) {
      // v1 → v2: 새 필드는 빈 값으로 시작한다. 기존 기록은 그대로 둔다.
      j['animalEvents'] = <Object?>[];
      j['feedingUsage'] = <String, Object?>{};
      j['schemaVersion'] = 2;
    }
    if ((j['schemaVersion'] as int) < 3) {
      // v2 → v3: 백신·진료 일정은 비어 있는 상태로 시작한다.
      j['careItems'] = <Object?>[];
      j['schemaVersion'] = 3;
    }
    return j;
  }
}
