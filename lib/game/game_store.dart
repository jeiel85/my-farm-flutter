import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../data/storage.dart';
import 'engine.dart';
import 'state.dart';

/// 게임 상태를 들고 시간을 진행시키고 저장한다. 화면은 이것만 본다.
class GameStore extends ChangeNotifier {
  GameStore._(this._storage, this._state, this._clock);

  /// 관리 앱 시절(v1~v4) 저장본을 두는 meta 키. 일반 보관본(최근 5개만 유지)과 달리 지우지 않는다.
  static const managementArchiveKey = 'management_archive';

  static Future<GameStore> load(
    FarmStorage storage, {
    DateTime Function()? clock,
    required String defaultFarmName,
  }) async {
    final now = clock ?? DateTime.now;
    final raw = await storage.read();
    GameState? state;
    var migrated = false;
    var recovered = false;
    if (raw != null) {
      try {
        final json = (jsonDecode(raw) as Map).cast<String, Object?>();
        // v5(정해진 구역 시절) 저장본은 부지(v6)로 옮겨 읽는다. 옮기기 전 원문을 따로 남긴다(docs/farm-lots-design.md §9).
        if (json['schemaVersion'] == 5) await storage.keepCopy(raw, 'before_v6');
        try {
          state = GameState.fromJson(json);
        } on UnsupportedGameSchema catch (e) {
          if (!e.legacy) rethrow;
          // 관리 앱 기록은 게임 수치로 바꿀 의미 있는 방법이 없다. 지우지 않고 보관하고 농장 이름만 잇는다.
          // 처음 보관한 원본은 덮어쓰지 않는다. 2.0 → 1.7로 낮췄다가 다시 올리면 1.7이 새로 만든 기록이 또 들어오는데,
          // 그때 원본을 잃지 않도록 두 번째부터는 일반 보관본으로 남긴다.
          if (await storage.readMeta(managementArchiveKey) == null) {
            await storage.writeMeta(managementArchiveKey, raw);
          } else {
            await storage.keepCopy(raw, 'management_again');
          }
          final profile = json['profile'];
          final name = profile is Map && profile['name'] is String ? profile['name'] as String : defaultFarmName;
          state = GameEngine.newGame(now(), farmName: name.trim().isEmpty ? defaultFarmName : name);
          migrated = true;
        }
      } catch (e) {
        debugPrint('Could not read saved game: $e');
        // 더 새로운 앱에서 만든 저장본(앱을 낮춘 경우)도 지우지 않고 따로 남긴다.
        await storage.keepCopy(raw, e is UnsupportedGameSchema && e.newer ? 'newer_v${e.version}' : 'corrupt');
        recovered = true;
      }
    }
    final store = GameStore._(storage, state ?? GameEngine.newGame(now(), farmName: defaultFarmName), now)
      ..migratedFromManagement = migrated
      ..recoveredFromCorruptData = recovered;
    final savedLocale = await storage.readMeta('locale');
    store.locale.value = savedLocale == null || savedLocale.isEmpty ? null : savedLocale;
    store._lastBackupAt = DateTime.tryParse(await storage.readMeta('last_backup') ?? '');
    store._catchUp();
    await store._persist();
    return store;
  }

  final FarmStorage _storage;
  final DateTime Function() _clock;
  GameState _state;

  GameState get state => _state;
  DateTime get now => _clock();

  /// 이번 실행에서 관리 앱 기록을 보관하고 새 게임을 시작했다(시작할 때 한 번 알린다).
  bool migratedFromManagement = false;

  /// 저장본을 읽지 못해 새 게임으로 시작했다(원본은 보관본으로 남는다).
  bool recoveredFromCorruptData = false;

  /// 앱을 다시 열었을 때 자리 비운 동안 일어난 일. 화면이 보여 준 뒤 [dismissReport]로 지운다.
  AdvanceReport? awayReport;

  /// 마지막 저장 실패 원인. 성공하면 null로 돌아간다.
  Object? saveError;

  /// 앞으로 일어날 일의 시각이나 알림 문구가 달라질 수 있는 변경(행동·복원·새로 시작·오프라인 진행·언어) 횟수.
  /// 매초 [tick]은 예정 시각을 바꾸지 않으므로 세지 않는다. 알림 예약이 이 값이 바뀔 때만 다시 계산한다.
  int revision = 0;

  /// 사용자가 고른 언어 코드(ko, en). null이면 기기 언어를 따른다. 앱 루트가 이 값만 따로 듣는다.
  final locale = ValueNotifier<String?>(null);

  String? get localeOverride => locale.value;

  Future<void> setLocaleOverride(String? code) async {
    locale.value = code;
    // 예약해 둔 알림 문구도 새 언어로 다시 만들어야 하므로 알림 예약(revision을 보는 쪽)에 알린다(#32 리뷰).
    revision++;
    notifyListeners();
    await _storage.writeMeta('locale', code ?? '');
  }

  DateTime? _lastBackupAt;
  DateTime? get lastBackupAt => _lastBackupAt;

  Future<void> markBackedUp() async {
    _lastBackupAt = now;
    notifyListeners();
    await _storage.writeMeta('last_backup', _lastBackupAt!.toIso8601String());
  }

  Future<void> rename(String farmName) async {
    final name = farmName.trim();
    if (name.isEmpty) throw ArgumentError.value(farmName, 'farmName', 'must not be empty');
    _state = _state.copyWith(farmName: name);
    notifyListeners();
    await _persist();
  }

  static const backupFormat = 'my-farm-backup';

  /// 현재 게임을 백업 파일 내용(JSON 문자열)으로 만든다. 1.x 백업과 같은 껍데기에 v5 상태를 담는다.
  String exportBackup() =>
      const JsonEncoder.withIndent('  ')
          .convert({'format': backupFormat, 'exportedAt': now.toIso8601String(), 'state': _state.toJson()});

  /// 보관한 관리 앱 기록을 1.7.x 앱에서 복원할 수 있는 백업 파일 내용으로. 없으면 null.
  Future<String?> exportManagementArchive() async {
    final raw = await managementArchive();
    if (raw == null) return null;
    return const JsonEncoder.withIndent('  ')
        .convert({'format': backupFormat, 'exportedAt': now.toIso8601String(), 'state': jsonDecode(raw)});
  }

  /// 백업 파일 내용을 검사해 복원할 게임을 돌려준다. 맞지 않으면 [BackupException].
  static BackupContents parseBackup(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const BackupException(BackupProblem.notJson);
    }
    if (decoded is! Map || decoded['format'] != backupFormat || decoded['state'] is! Map) {
      throw const BackupException(BackupProblem.notBackup);
    }
    final GameState state;
    try {
      state = GameState.fromJson((decoded['state'] as Map).cast<String, Object?>());
    } on UnsupportedGameSchema catch (e) {
      throw BackupException(
        e.legacy
            ? BackupProblem.managementApp
            : e.newer
            ? BackupProblem.newerVersion
            : BackupProblem.damaged,
      );
    } catch (_) {
      throw const BackupException(BackupProblem.damaged);
    }
    return BackupContents(state: state, exportedAt: DateTime.tryParse('${decoded['exportedAt']}'));
  }

  /// 백업으로 덮어쓴다. 덮어쓰기 전 게임은 보관본으로 남긴다. 백업 뒤 흐른 시간은 오프라인 진행으로 계산한다.
  Future<void> restoreBackup(GameState restored) async {
    await _storage.keepCopy(jsonEncode(_state.toJson()), 'before_restore');
    _state = restored;
    awayReport = null;
    revision++;
    _catchUp();
    notifyListeners();
    await _persist();
  }

  void dismissReport() {
    awayReport = null;
    notifyListeners();
  }

  void dismissLoadNotice() {
    migratedFromManagement = false;
    recoveredFromCorruptData = false;
    notifyListeners();
  }

  /// 앱을 열었거나 다시 앞으로 왔을 때. 오래 비웠으면 요약을 남긴다.
  Future<void> resume() async {
    revision++;
    _catchUp();
    await _persist();
    notifyListeners();
  }

  void _catchUp() {
    final (next, report) = GameEngine.advance(_state, now);
    _state = next;
    // 몇 분 비운 정도는 요약할 일이 없다.
    if (report.minutes >= 5 && report.eventful) awayReport = report;
  }

  /// 앱이 켜져 있는 동안 매초 부른다. 남은 시간이 초 단위로 줄어 보이게 매번 알리고, 저장은 분이 바뀌었을 때만 한다.
  Future<void> tick() async {
    final (next, _) = GameEngine.advance(_state, now);
    final changed = !identical(next, _state);
    _state = next;
    notifyListeners();
    if (changed) await _persist();
  }

  /// 지금까지 진행한 뒤 [action]을 적용한다. 할 수 없으면 [GameException]이 그대로 올라간다(상태는 그대로).
  Future<void> act(GameState Function(GameState s) action) async {
    final (current, _) = GameEngine.advance(_state, now);
    final next = action(current);
    _state = next;
    revision++;
    notifyListeners();
    await _persist();
  }

  /// [act]처럼 적용하고 행동의 결과값도 돌려준다(짜기·줍기 개수 등).
  Future<R> actWith<R>((GameState, R) Function(GameState s) action) async {
    final (current, _) = GameEngine.advance(_state, now);
    final (next, result) = action(current);
    _state = next;
    revision++;
    notifyListeners();
    await _persist();
    return result;
  }

  /// 새로 시작한다. 지금 게임은 지우지 않고 보관본으로 남긴다.
  Future<void> restart({required String farmName}) async {
    await _storage.keepCopy(jsonEncode(_state.toJson()), 'before_restart');
    _state = GameEngine.newGame(now, farmName: farmName);
    awayReport = null;
    revision++;
    notifyListeners();
    await _persist();
  }

  /// 보관해 둔 관리 앱 기록(없으면 null). 설정에서 백업 파일로 내보낼 수 있게 한다.
  Future<String?> managementArchive() => _storage.readMeta(managementArchiveKey);

  Future<void> _persist() async {
    try {
      await _storage.write(jsonEncode(_state.toJson()));
      if (saveError != null) {
        saveError = null;
        notifyListeners();
      }
    } catch (e) {
      saveError = e;
      notifyListeners();
    }
  }
}

enum BackupProblem { notJson, notBackup, damaged, newerVersion, managementApp }

class BackupException implements Exception {
  const BackupException(this.problem);
  final BackupProblem problem;
  @override
  String toString() => 'BackupException($problem)';
}

class BackupContents {
  const BackupContents({required this.state, required this.exportedAt});

  final GameState state;
  final DateTime? exportedAt;
}

/// 위젯 트리에 [GameStore]를 내려주고 바뀌면 다시 그린다.
class GameScope extends InheritedNotifier<GameStore> {
  const GameScope({super.key, required GameStore store, required super.child}) : super(notifier: store);

  static GameStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<GameScope>()!.notifier!;

  /// 다시 그리기를 구독하지 않고 동작만 부를 때.
  static GameStore read(BuildContext context) => context.getInheritedWidgetOfExactType<GameScope>()!.notifier!;
}
