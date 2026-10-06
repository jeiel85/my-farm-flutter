import 'package:my_farm/data/storage.dart';

/// 테스트용 메모리 저장소.
class MemoryStorage implements FarmStorage {
  MemoryStorage([this.value]);

  String? value;

  /// keepCopy로 따로 보관된 (라벨, 내용) 목록.
  final copies = <(String, String)>[];

  List<String> copiesLabeled(String label) => [
    for (final (l, raw) in copies)
      if (l == label) raw,
  ];
  bool failWrites = false;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async {
    if (failWrites) throw StateError('disk full');
    value = json;
  }

  @override
  Future<void> keepCopy(String raw, String label) async => copies.add((label, raw));

  final meta = <String, String>{};

  @override
  Future<String?> readMeta(String key) async => meta[key];

  @override
  Future<void> writeMeta(String key, String value) async => meta[key] = value;
}
