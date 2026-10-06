import 'package:shared_preferences/shared_preferences.dart';

/// 저장소 추상화. 앱은 SharedPreferences, 테스트는 메모리 구현을 쓴다.
abstract class FarmStorage {
  Future<String?> read();
  Future<void> write(String json);

  /// 덮어쓰거나 읽을 수 없게 된 저장본을 지우지 않고 [label]을 붙여 따로 보관한다
  /// (손상본, 마이그레이션 전 원본, 백업 복원 전 데이터).
  Future<void> keepCopy(String raw, String label);

  /// 농장 데이터와 따로 두는 기기별 값(마지막 백업 시각 등). 백업 파일에 들어가지 않는다.
  Future<String?> readMeta(String key);
  Future<void> writeMeta(String key, String value);
}

class PrefsFarmStorage implements FarmStorage {
  /// 키 이름의 v1은 최초 키라는 뜻이며 저장 형식 버전과 무관하다. 바꾸면 기존 데이터를 못 읽는다.
  static const _key = 'farm_state_v1';

  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String json) async {
    final ok = await (await SharedPreferences.getInstance()).setString(_key, json);
    if (!ok) throw StateError('SharedPreferences.setString returned false');
  }

  /// 보관본은 최근 [maxCopies]개만 남긴다(하나에 수십 KB라 무한히 쌓이지 않게).
  static const maxCopies = 5;

  @override
  Future<void> keepCopy(String raw, String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_key}_${label}_${DateTime.now().millisecondsSinceEpoch}', raw);
    final copies = prefs.getKeys().where((k) => k.startsWith('${_key}_') && !k.startsWith('${_key}_meta_')).toList()
      ..sort((a, b) => _stamp(b).compareTo(_stamp(a)));
    for (final old in copies.skip(maxCopies)) {
      await prefs.remove(old);
    }
  }

  static int _stamp(String key) => int.tryParse(key.split('_').last) ?? 0;

  @override
  Future<String?> readMeta(String key) async => (await SharedPreferences.getInstance()).getString('${_key}_meta_$key');

  @override
  Future<void> writeMeta(String key, String value) async {
    await (await SharedPreferences.getInstance()).setString('${_key}_meta_$key', value);
  }
}
