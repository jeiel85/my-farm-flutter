import 'farm_state.dart';
import 'models.dart';

enum ReminderKind { watering, feeding, care }

/// 휴대폰 알림 설정. 기기마다 다를 수 있어 농장 데이터가 아니라 기기별 meta에 둔다(백업에 들어가지 않는다).
class ReminderSettings {
  const ReminderSettings({this.enabled = false, this.watering = true, this.feeding = true, this.care = true});

  final bool enabled;
  final bool watering;
  final bool feeding;
  final bool care;

  bool allows(ReminderKind kind) => switch (kind) {
    ReminderKind.watering => watering,
    ReminderKind.feeding => feeding,
    ReminderKind.care => care,
  };

  ReminderSettings copyWith({bool? enabled, bool? watering, bool? feeding, bool? care}) => ReminderSettings(
    enabled: enabled ?? this.enabled,
    watering: watering ?? this.watering,
    feeding: feeding ?? this.feeding,
    care: care ?? this.care,
  );

  ReminderSettings withKind(ReminderKind kind, bool on) => switch (kind) {
    ReminderKind.watering => copyWith(watering: on),
    ReminderKind.feeding => copyWith(feeding: on),
    ReminderKind.care => copyWith(care: on),
  };

  Map<String, Object?> toJson() => {'enabled': enabled, 'watering': watering, 'feeding': feeding, 'care': care};

  /// 읽을 수 없으면 기본값(꺼짐)으로 본다. 알림을 몰래 켜는 쪽으로 틀리지 않게 한다.
  factory ReminderSettings.fromJson(Object? j) {
    if (j is! Map) return const ReminderSettings();
    bool flag(String key, bool fallback) => j[key] is bool ? j[key] as bool : fallback;
    return ReminderSettings(
      enabled: flag('enabled', false),
      watering: flag('watering', true),
      feeding: flag('feeding', true),
      care: flag('care', true),
    );
  }
}

/// 예약할 알림 한 건. 문구는 화면 언어로 따로 만든다.
sealed class PlannedReminder {
  const PlannedReminder(this.at);

  /// 알림을 보낼 기기 현지 시각.
  final DateTime at;

  ReminderKind get kind;
}

/// 같은 시각에 물이 필요한 밭들(스마트 관수로 함께 준 밭은 함께 돌아온다).
class WateringReminder extends PlannedReminder {
  const WateringReminder(super.at, this.crops);
  final List<String> crops;
  @override
  ReminderKind get kind => ReminderKind.watering;
}

class FeedingReminder extends PlannedReminder {
  const FeedingReminder(super.at, this.slot);
  final FeedingSlot slot;
  @override
  ReminderKind get kind => ReminderKind.feeding;
}

class CareReminder extends PlannedReminder {
  const CareReminder(super.at, this.item, this.animal);
  final CareItem item;

  /// 개체 전용 일정이면 그 개체, 종 전체 대상이면 null.
  final Animal? animal;
  @override
  ReminderKind get kind => ReminderKind.care;
}

/// 앞으로 보낼 알림을 시각 순으로 계산한다.
///
/// - 물주기: 다음 물주기 시각. 밤(21시~7시)에 돌아오면 아침 7시로 미룬다. 이미 지난 것은 앱 홈에 나오므로 보내지 않는다.
/// - 급이: 앞으로 [feedingDays]일의 급이 시각. 오늘 이미 체크한 회차는 뺀다.
/// - 백신·진료: [careDays]일 안의 일정을 그날 아침 8시에. 대상 개체가 없어진 일정은 뺀다.
///
/// 앱을 열지 않는 동안에도 며칠은 알림이 오도록 미리 잡아 두고, 앱을 열거나 기록이 바뀔 때마다 다시 계산한다.
/// 기기의 예약 알람 수 제한을 넘지 않게 [maxCount]건까지만 돌려준다.
List<PlannedReminder> planReminders(
  FarmState state,
  DateTime now,
  ReminderSettings settings, {
  int feedingDays = 7,
  int careDays = 14,
  int maxCount = 60,
}) {
  if (!settings.enabled) return const [];
  final out = <PlannedReminder>[];

  if (settings.watering) {
    final byTime = <DateTime, List<String>>{};
    for (final f in state.fields) {
      final due = f.nextWateringAt;
      if (!due.isAfter(now)) continue;
      byTime.putIfAbsent(_outsideQuietHours(due), () => []).add(f.cropName);
    }
    for (final e in byTime.entries) {
      out.add(WateringReminder(e.key, e.value));
    }
  }

  if (settings.feeding) {
    final doneToday = {...?state.feedingDone[dateKeyOf(now)]};
    for (var d = 0; d < feedingDays; d++) {
      for (final (i, slot) in state.feedingSlots.indexed) {
        if (d == 0 && doneToday.contains(i)) continue;
        final at = DateTime(now.year, now.month, now.day + d, slot.hour, slot.minute);
        if (at.isAfter(now)) out.add(FeedingReminder(at, slot));
      }
    }
  }

  if (settings.care) {
    final animals = {for (final a in state.animals) a.id: a};
    for (final c in state.careItems) {
      if (c.isDone) continue;
      final animal = c.animalId == null ? null : animals[c.animalId];
      if (c.animalId != null && animal == null) continue;
      final at = DateTime(c.dueDate.year, c.dueDate.month, c.dueDate.day, 8);
      if (at.isAfter(now) && at.isBefore(now.add(Duration(days: careDays)))) out.add(CareReminder(at, c, animal));
    }
  }

  out.sort((a, b) => a.at.compareTo(b.at));
  return out.length > maxCount ? out.sublist(0, maxCount) : out;
}

const _quietStartHour = 21;
const _quietEndHour = 7;

DateTime _outsideQuietHours(DateTime at) {
  if (at.hour >= _quietStartHour) return DateTime(at.year, at.month, at.day + 1, _quietEndHour);
  if (at.hour < _quietEndHour) return DateTime(at.year, at.month, at.day, _quietEndHour);
  return at;
}
