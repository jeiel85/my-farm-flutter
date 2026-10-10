import 'defs.dart';
import 'engine.dart';
import 'state.dart';

enum ReminderKind { harvest, animals, feed }

/// 알림 설정. 기기마다 다를 수 있어 게임 데이터가 아니라 기기별 meta에 둔다(백업에 들어가지 않는다).
class ReminderSettings {
  const ReminderSettings({this.enabled = false, this.harvest = true, this.animals = true, this.feed = true});

  final bool enabled;
  final bool harvest;
  final bool animals;
  final bool feed;

  bool allows(ReminderKind kind) => switch (kind) {
    ReminderKind.harvest => harvest,
    ReminderKind.animals => animals,
    ReminderKind.feed => feed,
  };

  ReminderSettings copyWith({bool? enabled, bool? harvest, bool? animals, bool? feed}) => ReminderSettings(
    enabled: enabled ?? this.enabled,
    harvest: harvest ?? this.harvest,
    animals: animals ?? this.animals,
    feed: feed ?? this.feed,
  );

  ReminderSettings withKind(ReminderKind kind, bool on) => switch (kind) {
    ReminderKind.harvest => copyWith(harvest: on),
    ReminderKind.animals => copyWith(animals: on),
    ReminderKind.feed => copyWith(feed: on),
  };

  Map<String, Object?> toJson() => {'enabled': enabled, 'harvest': harvest, 'animals': animals, 'feed': feed};

  /// 읽을 수 없으면 기본값(꺼짐)으로 본다. 알림을 몰래 켜는 쪽으로 틀리지 않게 한다.
  /// 1.x의 종류 키(watering 등)는 없는 셈 치고 새 종류는 켜진 채로 시작한다(켜기 여부는 그대로 이어받는다).
  factory ReminderSettings.fromJson(Object? j) {
    if (j is! Map) return const ReminderSettings();
    bool flag(String key, bool fallback) => j[key] is bool ? j[key] as bool : fallback;
    return ReminderSettings(
      enabled: flag('enabled', false),
      harvest: flag('harvest', true),
      animals: flag('animals', true),
      feed: flag('feed', true),
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

/// 같은 분에 다 자란 작물들.
class HarvestReminder extends PlannedReminder {
  const HarvestReminder(super.at, this.crops);
  final List<CropId> crops;
  @override
  ReminderKind get kind => ReminderKind.harvest;
}

/// 이 종의 생산물이 가득 차 생산이 멈춘다.
class AnimalsReminder extends PlannedReminder {
  const AnimalsReminder(super.at, this.species);
  final Species species;
  @override
  ReminderKind get kind => ReminderKind.animals;
}

/// 사료가 떨어져 성장·생산이 멈춘다.
class FeedReminder extends PlannedReminder {
  const FeedReminder(super.at);
  @override
  ReminderKind get kind => ReminderKind.feed;
}

/// 지금 상태에서 앱을 닫아 둔다고 보고 앞으로 일어날 일을 시각 순으로 계산한다.
///
/// 앱을 닫아 둔 동안은 농가 레벨에 따른 시간([GameState.offlineCapMinutes])까지만 진행되므로 그 안의 일만 알린다.
/// 지금 이미 그런 상태(다 자람·가득 참·사료 없음)인 것은 앱 화면에 나오므로 보내지 않는다.
/// 밤(21시~7시)에 일어나는 일은 아침 7시로 미룬다(작물·생산물은 그때까지 그대로 기다린다).
List<PlannedReminder> planReminders(GameState state, DateTime now, ReminderSettings settings) {
  if (!settings.enabled) return const [];
  var (s, _) = GameEngine.advance(state, now);
  final full = {for (final sp in Species.values) sp: _anyFull(s, sp)};
  // 홈 할 일에 '사료가 떨어졌어요'가 이미 떠 있으면(사료 0) 다시 알리지 않는다.
  var feedOut = s.animals.isNotEmpty && (s.feedUnits == 0 || _feedShort(s));
  final harvest = <DateTime, List<CropId>>{};
  final out = <PlannedReminder>[];

  for (var m = 0; m < state.offlineCapMinutes; m++) {
    final (next, report) = GameEngine.advance(s, s.simTime.add(const Duration(minutes: 1)));
    s = next;
    final at = _outsideQuietHours(s.simTime);
    if (settings.harvest) {
      for (final lot in report.cropsReady) {
        harvest.putIfAbsent(at, () => []).add(s.lots[lot]!.field!.crop!);
      }
    }
    if (settings.animals) {
      for (final sp in Species.values) {
        if (full[sp]! || !_anyFull(s, sp)) continue;
        full[sp] = true;
        out.add(AnimalsReminder(at, sp));
      }
    }
    if (settings.feed && !feedOut && report.feedRanOut) {
      feedOut = true;
      out.add(FeedReminder(at));
    }
  }
  for (final e in harvest.entries) {
    out.add(HarvestReminder(e.key, [...e.value]..sort((a, b) => a.index.compareTo(b.index))));
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

bool _anyFull(GameState s, Species sp) =>
    s.animals.any((a) => a.species == sp && a.adult && a.stored >= a.def.storeCap);

/// 다음 1분을 먹일 사료가 모자란 동물이 있다.
bool _feedShort(GameState s) =>
    s.animals.any((a) => (a.adult ? a.stored < a.def.storeCap : true) && s.feedUnits < _need(a));

int _need(GameAnimal a) => a.adult ? a.def.feedPerHour : a.def.feedPerHour ~/ 2;

const _quietStartHour = 21;
const _quietEndHour = 7;

DateTime _outsideQuietHours(DateTime at) {
  if (at.hour >= _quietStartHour) return DateTime(at.year, at.month, at.day + 1, _quietEndHour);
  if (at.hour < _quietEndHour) return DateTime(at.year, at.month, at.day, _quietEndHour);
  return at;
}
