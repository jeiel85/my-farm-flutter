import 'defs.dart';

/// 게임 날씨. docs/game-design.md §10.
///
/// 실제 날씨를 받아 쓰지 않고 날짜·시각(기기 현지 시간)으로 정해지는 결정적 날씨다. 앱을 닫아 둔 동안의
/// 시간도 [GameEngine.advance]가 분 단위로 다시 계산하므로, 지나간 시각의 날씨를 언제든 같은 값으로 알 수
/// 있어야 한다(실제 날씨는 지나간 시각의 값을 오프라인에서 알 수 없다). 같은 시각이면 모든 기기에서 같다.
enum SkyKind { clear, cloudy, windy, rain, snow, fog, heat }

/// 하루 중 때. 그림의 빛깔만 바꾸고 게임 규칙에는 영향이 없다.
enum DayPhase { dawn, day, dusk, night }

abstract final class GameSky {
  /// 날씨가 바뀌는 단위(현지 시각 0시부터 2시간씩).
  static const blockHours = 2;

  /// 비가 그친 뒤 무지개가 떠 있는 시간.
  static const rainbowMinutes = 40;

  /// 분당 물 충전량. 비 오는 동안 두 배, 폭염에는 증발로 줄어든다.
  static const rainRefillPerMinute = 10;
  static const heatRefillPerMinute = 3;

  /// 달별 날씨 비중(합 100). 한국 날씨를 단순하게 따랐다: 7월 장마, 8월 폭염, 겨울 눈, 봄 바람, 가을 맑음·안개.
  static const _monthly = <List<int>>[
    // clear, cloudy, windy, rain, snow, fog, heat
    [40, 30, 15, 0, 15, 0, 0], // 1월
    [40, 30, 15, 5, 10, 0, 0],
    [35, 30, 25, 10, 0, 0, 0],
    [40, 25, 20, 15, 0, 0, 0],
    [45, 25, 10, 15, 0, 5, 0],
    [35, 30, 0, 25, 0, 0, 10],
    [15, 30, 0, 45, 0, 0, 10], // 7월
    [30, 20, 0, 25, 0, 0, 25],
    [45, 25, 10, 15, 0, 5, 0],
    [55, 20, 10, 8, 0, 7, 0],
    [40, 30, 15, 10, 0, 5, 0],
    [35, 30, 15, 0, 20, 0, 0], // 12월
  ];

  static DateTime blockStart(DateTime t) => DateTime(t.year, t.month, t.day, t.hour - t.hour % blockHours);

  /// [t]가 속한 2시간 동안의 날씨.
  static SkyKind kindAt(DateTime t) {
    final start = blockStart(t);
    final roll = _roll(start);
    final weights = _monthly[start.month - 1];
    var acc = 0;
    var kind = SkyKind.clear;
    for (var i = 0; i < weights.length; i++) {
      acc += weights[i];
      if (roll < acc) {
        kind = SkyKind.values[i];
        break;
      }
    }
    // 폭염은 한낮에만, 안개는 이른 아침에만 낀다.
    if (kind == SkyKind.heat && (start.hour < 10 || start.hour > 16)) return SkyKind.clear;
    if (kind == SkyKind.fog && (start.hour < 4 || start.hour > 8)) return SkyKind.cloudy;
    return kind;
  }

  /// 0~99. 날짜·시간 블록으로 정해지는 의사 난수(Park–Miller). 웹에서도 같은 값이 나오도록 2^53 안의 정수 연산만 쓴다.
  static int _roll(DateTime start) {
    var x = ((start.year * 372 + start.month * 31 + start.day) * 12 + start.hour ~/ blockHours + 1) % 2147483647;
    for (var i = 0; i < 3; i++) {
      x = x * 48271 % 2147483647;
    }
    return x % 100;
  }

  /// 비가 그친 지 [rainbowMinutes] 안이고 해가 있는 때(6시~19시)면 무지개가 떠 있다.
  static bool rainbowAt(DateTime t) {
    if (t.hour < 6 || t.hour >= 19) return false;
    final start = blockStart(t);
    if (t.difference(start).inMinutes >= rainbowMinutes) return false;
    final kind = kindAt(t);
    if (kind == SkyKind.rain || kind == SkyKind.snow) return false;
    return kindAt(start.subtract(const Duration(minutes: 1))) == SkyKind.rain;
  }

  /// 무지개가 사라지기까지 남은 분(무지개가 없으면 0).
  static int rainbowMinutesLeft(DateTime t) =>
      rainbowAt(t) ? rainbowMinutes - t.difference(blockStart(t)).inMinutes : 0;

  static int waterRefillAt(DateTime t) => switch (kindAt(t)) {
    SkyKind.rain => rainRefillPerMinute,
    SkyKind.heat => heatRefillPerMinute,
    _ => GameDefs.waterRefillPerMinute,
  };

  /// [t]에 수확하면 얻는 개수. 무지개가 떠 있으면 20% 더(올림).
  static int yieldAt(CropDef def, DateTime t) => rainbowAt(t) ? (def.yieldCount * 6 + 4) ~/ 5 : def.yieldCount;

  static DayPhase phaseAt(DateTime t) => switch (t.hour) {
    5 || 6 => DayPhase.dawn,
    >= 7 && < 17 => DayPhase.day,
    17 || 18 => DayPhase.dusk,
    _ => DayPhase.night,
  };

  /// [from]이 속한 블록부터 [blocks]개 블록의 (시작 시각, 날씨).
  static List<(DateTime, SkyKind)> forecast(DateTime from, int blocks) {
    final first = blockStart(from);
    return [
      for (var i = 0; i < blocks; i++)
        if (DateTime(first.year, first.month, first.day, first.hour + i * blockHours) case final start)
          (start, kindAt(start)),
    ];
  }
}
