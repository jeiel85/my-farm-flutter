import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_farm/data/app_update.dart';
import 'package:my_farm/data/storage.dart';

class MetaStorage implements FarmStorage {
  final meta = <String, String>{};

  @override
  Future<String?> readMeta(String key) async => meta[key];

  @override
  Future<void> writeMeta(String key, String value) async => meta[key] = value;

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String json) async {}

  @override
  Future<void> keepCopy(String raw, String label) async {}
}

class FakePlatform implements UpdatePlatform {
  FakePlatform(this.cacheDir);

  final String cacheDir;
  bool installAllowed = true;

  /// sha256()가 돌려줄 값. null이면 manifest와 다른 값.
  String? hash;
  final installed = <String>[];
  int hashCalls = 0;

  @override
  Future<AppBuildInfo> info() async =>
      AppBuildInfo(versionCode: 7, versionName: '1.6.0', sdkInt: 34, cacheDir: cacheDir);

  @override
  Future<bool> canInstall() async => installAllowed;

  @override
  Future<void> openInstallSettings() async {}

  @override
  Future<String> sha256(String path) async {
    hashCalls++;
    return hash ?? '0' * 64;
  }

  @override
  Future<void> install(String path) async => installed.add(path);

  @override
  Future<void> openUrl(String url) async {}
}

void main() {
  final sha = 'AB' * 32;
  Map<String, Object?> manifestJson({
    int versionCode = 8,
    int size = 5,
    String apkUrl = 'https://example.test/a.apk',
  }) => {
    'versionCode': versionCode,
    'versionName': '1.7.0',
    'apkUrl': apkUrl,
    'apkSizeBytes': size,
    'sha256': sha,
    'minSdk': 24,
    'releaseNotesUrl': 'https://github.com/jeiel85/my-farm-flutter/releases/tag/v1.7.0',
  };

  group('update.json 읽기', () {
    test('일곱 키가 모두 맞으면 읽고 해시는 소문자로 맞춘다', () {
      final m = UpdateManifest.parse(jsonEncode(manifestJson()))!;
      expect((m.versionCode, m.versionName, m.apkSizeBytes, m.minSdk), (8, '1.7.0', 5, 24));
      expect(m.sha256, 'ab' * 32);
    });

    test('키가 빠지거나 형식이 틀리면 전체를 버린다', () {
      final bad = <Map<String, Object?>>[
        {...manifestJson()}..remove('sha256'),
        {...manifestJson(), 'apkUrl': 'http://example.test/a.apk'},
        {...manifestJson(), 'releaseNotesUrl': 'file:///x'},
        {...manifestJson(), 'sha256': 'xyz'},
        {...manifestJson(), 'versionCode': '8'},
        {...manifestJson(), 'versionCode': 0},
        {...manifestJson(), 'apkSizeBytes': -1},
      ];
      for (final j in bad) {
        expect(UpdateManifest.parse(jsonEncode(j)), isNull, reason: '$j');
      }
      expect(UpdateManifest.parse('not json'), isNull);
      expect(UpdateManifest.parse('[]'), isNull);
      expect(UpdateManifest.parse(''), isNull);
    });
  });

  test('확인은 하루에 한 번, 시계가 뒤로 가면 다시 한다', () {
    final now = DateTime(2026, 10, 6, 12);
    expect(shouldCheckUpdateNow(null, now), isTrue);
    expect(shouldCheckUpdateNow(now.subtract(const Duration(hours: 23)), now), isFalse);
    expect(shouldCheckUpdateNow(now.subtract(const Duration(days: 1)), now), isTrue);
    expect(shouldCheckUpdateNow(now.add(const Duration(hours: 1)), now), isTrue);
  });

  test('versionCode가 더 크고, 건너뛰지 않았고, 기기가 minSdk 이상일 때만 권한다', () {
    final m = UpdateManifest.parse(jsonEncode(manifestJson()))!;
    expect(shouldOfferUpdate(m, installed: 7, skipped: null, sdk: 34), isTrue);
    expect(shouldOfferUpdate(m, installed: 8, skipped: null, sdk: 34), isFalse);
    expect(shouldOfferUpdate(m, installed: 7, skipped: 8, sdk: 34), isFalse);
    expect(shouldOfferUpdate(m, installed: 7, skipped: null, sdk: 23), isFalse);
  });

  group('UpdateController', () {
    late Directory cache;
    late MetaStorage storage;
    late FakePlatform platform;
    var now = DateTime(2026, 10, 6, 9);
    late List<Uri> requests;
    var manifestBody = jsonEncode(manifestJson());
    var manifestStatus = 200;
    var apkBytes = <int>[1, 2, 3, 4, 5];

    setUp(() async {
      cache = await Directory.systemTemp.createTemp('my_farm_update_');
      storage = MetaStorage();
      platform = FakePlatform(cache.path);
      now = DateTime(2026, 10, 6, 9);
      requests = [];
      manifestBody = jsonEncode(manifestJson());
      manifestStatus = 200;
      apkBytes = [1, 2, 3, 4, 5];
    });

    tearDown(() => cache.delete(recursive: true));

    UpdateController controller() => UpdateController(
      storage: storage,
      platform: platform,
      clock: () => now,
      client: MockClient.streaming((req, _) async {
        requests.add(req.url);
        if (req.url.toString() == updateManifestUrl) {
          return http.StreamedResponse(Stream.value(utf8.encode(manifestBody)), manifestStatus);
        }
        return http.StreamedResponse(Stream.value(apkBytes), 200);
      }),
    );

    test('꺼져 있으면 GitHub에 요청하지 않는다', () async {
      final update = controller();
      await update.init();
      expect(update.enabled, isFalse);
      expect(requests, isEmpty);
      expect(update.offer, isNull);
    });

    test('켜면 바로 확인하고, 하루 안에는 저장해 둔 결과를 쓴다', () async {
      final update = controller();
      await update.init();
      await update.setEnabled(true);
      expect(requests, [Uri.parse(updateManifestUrl)]);
      expect(update.offer?.versionCode, 8);
      expect(update.lastCheckedAt, now);

      now = now.add(const Duration(hours: 5));
      final again = controller();
      await again.init();
      expect(requests, hasLength(1));
      expect(again.offer?.versionCode, 8);

      await again.skip(again.offer!);
      expect(again.offer, isNull);
      final third = controller();
      await third.init();
      expect(third.offer, isNull);
    });

    test('확인에 실패하면 시각을 남기지 않아 다음 실행 때 다시 확인한다', () async {
      manifestStatus = 404;
      final update = controller();
      await update.init();
      await update.setEnabled(true);
      expect(update.lastCheckFailed, isTrue);
      expect(update.lastCheckedAt, isNull);
      expect(update.offer, isNull);

      manifestStatus = 200;
      final next = controller();
      await next.init();
      expect(requests, hasLength(2));
      expect(next.offer?.versionCode, 8);
    });

    test('설치 허용이 없으면 내려받지 않고 허용을 요청한다', () async {
      platform.installAllowed = false;
      final update = controller();
      await update.init();
      await update.setEnabled(true);
      expect(await update.downloadAndInstall(update.offer!), isFalse);
      expect(update.step, UpdateStep.needsPermission);
      expect(requests, hasLength(1));
    });

    test('해시가 맞으면 설치 화면을 연다', () async {
      platform.hash = sha;
      final update = controller();
      await update.init();
      await update.setEnabled(true);
      expect(await update.downloadAndInstall(update.offer!), isTrue);
      expect(platform.installed, hasLength(1));
      expect(await File(platform.installed.single).readAsBytes(), apkBytes);
      expect(update.step, UpdateStep.idle);

      // 다음 실행 때 지난번에 받은 파일을 지운다.
      await controller().init();
      expect(File(platform.installed.single).existsSync(), isFalse);
    });

    test('해시가 계속 틀리면 세 번 시도 후 실패하고 파일을 남기지 않는다', () async {
      final update = controller();
      await update.init();
      await update.setEnabled(true);
      expect(await update.downloadAndInstall(update.offer!), isFalse);
      expect(platform.hashCalls, UpdateController.downloadAttempts);
      expect(platform.installed, isEmpty);
      expect(update.step, UpdateStep.failed);
      expect(Directory('${cache.path}/updates').listSync(), isEmpty);
    });

    test('알린 크기와 다른 파일은 해시를 보기 전에 거부한다', () async {
      platform.hash = sha;
      apkBytes = [1, 2, 3, 4, 5, 6];
      final update = controller();
      await update.init();
      await update.setEnabled(true);
      expect(await update.downloadAndInstall(update.offer!), isFalse);
      expect(platform.hashCalls, 0);
      expect(platform.installed, isEmpty);
    });
  });

  test('릴리스 스크립트가 올리는 자산 이름이 앱이 읽는 주소와 같다', () {
    final script = File('tool/release_android.ps1').readAsStringSync();
    expect(updateManifestUrl, endsWith('/releases/latest/download/update.json'));
    expect(script, contains("'update.json'"));
    expect(updateManifestUrl, contains('jeiel85/my-farm-flutter'));
    expect(script, contains('jeiel85/my-farm-flutter'));
  });
}
