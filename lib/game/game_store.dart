import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/farm_store.dart' show FarmStorage;
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
        try {
          state = GameState.fromJson(json);
        } on UnsupportedGameSchema catch (e) {
          if (!e.legacy) rethrow;
          // 관리 앱 기록은 게임 수치로 바꿀 의미 있는 방법이 없다. 지우지 않고 보관하고 농장 이름만 잇는다.
          await storage.writeMeta(managementArchiveKey, raw);
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

  /// 앱이 켜져 있는 동안 주기적으로 부른다(분이 바뀌었을 때만 저장한다).
  Future<void> tick() async {
    final (next, _) = GameEngine.advance(_state, now);
    if (identical(next, _state)) return;
    _state = next;
    notifyListeners();
    await _persist();
  }

  /// 지금까지 진행한 뒤 [action]을 적용한다. 할 수 없으면 [GameException]이 그대로 올라간다(상태는 그대로).
  Future<void> act(GameState Function(GameState s) action) async {
    final (current, _) = GameEngine.advance(_state, now);
    final next = action(current);
    _state = next;
    notifyListeners();
    await _persist();
  }

  /// [act]처럼 적용하고 행동의 결과값도 돌려준다(짜기·줍기 개수 등).
  Future<R> actWith<R>((GameState, R) Function(GameState s) action) async {
    final (current, _) = GameEngine.advance(_state, now);
    final (next, result) = action(current);
    _state = next;
    notifyListeners();
    await _persist();
    return result;
  }

  /// 새로 시작한다. 지금 게임은 지우지 않고 보관본으로 남긴다.
  Future<void> restart({required String farmName}) async {
    await _storage.keepCopy(jsonEncode(_state.toJson()), 'before_restart');
    _state = GameEngine.newGame(now, farmName: farmName);
    awayReport = null;
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
