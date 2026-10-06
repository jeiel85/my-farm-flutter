import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'storage.dart';

/// GitHub 릴리스로 내려받은 APK(사이드로드)의 앱 안 업데이트.
///
/// 최신 릴리스의 `update.json`을 버전과 무관한 고정 주소로 읽는다(`releases/latest/download/…`는
/// 최신 릴리스의 같은 이름 자산으로 넘겨 준다). api.github.com은 비인증 요청 한도가 IP당 시간당
/// 60건이라 같은 통신사 IP를 쓰는 다른 사람 때문에 막힐 수 있어 쓰지 않는다.
/// `update.json`은 `tool/release_android.ps1`이 APK에서 값을 뽑아 만든다.
const updateManifestUrl = 'https://github.com/jeiel85/my-farm-flutter/releases/latest/download/update.json';

/// 앱 안 업데이트를 쓰는 플랫폼. 웹은 늘 최신이고, Windows는 Release 폴더째 배포라 대상이 아니다.
bool get appUpdateSupported => !kIsWeb && Platform.isAndroid;

/// `update.json` 한 건. 일곱 키가 모두 있어야 하고 하나라도 형식이 틀리면 전체를 버린다.
class UpdateManifest {
  const UpdateManifest({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.apkSizeBytes,
    required this.sha256,
    required this.minSdk,
    required this.releaseNotesUrl,
  });

  final int versionCode;
  final String versionName;
  final String apkUrl;
  final int apkSizeBytes;
  final String sha256;
  final int minSdk;
  final String releaseNotesUrl;

  static final _sha256 = RegExp(r'^[0-9a-fA-F]{64}$');

  /// 형식이 맞지 않으면 null. 주소는 https만 받는다(호스트는 GitHub가 다른 곳으로 넘겨 주므로
  /// 고정하지 않고, 대신 내려받은 파일을 SHA-256과 크기로, 설치는 OS 서명 검사로 확인한다).
  static UpdateManifest? parse(String body) {
    try {
      final j = jsonDecode(body);
      if (j is! Map) return null;
      final versionCode = j['versionCode'];
      final versionName = j['versionName'];
      final apkUrl = j['apkUrl'];
      final size = j['apkSizeBytes'];
      final sha = j['sha256'];
      final minSdk = j['minSdk'];
      final notes = j['releaseNotesUrl'];
      if (versionCode is! int || versionCode <= 0) return null;
      if (versionName is! String || versionName.isEmpty) return null;
      if (apkUrl is! String || !_isHttps(apkUrl)) return null;
      if (size is! int || size <= 0) return null;
      if (sha is! String || !_sha256.hasMatch(sha)) return null;
      if (minSdk is! int || minSdk <= 0) return null;
      if (notes is! String || !_isHttps(notes)) return null;
      return UpdateManifest(
        versionCode: versionCode,
        versionName: versionName,
        apkUrl: apkUrl,
        apkSizeBytes: size,
        sha256: sha.toLowerCase(),
        minSdk: minSdk,
        releaseNotesUrl: notes,
      );
    } on FormatException {
      return null;
    }
  }

  static bool _isHttps(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}

/// 네트워크 확인은 성공 기준 하루 한 번. 시계가 뒤로 갔으면 다시 확인한다.
bool shouldCheckUpdateNow(DateTime? lastCheckedAt, DateTime now) =>
    lastCheckedAt == null || lastCheckedAt.isAfter(now) || now.difference(lastCheckedAt) >= const Duration(days: 1);

/// 버전은 문자열이 아니라 versionCode 정수로 비교한다(문자열이면 1.9.0이 1.10.0보다 크다).
bool shouldOfferUpdate(UpdateManifest m, {required int installed, required int? skipped, required int sdk}) =>
    m.versionCode > installed && m.versionCode != skipped && sdk >= m.minSdk;

/// 설치된 앱 정보와 설치 동작(Android 네이티브).
class AppBuildInfo {
  const AppBuildInfo({
    required this.versionCode,
    required this.versionName,
    required this.sdkInt,
    required this.cacheDir,
  });

  final int versionCode;
  final String versionName;
  final int sdkInt;
  final String cacheDir;
}

abstract class UpdatePlatform {
  Future<AppBuildInfo> info();

  /// "출처를 알 수 없는 앱 설치" 허용 여부(Android 8 미만은 늘 true).
  Future<bool> canInstall();
  Future<void> openInstallSettings();
  Future<String> sha256(String path);

  /// 시스템 설치 화면을 연다. 파일은 캐시의 `updates/` 안에 있어야 한다.
  Future<void> install(String path);
  Future<void> openUrl(String url);
}

class MethodChannelUpdatePlatform implements UpdatePlatform {
  static const _channel = MethodChannel('com.jeiel85.myfarm/update');

  @override
  Future<AppBuildInfo> info() async {
    final m = (await _channel.invokeMapMethod<String, Object?>('info'))!;
    return AppBuildInfo(
      versionCode: (m['versionCode'] as num).toInt(),
      versionName: m['versionName'] as String,
      sdkInt: m['sdkInt'] as int,
      cacheDir: m['cacheDir'] as String,
    );
  }

  @override
  Future<bool> canInstall() async => (await _channel.invokeMethod<bool>('canInstall'))!;

  @override
  Future<void> openInstallSettings() => _channel.invokeMethod('openInstallSettings');

  @override
  Future<String> sha256(String path) async => (await _channel.invokeMethod<String>('sha256', path))!;

  @override
  Future<void> install(String path) => _channel.invokeMethod('install', path);

  @override
  Future<void> openUrl(String url) => _channel.invokeMethod('openUrl', url);
}

enum UpdateStep { idle, needsPermission, downloading, failed }

/// 업데이트 확인·내려받기 상태. 설정은 기기별 값(FarmStorage meta)이라 백업에 들어가지 않는다.
class UpdateController extends ChangeNotifier {
  UpdateController({
    required this._storage,
    required this._platform,
    http.Client? client,
    DateTime Function()? clock,
    this.manifestUrl = updateManifestUrl,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final FarmStorage _storage;
  final UpdatePlatform _platform;
  final http.Client _client;
  final DateTime Function() _clock;
  final String manifestUrl;

  /// `update.json`은 1KB 남짓이다. 엉뚱한 응답을 통째로 읽지 않게 상한을 둔다.
  static const maxManifestBytes = 64 * 1024;
  static const downloadAttempts = 3;

  AppBuildInfo? build;

  /// 하루 한 번 자동 확인. 기본은 꺼짐(사용자가 켜야 GitHub에 요청한다).
  bool enabled = false;
  DateTime? lastCheckedAt;

  /// 마지막 확인이 실패했는지(네트워크·형식 오류). 성공하면 false.
  bool lastCheckFailed = false;
  bool checking = false;
  UpdateManifest? _cached;
  int? _skipped;

  UpdateStep step = UpdateStep.idle;
  bool _busy = false;

  /// 지금 권할 새 버전. 없으면 null.
  UpdateManifest? get offer {
    final m = _cached;
    final b = build;
    if (!enabled || m == null || b == null) return null;
    return shouldOfferUpdate(m, installed: b.versionCode, skipped: _skipped, sdk: b.sdkInt) ? m : null;
  }

  /// 앱 시작 시 한 번. 지난번에 받은 APK를 지우고, 켜져 있으면 확인한다.
  Future<void> init() async {
    build = await _platform.info();
    enabled = await _storage.readMeta('update_enabled') == 'true';
    lastCheckedAt = DateTime.tryParse(await _storage.readMeta('update_checked_at') ?? '');
    _cached = UpdateManifest.parse(await _storage.readMeta('update_manifest') ?? '');
    _skipped = int.tryParse(await _storage.readMeta('update_skipped') ?? '');
    notifyListeners();
    await _clearDownloads();
    await refresh();
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    notifyListeners();
    await _storage.writeMeta('update_enabled', '$value');
    if (value) await refresh(force: true);
  }

  /// 켜져 있고 하루가 지났으면(또는 [force]) 확인한다. 실패는 기록만 하고 다음 실행 때 다시 한다.
  Future<void> refresh({bool force = false}) async {
    if (!enabled || checking) return;
    final now = _clock();
    if (!force && !shouldCheckUpdateNow(lastCheckedAt, now)) return;
    checking = true;
    notifyListeners();
    try {
      final body = await _fetchManifest();
      final parsed = body == null ? null : UpdateManifest.parse(body);
      if (parsed == null) {
        lastCheckFailed = true;
      } else {
        _cached = parsed;
        lastCheckedAt = now;
        lastCheckFailed = false;
        await _storage.writeMeta('update_manifest', body!);
        await _storage.writeMeta('update_checked_at', now.toIso8601String());
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
      lastCheckFailed = true;
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  Future<String?> _fetchManifest() async {
    // 캐시된 응답 대신 늘 최신 릴리스를 묻는다. 요청에 식별자나 쿼리를 붙이지 않는다.
    final req = http.Request('GET', Uri.parse(manifestUrl))..headers['Cache-Control'] = 'no-cache';
    final res = await _client.send(req).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      await res.stream.drain<void>();
      return null;
    }
    final bytes = <int>[];
    await for (final chunk in res.stream.timeout(const Duration(seconds: 10))) {
      bytes.addAll(chunk);
      if (bytes.length > maxManifestBytes) return null;
    }
    return utf8.decode(bytes, allowMalformed: false);
  }

  Future<void> skip(UpdateManifest m) async {
    _skipped = m.versionCode;
    notifyListeners();
    await _storage.writeMeta('update_skipped', '${m.versionCode}');
  }

  /// 대화상자를 닫을 때 진행 상태를 처음으로 돌린다(내려받는 중에는 닫히지 않는다).
  void resetStep() {
    if (step == UpdateStep.downloading) return;
    step = UpdateStep.idle;
    notifyListeners();
  }

  Future<void> openInstallSettings() => _platform.openInstallSettings();

  Future<void> openUrl(String url) => _platform.openUrl(url);

  /// 설치 허용을 확인하고, 내려받아 SHA-256·크기를 확인한 뒤 시스템 설치 화면을 연다.
  /// 설치 화면이 열리면 true. 그 뒤(설치·완료·열기)는 시스템이 맡는다.
  Future<bool> downloadAndInstall(UpdateManifest m) async {
    // 같은 파일을 두 번 동시에 쓰지 않게 한 번에 하나만 돈다.
    if (_busy) return false;
    _busy = true;
    try {
      if (!await _platform.canInstall()) {
        _setStep(UpdateStep.needsPermission);
        return false;
      }
      _setStep(UpdateStep.downloading);
      final dir = Directory('${build!.cacheDir}/updates');
      await dir.create(recursive: true);
      final file = File('${dir.path}/my-farm-${m.versionCode}.apk');
      for (var attempt = 1; attempt <= downloadAttempts; attempt++) {
        try {
          await _download(m, file);
          final hash = await _platform.sha256(file.path);
          if (hash.toLowerCase() == m.sha256) {
            await _platform.install(file.path);
            _setStep(UpdateStep.idle);
            return true;
          }
          debugPrint('Update download hash mismatch (attempt $attempt)');
        } catch (e) {
          debugPrint('Update download failed (attempt $attempt): $e');
        }
        if (await file.exists()) await file.delete();
      }
      _setStep(UpdateStep.failed);
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<void> _download(UpdateManifest m, File file) async {
    final res = await _client.send(http.Request('GET', Uri.parse(m.apkUrl))).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      await res.stream.drain<void>();
      throw HttpException('HTTP ${res.statusCode}');
    }
    final sink = file.openWrite();
    var received = 0;
    try {
      // 한 조각이 1분 넘게 오지 않으면 끊긴 것으로 본다. 알린 크기보다 크면 바로 멈춘다.
      await for (final chunk in res.stream.timeout(const Duration(minutes: 1))) {
        received += chunk.length;
        if (received > m.apkSizeBytes) throw const FormatException('APK is larger than update.json says');
        sink.add(chunk);
      }
    } finally {
      await sink.close();
    }
    if (received != m.apkSizeBytes) throw FormatException('APK size $received != ${m.apkSizeBytes}');
  }

  Future<void> _clearDownloads() async {
    final b = build;
    if (b == null) return;
    final dir = Directory('${b.cacheDir}/updates');
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException catch (e) {
      debugPrint('Could not clear old update files: $e');
    }
  }

  void _setStep(UpdateStep s) {
    step = s;
    notifyListeners();
  }
}

class UpdateScope extends InheritedNotifier<UpdateController> {
  const UpdateScope({super.key, required UpdateController? controller, required super.child})
    : super(notifier: controller);

  /// 업데이트를 쓰지 않는 플랫폼(웹·Windows)에서는 null.
  static UpdateController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UpdateScope>()?.notifier;
}
