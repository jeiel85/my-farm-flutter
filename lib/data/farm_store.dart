import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'farm_state.dart';
import 'models.dart';
import 'seed.dart';

/// 저장소 추상화. 앱은 SharedPreferences, 테스트는 메모리 구현을 쓴다.
abstract class FarmStorage {
  Future<String?> read();
  Future<void> write(String json);

  /// 덮어쓰거나 읽을 수 없게 된 저장본을 지우지 않고 [label]을 붙여 따로 보관한다
  /// (손상본, 마이그레이션 전 원본, 백업 복원 전 데이터).
  Future<void> keepCopy(String raw, String label);
}

class PrefsFarmStorage implements FarmStorage {
  /// 키 이름의 v1은 최초 키라는 뜻이며 저장 형식 버전과 무관하다. 바꾸면 기존 데이터를 못 읽는다.
  static const _key = 'farm_state_v1';

  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String json) async {
    final ok = await (await SharedPreferences.getInstance()).setString(_key, json);
    if (!ok) throw StateError('저장 공간에 기록하지 못했습니다.');
  }

  @override
  Future<void> keepCopy(String raw, String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_key}_${label}_${DateTime.now().millisecondsSinceEpoch}', raw);
  }
}

class FarmStore extends ChangeNotifier {
  FarmStore._(this._storage, this._state, this._clock, this.loadNotice);

  static Future<FarmStore> load(FarmStorage storage, {DateTime Function()? clock}) async {
    final now = clock ?? DateTime.now;
    final raw = await storage.read();
    if (raw == null) {
      final store = FarmStore._(storage, buildDemoFarm(now()), now, null);
      await store._persist();
      return store;
    }
    try {
      final json = (jsonDecode(raw) as Map).cast<String, Object?>();
      final state = FarmState.fromJson(json);
      final store = FarmStore._(storage, state, now, null);
      final version = json['schemaVersion'];
      if (version != FarmState.schemaVersion) {
        // 이전 형식이면 원본을 남겨 두고 새 형식으로 다시 저장한다.
        await storage.keepCopy(raw, 'pre_migration_v$version');
        await store._persist();
      }
      return store;
    } catch (e) {
      debugPrint('저장된 농장 데이터를 읽지 못함: $e');
      await storage.keepCopy(raw, 'corrupt');
      final store = FarmStore._(
        storage,
        buildDemoFarm(now()),
        now,
        '저장된 데이터를 읽지 못해 예시 농장으로 시작했습니다. 이전 데이터는 별도로 보관했습니다.',
      );
      await store._persist();
      return store;
    }
  }

  final FarmStorage _storage;
  final DateTime Function() _clock;
  FarmState _state;

  /// 시작 시 사용자에게 알릴 내용(손상된 저장본 복구 등).
  String? loadNotice;

  /// 마지막 저장 실패 메시지. 성공하면 null로 돌아간다.
  String? saveError;

  FarmState get state => _state;
  DateTime get now => _clock();
  String get todayKey => dateKeyOf(now);

  Future<void> _commit(FarmState next) async {
    _state = next;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await _storage.write(jsonEncode(_state.toJson()));
      if (saveError != null) {
        saveError = null;
        notifyListeners();
      }
    } catch (e) {
      saveError = '변경 내용을 저장하지 못했습니다: $e';
      notifyListeners();
    }
  }

  void dismissLoadNotice() {
    loadNotice = null;
    notifyListeners();
  }

  // ---------- 가축 ----------

  int get totalAnimals => _state.animals.length;

  int countOf(AnimalKind kind) => _state.animals.where((a) => a.kind == kind).length;

  List<Animal> animalsOf(AnimalKind kind) => _state.animals.where((a) => a.kind == kind).toList();

  Animal? animalById(String id) {
    for (final a in _state.animals) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// 전체 가축 평균 건강 점수(0~1).
  double get herdHealth {
    if (_state.animals.isEmpty) return 0;
    return _state.animals.fold<int>(0, (s, a) => s + a.health) / _state.animals.length / 100;
  }

  int get animalsNeedingCare => _state.animals.where((a) => a.health < 80).length;

  Future<void> updateAnimal(Animal updated) =>
      _commit(_state.copyWith(animals: [for (final a in _state.animals) a.id == updated.id ? updated : a]));

  /// 종류별 다음 개체 번호표. 현재 개체와 이력에 쓰인 번호 중 가장 큰 값 다음 번호.
  String nextTag(AnimalKind kind) {
    var max = 0;
    final tags = [
      for (final a in _state.animals)
        if (a.kind == kind) a.tag,
      for (final e in _state.animalEvents)
        if (e.kind == kind) e.tag,
    ];
    for (final tag in tags) {
      final n = int.tryParse(tag.split('-').last) ?? 0;
      if (n > max) max = n;
    }
    return '${kind.tagPrefix}-${(max + 1).toString().padLeft(3, '0')}';
  }

  /// 새 가축을 들인다(입식 이력도 함께 남긴다).
  Future<Animal> addAnimal({
    required AnimalKind kind,
    required String name,
    required String breed,
    required DateTime birthDate,
    required double weightKg,
    int health = 90,
    String note = '',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('이름을 입력하세요.');
    if (weightKg <= 0) throw ArgumentError('체중은 0보다 커야 합니다.');
    final at = now;
    final animal = Animal(
      id: '${kind.name}-${at.microsecondsSinceEpoch}',
      kind: kind,
      tag: nextTag(kind),
      name: trimmed,
      breed: breed.trim().isEmpty ? '미상' : breed.trim(),
      birthDate: birthDate,
      health: health.clamp(0, 100),
      weightKg: weightKg,
      lastCheckup: null,
      note: note.trim(),
    );
    await _commit(
      _state.copyWith(
        animals: [..._state.animals, animal],
        animalEvents: [
          AnimalEvent(
            id: 'e${at.microsecondsSinceEpoch}',
            type: AnimalEventType.added,
            kind: kind,
            tag: animal.tag,
            name: animal.name,
            date: at,
            note: note.trim(),
          ),
          ..._state.animalEvents,
        ],
      ),
    );
    return animal;
  }

  /// 출하·폐사 등으로 목록에서 뺀다. 개체 정보는 이력으로 남는다.
  Future<void> removeAnimal(String id, {required AnimalEventType type, String note = ''}) {
    if (type == AnimalEventType.added) throw ArgumentError('입식은 제외 사유가 아닙니다.');
    final animal = animalById(id);
    if (animal == null) throw StateError('가축을 찾을 수 없습니다.');
    final at = now;
    return _commit(
      _state.copyWith(
        animals: _state.animals.where((a) => a.id != id).toList(),
        animalEvents: [
          AnimalEvent(
            id: 'e${at.microsecondsSinceEpoch}',
            type: type,
            kind: animal.kind,
            tag: animal.tag,
            name: animal.name,
            date: at,
            note: note.trim(),
          ),
          ..._state.animalEvents,
        ],
      ),
    );
  }

  // ---------- 급이 ----------

  Set<int> get feedingDoneToday => {...?_state.feedingDone[todayKey]};

  /// 다음 미완료 급이 슬롯. 오늘 모두 끝났으면 null.
  FeedingSlot? get nextFeeding {
    final done = feedingDoneToday;
    for (var i = 0; i < _state.feedingSlots.length; i++) {
      if (!done.contains(i)) return _state.feedingSlots[i];
    }
    return null;
  }

  /// 급이 완료를 토글한다.
  ///
  /// 완료로 바꾸면 하루 소비량이 있는 사료마다 `하루 사용량 ÷ 하루 급이 횟수`만큼 재고에서 빼고,
  /// 실제로 뺀 양을 기록해 둔다(재고가 모자라면 남은 만큼만 뺀다).
  /// 완료를 취소하면 기록해 둔 양만큼 되돌린다.
  /// 반환값은 모자랐던 사료 이름 목록이다.
  Future<List<String>> toggleFeeding(int slot) async {
    final key = todayKey;
    final done = feedingDoneToday;
    final todayUsage = {...?_state.feedingUsage[key]};
    var inventory = _state.inventory;
    final shortages = <String>[];

    if (done.contains(slot)) {
      done.remove(slot);
      final used = todayUsage.remove(slot) ?? const <String, double>{};
      inventory = [
        for (final i in inventory) used.containsKey(i.id) ? i.copyWith(quantity: i.quantity + used[i.id]!) : i,
      ];
    } else {
      done.add(slot);
      final perDay = _state.feedingSlots.isEmpty ? 1 : _state.feedingSlots.length;
      final used = <String, double>{};
      final next = <InventoryItem>[];
      for (final i in inventory) {
        if (i.category != InventoryCategory.feed || i.dailyUse <= 0) {
          next.add(i);
          continue;
        }
        final want = i.dailyUse / perDay;
        final take = want <= i.quantity ? want : i.quantity;
        if (take < want) shortages.add(i.name);
        if (take > 0) used[i.id] = take;
        next.add(i.copyWith(quantity: i.quantity - take));
      }
      inventory = next;
      todayUsage[slot] = used;
    }

    // 급이 기록은 30일까지만 유지한다.
    final cutoff = dateKeyOf(now.subtract(const Duration(days: 30)));
    bool keep(String day) => day.compareTo(cutoff) >= 0;
    await _commit(
      _state.copyWith(
        feedingDone: {
          for (final e in _state.feedingDone.entries)
            if (keep(e.key)) e.key: e.value,
          key: (done.toList()..sort()),
        },
        feedingUsage: {
          for (final e in _state.feedingUsage.entries)
            if (keep(e.key)) e.key: e.value,
          key: todayUsage,
        },
        inventory: inventory,
      ),
    );
    return shortages;
  }

  /// 사료 재고로 버틸 수 있는 일수(하루 소비량이 있는 사료 기준).
  double? get feedDaysLeft {
    final feeds = _state.inventory.where((i) => i.category == InventoryCategory.feed && i.dailyUse > 0);
    if (feeds.isEmpty) return null;
    return feeds.map((i) => i.daysLeft!).reduce((a, b) => a < b ? a : b);
  }

  static const feedTargetDays = 16.0;

  // ---------- 생산 ----------

  ProductionRecord? get todayProduction {
    for (final p in _state.production) {
      if (p.dateKey == todayKey) return p;
    }
    return null;
  }

  ProductionRecord? get latestProduction {
    if (_state.production.isEmpty) return null;
    return _state.production.reduce((a, b) => a.dateKey.compareTo(b.dateKey) >= 0 ? a : b);
  }

  /// 가장 최근 기록 기준 목표 대비 생산 달성률(0~1).
  double? get productionRatio {
    final p = latestProduction;
    if (p == null) return null;
    final eggs = p.eggs / _state.profile.dailyEggTarget;
    final milk = p.milkL / _state.profile.dailyMilkTargetL;
    return ((eggs + milk) / 2).clamp(0.0, 1.0);
  }

  Future<void> recordProduction({required int eggs, required double milkL}) {
    final key = todayKey;
    final list = [
      for (final p in _state.production)
        if (p.dateKey != key) p,
      ProductionRecord(dateKey: key, eggs: eggs, milkL: milkL),
    ]..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return _commit(_state.copyWith(production: list));
  }

  /// 최근 [days]일 생산 기록(기록 없는 날은 null).
  List<(DateTime, ProductionRecord?)> productionSeries(int days) {
    final today = DateTime(now.year, now.month, now.day);
    final byKey = {for (final p in _state.production) p.dateKey: p};
    return [
      for (var i = days - 1; i >= 0; i--)
        (today.subtract(Duration(days: i)), byKey[dateKeyOf(today.subtract(Duration(days: i)))]),
    ];
  }

  // ---------- 밭·물 ----------

  CropField? fieldFor(ZoneId zone) {
    for (final f in _state.fields) {
      if (f.zone == zone) return f;
    }
    return null;
  }

  CropField? fieldById(String id) {
    for (final f in _state.fields) {
      if (f.id == id) return f;
    }
    return null;
  }

  double get tankRatio => (_state.tankStoredL / _state.tankCapacityL).clamp(0.0, 1.0);

  double get waterUsedToday =>
      _state.waterLogs.where((w) => w.liters > 0 && dateKeyOf(w.at) == todayKey).fold(0.0, (s, w) => s + w.liters);

  /// 가장 이른 다음 물주기 시각.
  DateTime? get nextWatering {
    if (_state.fields.isEmpty) return null;
    return _state.fields.map((f) => f.nextWateringAt).reduce((a, b) => a.isBefore(b) ? a : b);
  }

  List<CropField> get fieldsNeedingWater => _state.fields.where((f) => f.needsWater(now)).toList();

  /// 밭에 물을 준다. 물탱크가 부족하면 [StateError].
  Future<void> waterField(String id) {
    final field = fieldById(id);
    if (field == null) throw StateError('밭을 찾을 수 없습니다.');
    if (_state.tankStoredL < field.litersPerWatering) {
      throw StateError('물탱크 잔량(${_state.tankStoredL.round()}L)이 부족합니다. 먼저 물을 보충하세요.');
    }
    final at = now;
    return _commit(
      _state.copyWith(
        fields: [for (final f in _state.fields) f.id == id ? f.copyWith(lastWateredAt: at) : f],
        tankStoredL: _state.tankStoredL - field.litersPerWatering,
        waterLogs: _trimLogs([
          ..._state.waterLogs,
          WaterLog(at: at, liters: field.litersPerWatering, note: '${field.cropName} 관수'),
        ]),
      ),
    );
  }

  /// 스마트 관수: 2시간 안에 물주기가 돌아오는 밭에 물탱크 잔량이 허락하는 만큼 물을 준다.
  /// 반환값은 (물 준 밭 수, 물이 부족해 건너뛴 밭 수).
  Future<(int, int)> smartWatering() async {
    final at = now;
    final soon = at.add(const Duration(hours: 2));
    final due = _state.fields.where((f) => !f.nextWateringAt.isAfter(soon)).toList()
      ..sort((a, b) => a.nextWateringAt.compareTo(b.nextWateringAt));
    var stored = _state.tankStoredL;
    final watered = <String>{};
    final logs = [..._state.waterLogs];
    var skipped = 0;
    for (final f in due) {
      if (stored < f.litersPerWatering) {
        skipped++;
        continue;
      }
      stored -= f.litersPerWatering;
      watered.add(f.id);
      logs.add(WaterLog(at: at, liters: f.litersPerWatering, note: '${f.cropName} 스마트 관수'));
    }
    if (watered.isNotEmpty) {
      await _commit(
        _state.copyWith(
          fields: [for (final f in _state.fields) watered.contains(f.id) ? f.copyWith(lastWateredAt: at) : f],
          tankStoredL: stored,
          waterLogs: _trimLogs(logs),
        ),
      );
    }
    return (watered.length, skipped);
  }

  Future<void> refillTank() {
    final amount = _state.tankCapacityL - _state.tankStoredL;
    if (amount <= 0) return Future.value();
    return _commit(
      _state.copyWith(
        tankStoredL: _state.tankCapacityL,
        waterLogs: _trimLogs([..._state.waterLogs, WaterLog(at: now, liters: -amount, note: '물탱크 보충')]),
      ),
    );
  }

  List<WaterLog> _trimLogs(List<WaterLog> logs) {
    final cutoff = now.subtract(const Duration(days: 60));
    return logs.where((w) => w.at.isAfter(cutoff)).toList();
  }

  /// 최근 [days]일 일별 물 사용량(L).
  List<(DateTime, double)> waterSeries(int days) {
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final day = today.subtract(Duration(days: i));
          final key = dateKeyOf(day);
          final used = _state.waterLogs
              .where((w) => w.liters > 0 && dateKeyOf(w.at) == key)
              .fold(0.0, (s, w) => s + w.liters);
          return (day, used);
        }(),
    ];
  }

  Future<void> setFieldStatus(String id, CropStatus status) =>
      _commit(_state.copyWith(fields: [for (final f in _state.fields) f.id == id ? f.copyWith(status: status) : f]));

  /// 수확을 기록한다. [replant]이면 같은 밭에 오늘 날짜로 다시 심는다.
  Future<void> harvest({required String fieldId, required double amountKg, required bool replant, String note = ''}) {
    final field = fieldById(fieldId);
    if (field == null) throw StateError('밭을 찾을 수 없습니다.');
    final record = HarvestRecord(
      id: 'h${now.microsecondsSinceEpoch}',
      cropName: field.cropName,
      emoji: field.emoji,
      amountKg: amountKg,
      date: now,
      note: note,
    );
    return _commit(
      _state.copyWith(
        harvests: [record, ..._state.harvests],
        fields: replant
            ? [for (final f in _state.fields) f.id == fieldId ? f.copyWith(plantedAt: now, status: CropStatus.good) : f]
            : null,
      ),
    );
  }

  Future<void> deleteHarvest(String id) =>
      _commit(_state.copyWith(harvests: _state.harvests.where((h) => h.id != id).toList()));

  /// 작물별 누적 수확량(kg), 많은 순.
  List<(String, String, double)> harvestTotals() {
    final totals = <String, (String, double)>{};
    for (final h in _state.harvests) {
      final cur = totals[h.cropName];
      totals[h.cropName] = (h.emoji, (cur?.$2 ?? 0) + h.amountKg);
    }
    final list = [for (final e in totals.entries) (e.key, e.value.$1, e.value.$2)];
    list.sort((a, b) => b.$3.compareTo(a.$3));
    return list;
  }

  double harvestSince(DateTime from) =>
      _state.harvests.where((h) => !h.date.isBefore(from)).fold(0.0, (s, h) => s + h.amountKg);

  // ---------- 재고 ----------

  List<InventoryItem> get lowInventory => _state.inventory.where((i) => i.isLow).toList();

  Future<void> adjustInventory(String id, double delta) => _commit(
    _state.copyWith(
      inventory: [
        for (final i in _state.inventory)
          i.id == id ? i.copyWith(quantity: (i.quantity + delta).clamp(0, double.infinity).toDouble()) : i,
      ],
    ),
  );

  // ---------- 작업 ----------

  List<FarmTask> get tasksToday => _state.tasks.where((t) => t.dateKey == todayKey).toList();

  /// 지난 날짜의 미완료 작업(이월 표시용).
  List<FarmTask> get overdueTasks => _state.tasks.where((t) => !t.done && t.dateKey.compareTo(todayKey) < 0).toList();

  Future<void> addTask(String title, {ZoneId? zone}) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return Future.value();
    return _commit(
      _state.copyWith(
        tasks: [
          ..._state.tasks,
          FarmTask(id: 't${now.microsecondsSinceEpoch}', title: trimmed, dateKey: todayKey, done: false, zone: zone),
        ],
      ),
    );
  }

  Future<void> toggleTask(String id) =>
      _commit(_state.copyWith(tasks: [for (final t in _state.tasks) t.id == id ? t.copyWith(done: !t.done) : t]));

  Future<void> deleteTask(String id) => _commit(_state.copyWith(tasks: _state.tasks.where((t) => t.id != id).toList()));

  // ---------- 농장 정보 ----------

  Future<void> updateProfile(FarmProfile profile) => _commit(_state.copyWith(profile: profile));

  Future<void> resetToDemo() => _commit(buildDemoFarm(now));

  // ---------- 백업 ----------

  static const backupFormat = 'my-farm-backup';

  /// 현재 데이터를 백업 파일 내용(JSON 문자열)으로 만든다.
  String exportBackup() =>
      const JsonEncoder.withIndent('  ')
          .convert({'format': backupFormat, 'exportedAt': now.toIso8601String(), 'state': _state.toJson()});

  /// 백업 파일 내용을 검사해 복원할 상태를 돌려준다. 형식이 맞지 않으면 [FormatException].
  static BackupContents parseBackup(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('JSON 파일이 아닙니다.');
    }
    if (decoded is! Map || decoded['format'] != backupFormat || decoded['state'] is! Map) {
      throw const FormatException('마이팜 백업 파일이 아닙니다.');
    }
    final FarmState state;
    try {
      state = FarmState.fromJson((decoded['state'] as Map).cast<String, Object?>());
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('백업 파일 내용이 손상되었습니다.');
    }
    return BackupContents(state: state, exportedAt: DateTime.tryParse('${decoded['exportedAt']}'));
  }

  /// 백업으로 덮어쓴다. 덮어쓰기 전 데이터는 지우지 않고 따로 보관한다.
  Future<void> restoreBackup(FarmState restored) async {
    await _storage.keepCopy(jsonEncode(_state.toJson()), 'before_restore');
    await _commit(restored);
  }
}

class BackupContents {
  const BackupContents({required this.state, required this.exportedAt});

  final FarmState state;
  final DateTime? exportedAt;
}

/// 위젯 트리에 [FarmStore]를 내려주고 변경 시 다시 그린다.
class FarmScope extends InheritedNotifier<FarmStore> {
  const FarmScope({super.key, required FarmStore store, required super.child}) : super(notifier: store);

  static FarmStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FarmScope>()!.notifier!;

  /// 리빌드 구독 없이 동작만 호출할 때.
  static FarmStore read(BuildContext context) => context.getInheritedWidgetOfExactType<FarmScope>()!.notifier!;
}
