import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/farm_store.dart';
import '../../data/reminder_plan.dart';
import '../../l10n/l10n.dart';

/// 알림은 Android와 Windows에서 쓴다. 웹은 앱을 닫으면 알림을 예약해 둘 수 없어 쓰지 않는다.
bool get remindersSupported => !kIsWeb && (Platform.isAndroid || Platform.isWindows);

/// 알림 한 건의 내용. 플랫폼 구현이 그대로 띄운다.
class ReminderNotice {
  const ReminderNotice({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    required this.channelName,
  });

  final int id;
  final ReminderKind kind;
  final DateTime at;
  final String title;
  final String body;

  /// 휴대폰 설정 > 알림에 보이는 채널 이름(종류마다 따로 끌 수 있다).
  final String channelName;
}

abstract class ReminderPlatform {
  /// [appName]은 Windows 알림 머리글에 나오는 앱 이름이다.
  Future<void> init({required String appName});

  /// 알림 권한을 요청한다(Android 13+). 허용되어 있으면 true.
  Future<bool> requestPermission();

  /// 지금 알림이 허용되어 있는지(사용자가 나중에 설정에서 끌 수 있다).
  Future<bool> permitted();

  /// 예약해 둔 알림을 [notices]로 바꾼다. 이미 화면·알림 센터에 떠 있는 알림은 건드리지 않는다.
  Future<void> replaceAll(List<ReminderNotice> notices);

  /// 예약만 모두 취소한다(떠 있는 알림은 남긴다).
  Future<void> cancelScheduled();
}

class LocalNotificationsPlatform implements ReminderPlatform {
  final _plugin = FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Windows 알림이 이 앱 것임을 알리는 ID와 알림 클릭 콜백 COM 클래스 ID. 바꾸면 이전에 잡은 예약을 지울 수 없게 되므로 고정한다.
  static const windowsAppId = 'Jeiel85.MyFarm';
  static const windowsCallbackGuid = 'b4f3f0c2-6a7e-4d0f-9a51-3c2d8e7f1a64';

  @override
  Future<void> init({required String appName}) async {
    final ok = await _plugin.initialize(
      settings: InitializationSettings(
        // res/drawable/ic_stat_farm.xml(흰 실루엣). 런처 아이콘을 쓰면 상태 표시줄에 회색 네모로 나온다.
        android: const AndroidInitializationSettings('ic_stat_farm'),
        // MSIX 패키지가 아니어도 되도록 플러그인이 HKCU에 앱 ID와 이름·아이콘을 등록한다.
        windows: WindowsInitializationSettings(
          appName: appName,
          appUserModelId: windowsAppId,
          guid: windowsCallbackGuid,
          iconPath: Platform.isWindows ? _windowsIconPath() : null,
        ),
      ),
    );
    if (ok == false) throw StateError('Notification plugin did not initialize');
  }

  /// 빌드에 함께 들어가는 앱 아이콘(pubspec assets). Windows 알림에 앱 아이콘으로 나온다.
  static String _windowsIconPath() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return [exeDir, 'data', 'flutter_assets', 'assets', 'icon', 'icon.png'].join(Platform.pathSeparator);
  }

  /// Windows는 알림 권한을 앱이 묻지 않는다(설정 > 시스템 > 알림에서 사용자가 끈다).
  @override
  Future<bool> requestPermission() async =>
      Platform.isWindows || (await _android?.requestNotificationsPermission() ?? false);

  @override
  Future<bool> permitted() async => Platform.isWindows || (await _android?.areNotificationsEnabled() ?? false);

  @override
  Future<void> replaceAll(List<ReminderNotice> notices) async {
    await cancelScheduled();
    // 계산한 뒤 예약하기까지 사이에 지나간 시각은 건너뛴다(플러그인이 지난 시각 예약을 거부한다).
    final soonest = DateTime.now().add(const Duration(seconds: 5));
    for (final n in notices.where((n) => n.at.isAfter(soonest))) {
      await _plugin.zonedSchedule(
        id: n.id,
        title: n.title,
        body: n.body,
        // 기기 현지 시각을 같은 순간의 UTC로 넘긴다. 반복 예약을 쓰지 않으므로 시간대 데이터베이스가 필요 없다.
        scheduledDate: tz.TZDateTime.from(n.at, tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_${n.kind.name}',
            n.channelName,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
        // 정확한 알람 권한(SCHEDULE_EXACT_ALARM) 없이 예약한다. Android가 배터리를 아끼려고 최대 1시간까지 늦출 수 있다.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// 플러그인의 cancelAll은 떠 있는 알림(Android 알림 창, Windows 알림 센터)까지 지워서 쓰지 않는다.
  /// 앱을 열거나 기록을 고칠 때마다 다시 예약하므로, 그때마다 아직 처리하지 않은 알림이 사라지게 된다.
  @override
  Future<void> cancelScheduled() async {
    if (Platform.isAndroid) {
      await _android?.cancelAllPendingNotifications();
      return;
    }
    // Windows는 cancelAllPendingNotifications가 없다. 예약 목록의 id마다 지운다(패키지가 아닌 앱이면 예약만 지운다).
    for (final pending in await _plugin.pendingNotificationRequests()) {
      await _plugin.cancel(id: pending.id);
    }
  }
}

/// 설정을 기기별 meta에 두고, 농장 기록이 바뀔 때마다 앞으로의 알림을 다시 예약한다.
class ReminderController extends ChangeNotifier {
  ReminderController({
    required this.store,
    required this.platform,
    required this.storage,
    required this.localizations,
    this.debounce = const Duration(seconds: 2),
  });

  final FarmStore store;
  final ReminderPlatform platform;
  final FarmStorage storage;

  /// 알림 문구에 쓸 현재 언어.
  final AppLocalizations Function() localizations;
  final Duration debounce;

  static const metaKey = 'reminders';

  ReminderSettings settings = const ReminderSettings();

  /// 켜져 있는데 휴대폰 설정에서 알림이 꺼져 있다.
  bool permissionMissing = false;
  int scheduledCount = 0;

  /// 가장 먼저 올 알림 시각.
  DateTime? nextAt;
  Object? lastError;

  Timer? _pending;
  Future<void> _queue = Future.value();

  Future<void> init() async {
    try {
      settings = ReminderSettings.fromJson(jsonDecode(await storage.readMeta(metaKey) ?? 'null'));
    } on FormatException {
      settings = const ReminderSettings();
    }
    store.addListener(_onStoreChanged);
    try {
      await platform.init(appName: localizations().appTitle);
    } catch (e) {
      // 알림만 못 쓸 뿐 앱은 계속 쓸 수 있다. 설정 카드에 원인을 보여 준다.
      debugPrint('Could not initialize reminders: $e');
      lastError = e;
      notifyListeners();
      return;
    }
    await sync();
  }

  void _onStoreChanged() {
    _pending?.cancel();
    _pending = Timer(debounce, sync);
  }

  /// 켜려면 알림 권한을 받아야 한다. 거절하면 꺼진 채로 두고 false.
  Future<bool> setEnabled(bool on) async {
    if (on && !await platform.requestPermission()) {
      permissionMissing = true;
      notifyListeners();
      return false;
    }
    await _save(settings.copyWith(enabled: on));
    return true;
  }

  Future<void> setKind(ReminderKind kind, bool on) => _save(settings.withKind(kind, on));

  Future<void> _save(ReminderSettings next) async {
    settings = next;
    notifyListeners();
    await storage.writeMeta(metaKey, jsonEncode(next.toJson()));
    await sync();
  }

  /// 예약을 지금 상태에 맞춘다. 여러 번 불려도 차례로 하나씩 실행한다.
  Future<void> sync() => _queue = _queue.then((_) => _sync());

  Future<void> _sync() async {
    _pending?.cancel();
    try {
      if (!settings.enabled) {
        await platform.cancelScheduled();
        scheduledCount = 0;
        nextAt = null;
        permissionMissing = false;
      } else {
        permissionMissing = !await platform.permitted();
        final plan = planReminders(store.state, store.now, settings);
        final l = localizations();
        await platform.replaceAll([for (final r in plan) _notice(r, l)]);
        scheduledCount = plan.length;
        nextAt = plan.firstOrNull?.at;
      }
      lastError = null;
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
      lastError = e;
    }
    notifyListeners();
  }

  ReminderNotice _notice(PlannedReminder r, AppLocalizations l) {
    final (title, body) = switch (r) {
      WateringReminder(:final crops) => (l.notifWateringTitle, l.notifWateringBody(crops.join(', '))),
      FeedingReminder(:final slot) => (l.alertFeedingTitle(slot.timeLabel, slot.label), l.notifFeedingBody),
      CareReminder(:final item, :final animal) => (
        l.notifCareTitle(item.title),
        l.notifCareBody(animal == null ? l.kind(item.kind) : '${animal.name} (${animal.tag})'),
      ),
    };
    return ReminderNotice(
      id: reminderId(r),
      kind: r.kind,
      at: r.at,
      title: title,
      body: body,
      channelName: switch (r.kind) {
        ReminderKind.watering => l.remindersWatering,
        ReminderKind.feeding => l.remindersFeeding,
        ReminderKind.care => l.remindersCare,
      },
    );
  }

  @override
  void dispose() {
    _pending?.cancel();
    store.removeListener(_onStoreChanged);
    super.dispose();
  }
}

/// 같은 알림(종류·시각·대상)이면 다시 예약해도 같은 id가 되도록 내용으로 정한다(FNV-1a 32비트, 양수).
///
/// 순번을 쓰면 다시 예약할 때마다 번호가 밀려, 예약한 알림이 떠 있는 다른 알림을 같은 id로 덮어쓰게 된다.
/// `Object.hash`는 실행마다 값이 달라 쓰지 않는다.
int reminderId(PlannedReminder r) {
  final key = switch (r) {
    WateringReminder(:final crops) => 'w|${crops.join(',')}',
    FeedingReminder(:final slot) => 'f|${slot.timeLabel}|${slot.label}',
    CareReminder(:final item) => 'c|${item.id}',
  };
  var h = 0x811c9dc5;
  for (final unit in utf8.encode('$key|${r.at.toIso8601String()}')) {
    h = ((h ^ unit) * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

/// 알림 문구 언어. 앱 화면과 같은 규칙(직접 고른 언어 → 기기 언어, 한국어가 아니면 영어)을 따른다.
AppLocalizations reminderLocalizations(FarmStore store) {
  final code = store.localeOverride ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return lookupAppLocalizations(Locale(code == 'ko' ? 'ko' : 'en'));
}

class ReminderScope extends InheritedNotifier<ReminderController> {
  const ReminderScope({super.key, required ReminderController? controller, required super.child})
    : super(notifier: controller);

  /// 알림을 쓰지 않는 플랫폼(웹·Windows)에서는 null.
  static ReminderController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReminderScope>()?.notifier;
}

/// 알림 시각을 사람이 읽는 형식으로(설정 카드의 다음 알림 표시용).
String reminderTimeLabel(BuildContext context, DateTime at) => DateFormat.MMMEd(context.localeName).add_Hm().format(at);
