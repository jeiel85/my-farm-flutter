import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/features/farm/sky_layer.dart';
import 'package:my_farm/game/defs.dart';
import 'package:my_farm/game/engine.dart';
import 'package:my_farm/game/sky.dart';

void main() {
  /// [from]부터 [step]씩 넘기며 [test]를 만족하는 첫 시각.
  DateTime firstWhere(DateTime from, bool Function(DateTime t) test, {Duration step = const Duration(hours: 2)}) {
    for (var t = from; t.isBefore(from.add(const Duration(days: 120))); t = t.add(step)) {
      if (test(t)) return t;
    }
    throw StateError('not found');
  }

  test('다른 테스트의 기준 시각은 게임에 영향이 없는 날씨다', () {
    // game_engine_test·game_store_test(10월 6일 9시), app_smoke_test·reminders_test(10월 5일 14시 30분)는
    // 물 충전량과 수확량이 기본값이라고 가정한다. 날씨 표를 바꿔 이 단언이 깨지면 그 테스트들도 함께 살핀다.
    for (final t in [DateTime(2026, 10, 6, 9), DateTime(2026, 10, 5, 14, 30), DateTime(2026, 10, 5, 20, 50)]) {
      expect(GameSky.waterRefillAt(t), GameDefs.waterRefillPerMinute, reason: '$t');
      expect(GameSky.rainbowAt(t), isFalse, reason: '$t');
    }
  });

  test('같은 2시간 안에서는 날씨가 같고, 같은 시각이면 언제 물어도 같다', () {
    final start = DateTime(2026, 10, 7, 12);
    final kind = GameSky.kindAt(start);
    for (var m = 0; m < 120; m += 7) {
      expect(GameSky.kindAt(start.add(Duration(minutes: m))), kind);
    }
    expect(GameSky.kindAt(DateTime(2026, 10, 7, 12, 30)), GameSky.kindAt(DateTime(2026, 10, 7, 13, 59)));
  });

  test('달마다 날씨 비중이 다르다: 7월 장마, 겨울 눈, 폭염은 한낮, 안개는 이른 아침', () {
    int count(int month, SkyKind k) {
      var n = 0;
      for (var d = 1; d <= 28; d++) {
        for (var h = 0; h < 24; h += GameSky.blockHours) {
          if (GameSky.kindAt(DateTime(2026, month, d, h)) == k) n++;
        }
      }
      return n;
    }

    expect(count(7, SkyKind.rain), greaterThan(count(10, SkyKind.rain) * 2));
    expect(count(1, SkyKind.rain), 0);
    expect(count(1, SkyKind.snow), greaterThan(0));
    expect(count(7, SkyKind.snow), 0);
    for (var d = 1; d <= 28; d++) {
      for (var h = 0; h < 24; h += GameSky.blockHours) {
        final aug = GameSky.kindAt(DateTime(2026, 8, d, h));
        if (aug == SkyKind.heat) expect(h, inInclusiveRange(10, 16));
        final oct = GameSky.kindAt(DateTime(2026, 10, d, h));
        if (oct == SkyKind.fog) expect(h, inInclusiveRange(4, 8));
      }
    }
  });

  test('비 오는 동안 물탱크가 두 배로 찬다', () {
    final rain = firstWhere(DateTime(2026, 10, 1), (t) => GameSky.kindAt(t) == SkyKind.rain);
    final s = GameEngine.newGame(rain, farmName: 'x').copyWith(water: 0);
    final (after, _) = GameEngine.advance(s, rain.add(const Duration(minutes: 10)));
    expect(after.water, 10 * GameSky.rainRefillPerMinute);
  });

  test('폭염에는 물탱크가 천천히 찬다', () {
    final heat = firstWhere(DateTime(2026, 8, 1), (t) => GameSky.kindAt(t) == SkyKind.heat);
    final s = GameEngine.newGame(heat, farmName: 'x').copyWith(water: 0);
    expect(GameEngine.advance(s, heat.add(const Duration(minutes: 10))).$1.water, 10 * GameSky.heatRefillPerMinute);
  });

  test('비가 갠 뒤 40분 동안 무지개가 뜨고, 그동안 수확량이 20% 는다(올림)', () {
    final after = firstWhere(DateTime(2026, 7, 1), GameSky.rainbowAt);
    expect(GameSky.kindAt(after.subtract(const Duration(minutes: 1))), SkyKind.rain);
    expect(GameSky.rainbowMinutesLeft(after), GameSky.rainbowMinutes);
    expect(GameSky.rainbowAt(after.add(const Duration(minutes: GameSky.rainbowMinutes - 1))), isTrue);
    expect(GameSky.rainbowAt(after.add(const Duration(minutes: GameSky.rainbowMinutes))), isFalse);

    final lettuce = GameDefs.crops[CropId.lettuce]!;
    expect(GameSky.yieldAt(lettuce, after), 6); // 5 × 1.2
    expect(GameSky.yieldAt(GameDefs.crops[CropId.carrot]!, after), 8); // 6 × 1.2 = 7.2 → 8

    final planted = GameEngine.newGame(after.subtract(const Duration(minutes: 1)), farmName: 'x');
    final (ready, _) = GameEngine.advance(planted, after);
    expect(GameEngine.harvest(ready, GameDefs.startFieldLot).countOf(ItemId.lettuce), 6);
  });

  test('밤에는 무지개가 뜨지 않는다', () {
    for (var d = 1; d <= 28; d++) {
      for (final h in [0, 2, 4, 20, 22]) {
        expect(GameSky.rainbowAt(DateTime(2026, 7, d, h, 10)), isFalse);
      }
    }
  });

  test('날씨를 넘나들어도 나눠 진행한 결과와 한 번에 진행한 결과가 같다', () {
    final rain = firstWhere(DateTime(2026, 7, 1), (t) => GameSky.kindAt(t) == SkyKind.rain);
    final start = GameEngine.newGame(rain.subtract(const Duration(minutes: 50)), farmName: 'x').copyWith(water: 0);
    final end = start.simTime.add(const Duration(hours: 4));
    final once = GameEngine.advance(start, end, capMinutes: 1000).$1;
    var split = start;
    while (split.simTime.isBefore(end)) {
      final next = split.simTime.add(const Duration(minutes: 13));
      split = GameEngine.advance(split, next.isAfter(end) ? end : next, capMinutes: 1000).$1;
    }
    expect(split.water, once.water);
    expect(split.toJson(), once.toJson());
  });

  test('앞으로 12시간 예보는 2시간씩 6칸이다', () {
    final f = GameSky.forecast(DateTime(2026, 10, 7, 13, 5), 6);
    expect([for (final (t, _) in f) t.hour], [12, 14, 16, 18, 20, 22]);
    expect(f.first.$2, GameSky.kindAt(DateTime(2026, 10, 7, 12)));
  });

  group('지도 하늘', () {
    test('밤은 어둡고 낮은 밝다. 노을은 18시에 가장 진하다', () {
      expect(SkyView.at(DateTime(2026, 10, 7, 22)).darkness, 1);
      expect(SkyView.at(DateTime(2026, 10, 7, 12)).darkness, 0);
      expect(SkyView.at(DateTime(2026, 10, 7, 18)).duskGlow, 1);
      expect(SkyView.at(DateTime(2026, 10, 7, 12)).duskGlow, 0);
    });

    test('새 날씨는 블록 처음 12분 동안 서서히 들어온다', () {
      final rain = firstWhere(
        DateTime(2026, 7, 1),
        (t) =>
            GameSky.kindAt(t) == SkyKind.rain && GameSky.kindAt(t.subtract(const Duration(minutes: 1))) != SkyKind.rain,
      );
      final begin = SkyView.at(rain);
      expect(begin.weight(SkyKind.rain), 0);
      expect(SkyView.at(rain.add(const Duration(minutes: 6))).weight(SkyKind.rain), closeTo(0.5, 0.01));
      expect(SkyView.at(rain.add(const Duration(minutes: 12))).weight(SkyKind.rain), 1);
    });

    test('비·밤에는 동물이 쉼터로 모이고, 맑은 낮에는 흩어져 논다', () {
      expect(SkyView.preview(SkyPreview.rain, DateTime(2026, 10, 7, 12)).shelter, greaterThan(0.5));
      expect(SkyView.preview(SkyPreview.night, DateTime(2026, 10, 7, 12)).shelter, greaterThan(0.5));
      expect(SkyView.preview(SkyPreview.clear, DateTime(2026, 10, 7, 12)).shelter, 0);
    });
  });
}
