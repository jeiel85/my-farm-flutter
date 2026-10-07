/// 지도 위에 내려앉는 날씨와 하루의 빛깔. 좌표는 지도 월드 단위다.
///
/// 날씨 화면을 따로 두지 않고, 위에서 내려다본 수채 지도에 그대로 내린다: 구름은 밭 위를 지나가는 그림자로,
/// 비는 종이에 번지는 물방울 자국과 연못 파문으로, 밤은 창문 불빛과 반딧불로 보인다.
/// 매 프레임 그리므로 흐림(blur)은 처음 한 번 구운 그림(구름 그림자·안개)에만 쓴다.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../game/defs.dart';
import '../../game/sky.dart';
import '../../game/zone.dart';
import 'farm_world.dart';
import 'storybook.dart';

/// 날씨 그림 미리 보기(설정이 아니라 시트에서 잠깐 보는 용도). 게임 효과는 바꾸지 않는다.
enum SkyPreview { clear, cloudy, windy, rain, snow, fog, heat, rainbow, dusk, night, spring, summer, autumn, winter }

/// 계절. 지평선 능선과 땅 빛깔, 꽃잎·낙엽·서리가 달라진다(게임 규칙에는 영향 없음).
enum Season { spring, summer, autumn, winter }

Season seasonOf(int month) => switch (month) {
  3 || 4 || 5 => Season.spring,
  6 || 7 || 8 => Season.summer,
  9 || 10 || 11 => Season.autumn,
  _ => Season.winter,
};

/// 지도 한 장에 그릴 하늘 상태.
@immutable
class SkyView {
  const SkyView({
    required this.kind,
    required this.previous,
    required this.blend,
    required this.rainbow,
    required this.minuteOfDay,
    required this.month,
    this.previewing = false,
  });

  /// 새 날씨가 2시간 블록 처음 [_fadeMinutes] 동안 서서히 들어온다.
  static const _fadeMinutes = 12.0;

  factory SkyView.at(DateTime now) {
    final start = GameSky.blockStart(now);
    final minutesIn = now.difference(start).inSeconds / 60;
    final left = GameSky.rainbowAt(now) ? GameSky.rainbowMinutesLeft(now) : 0;
    return SkyView(
      kind: GameSky.kindAt(now),
      previous: GameSky.kindAt(start.subtract(const Duration(minutes: 1))),
      blend: (minutesIn / _fadeMinutes).clamp(0.0, 1.0),
      // 무지개는 떠오를 때와 사라지기 전 5분 동안 옅어진다.
      rainbow: left == 0 ? 0 : math.min(1.0, math.min(minutesIn / 4, left / 5)),
      minuteOfDay: now.hour * 60 + now.minute + now.second / 60,
      month: now.month,
    );
  }

  factory SkyView.preview(SkyPreview p, DateTime now) {
    final kind = switch (p) {
      SkyPreview.cloudy => SkyKind.cloudy,
      SkyPreview.windy => SkyKind.windy,
      SkyPreview.rain => SkyKind.rain,
      SkyPreview.snow => SkyKind.snow,
      SkyPreview.fog => SkyKind.fog,
      SkyPreview.heat => SkyKind.heat,
      _ => SkyKind.clear,
    };
    return SkyView(
      kind: kind,
      previous: kind,
      blend: 1,
      rainbow: p == SkyPreview.rainbow ? 1 : 0,
      minuteOfDay: switch (p) {
        SkyPreview.dusk => 18 * 60,
        SkyPreview.night => 22 * 60,
        _ => 12 * 60,
      },
      // 반딧불은 여름 밤에만 나온다. 밤 미리 보기에서는 보이게 한다.
      month: switch (p) {
        SkyPreview.night || SkyPreview.summer => 7,
        SkyPreview.spring => 4,
        SkyPreview.autumn => 10,
        SkyPreview.winter => 1,
        _ => now.month,
      },
      previewing: true,
    );
  }

  final SkyKind kind;
  final SkyKind previous;

  /// 0이면 아직 이전 날씨, 1이면 새 날씨로 다 바뀜.
  final double blend;

  /// 무지개 진하기(0~1).
  final double rainbow;
  final double minuteOfDay;
  final int month;
  final bool previewing;

  Season get season => seasonOf(month);

  /// [k] 날씨가 지금 얼마나 보이는지(0~1).
  double weight(SkyKind k) => (k == kind ? blend : 0) + (k == previous ? 1 - blend : 0);

  /// 밤의 어두움(0~1). 20시~4시 반은 가장 어둡고, 해 질 녘·새벽에 서서히 바뀐다.
  double get darkness {
    final m = minuteOfDay;
    if (m >= 20 * 60 || m < 4.5 * 60) return 1;
    if (m >= 17.5 * 60) return (m - 17.5 * 60) / 150;
    if (m < 6.5 * 60) return 1 - (m - 4.5 * 60) / 120;
    return 0;
  }

  /// 노을빛(0~1). 18시에 가장 진하다.
  double get duskGlow => _peak(minuteOfDay, 18 * 60, 75);

  /// 새벽빛(0~1). 5시 45분에 가장 진하다.
  double get dawnGlow => _peak(minuteOfDay, 5.75 * 60, 65);

  static double _peak(double m, double at, double half) => (1 - (m - at).abs() / half).clamp(0.0, 1.0);

  /// 동물이 비·눈·밤·폭염을 피해 쉼터 쪽으로 모이는 정도(0~1).
  double get shelter => math.max(
    math.max(weight(SkyKind.rain), weight(SkyKind.snow)) * 0.8,
    math.max(darkness * 0.6, weight(SkyKind.heat) * 0.6),
  );

  @override
  bool operator ==(Object other) =>
      other is SkyView &&
      other.kind == kind &&
      other.previous == previous &&
      other.blend == blend &&
      other.rainbow == rainbow &&
      other.minuteOfDay == minuteOfDay &&
      other.month == month &&
      other.previewing == previewing;

  @override
  int get hashCode => Object.hash(kind, previous, blend, rainbow, minuteOfDay, month, previewing);
}

double _hash(double x) => (math.sin(x) * 43758.5453).abs() % 1;

/// 처음 한 번 구운 부드러운 얼룩(구름 그림자·안개·하늘 구름). 흰색으로 구워 두고 그릴 때 색을 입힌다.
ui.Image? _puff;

ui.Image get _puffImage => _puff ??= bake(const Rect.fromLTWH(0, 0, 320, 200), 0.5, (c) {
  final rng = math.Random(11);
  final p = Paint()
    ..color = Colors.white
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
  for (var i = 0; i < 7; i++) {
    c.drawCircle(Offset(90 + rng.nextDouble() * 140, 70 + rng.nextDouble() * 60), 42 + rng.nextDouble() * 22, p);
  }
});

void puffAt(Canvas c, Rect dst, Color color) {
  final img = _puffImage;
  c.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    dst,
    Paint()
      ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn)
      ..filterQuality = FilterQuality.low,
  );
}

/// 날씨(빛깔·구름·비·눈·바람·무지개)를 그린다. 장면 위, 표식(말풍선·잠금) 아래에 둔다.
void paintWeather(Canvas c, SkyView sky, Rect view, double t) {
  final area = view.intersect(FarmWorld.bakeArea);
  if (area.isEmpty) return;
  // 화면에 보이는 월드 면적에 맞춰 입자 수를 정해, 확대해도 밀도가 같게 한다.
  final density = (area.width * area.height) / (FarmWorld.size.width * FarmWorld.size.height);

  _washes(c, sky, area);
  _season(c, sky, area, t, density);
  _cloudShadows(c, sky, t);
  final rain = sky.weight(SkyKind.rain);
  if (rain > 0) _rain(c, area, t, rain, density);
  final snow = sky.weight(SkyKind.snow);
  if (snow > 0) _snow(c, area, t, snow, density);
  final wind = sky.weight(SkyKind.windy);
  if (wind > 0) _wind(c, area, t, wind, density);
  final fog = sky.weight(SkyKind.fog);
  if (fog > 0) _fog(c, t, fog);
  final heat = sky.weight(SkyKind.heat);
  if (heat > 0) _heat(c, area, t, heat);
  if (sky.rainbow > 0) _rainbow(c, t, sky.rainbow);
}

/// 하루의 빛깔(새벽·노을·밤)과 밤의 불빛. 날씨 위에 덮는다.
void paintDaylight(Canvas c, SkyView sky, Rect view, double t) {
  final area = view.intersect(FarmWorld.bakeArea);
  if (area.isEmpty) return;
  if (sky.dawnGlow > 0) {
    c.drawRect(area, fill(const Color(0xFFF4C3CF).withValues(alpha: 0.16 * sky.dawnGlow)));
  }
  if (sky.duskGlow > 0) {
    c.drawRect(area, fill(const Color(0xFFF2A65A).withValues(alpha: 0.18 * sky.duskGlow)));
  }
  final d = sky.darkness;
  if (d <= 0) return;
  c.drawRect(
    area,
    Paint()
      ..color = const Color(0xFF4F5F94).withValues(alpha: 0.62 * d)
      ..blendMode = BlendMode.multiply,
  );
  _nightLights(c, sky, t, d);
}

// ---------------------------------------------------------------- 빛깔

void _washes(Canvas c, SkyView sky, Rect area) {
  void tint(SkyKind k, Color color, double alpha) {
    final w = sky.weight(k);
    if (w > 0) c.drawRect(area, fill(color.withValues(alpha: alpha * w)));
  }

  tint(SkyKind.cloudy, const Color(0xFF8E9AA6), 0.12);
  tint(SkyKind.rain, const Color(0xFF5F7388), 0.26);
  tint(SkyKind.snow, const Color(0xFFF7FAFF), 0.3);
  tint(SkyKind.fog, const Color(0xFFF4F1EA), 0.22);
  tint(SkyKind.heat, const Color(0xFFFFC46B), 0.13);

  // 맑은 날·폭염: 지도 밖 왼쪽 위에 있는 해에서 따뜻한 빛이 번진다.
  final sun = sky.weight(SkyKind.clear) * 0.7 + sky.weight(SkyKind.heat) + sky.weight(SkyKind.windy) * 0.4;
  if (sun > 0) {
    const center = Offset(-160, -220);
    c.drawCircle(
      center,
      900,
      Paint()
        ..shader = ui.Gradient.radial(center, 900, [
          const Color(0xFFFFF1C4).withValues(alpha: 0.42 * sun),
          const Color(0x00FFF1C4),
        ]),
    );
  }
}

/// 계절의 땅 빛깔과 꽃잎·낙엽·서리.
void _season(Canvas c, SkyView sky, Rect area, double t, double density) {
  switch (sky.season) {
    case Season.spring:
      c.drawRect(area, fill(const Color(0xFFF7E6EC).withValues(alpha: 0.07)));
      _drift(c, area, t, (34 * density).round(), const [Color(0xFFF3BFD0), Color(0xFFFBE3EA)], 22, 5);
    case Season.summer:
      c.drawRect(area, fill(const Color(0xFF4F8A3C).withValues(alpha: 0.07)));
    case Season.autumn:
      c.drawRect(area, fill(const Color(0xFFE2A04E).withValues(alpha: 0.13)));
      _drift(
        c,
        area,
        t,
        (30 * density).round(),
        const [Color(0xFFD9573F), Color(0xFFE9A23E), Color(0xFFB8643A)],
        16,
        7,
      );
    case Season.winter:
      // 이른 아침(5~9시)에는 서리가 더 하얗게 내려앉는다.
      final frost = sky.minuteOfDay >= 300 && sky.minuteOfDay < 540 ? 0.2 : 0.1;
      c.drawRect(area, fill(const Color(0xFFEAF0F4).withValues(alpha: frost)));
      final speck = (90 * density).round();
      for (var i = 0; i < speck; i++) {
        final seed = i * 1.77 + 0.3;
        c.drawCircle(
          Offset(area.left + _hash(seed) * area.width, area.top + _hash(seed * 6.1) * area.height),
          1.2 + _hash(seed * 2.9) * 1.6,
          fill(Colors.white.withValues(alpha: frost * 2.5)),
        );
      }
  }
}

/// 천천히 흩날리는 꽃잎·낙엽.
void _drift(Canvas c, Rect area, double t, int count, List<Color> colors, double speed, double size) {
  for (var i = 0; i < count; i++) {
    final seed = i * 2.53 + 0.8;
    final x = area.left + (_hash(seed) * area.width + t * speed * (0.6 + _hash(seed * 1.4) * 0.8)) % area.width;
    final y = area.top + (_hash(seed * 4.6) * area.height + t * speed * 0.5) % area.height;
    c.save();
    c.translate(x + math.sin(t * 1.4 + seed) * 10, y);
    c.rotate(t * 1.2 + seed);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: size, height: size * 0.55), fill(colors[i % colors.length]));
    c.restore();
  }
}

/// 밭 위를 천천히 지나가는 구름 그림자.
void _cloudShadows(Canvas c, SkyView sky, double t) {
  var count = 0.0;
  var alpha = 0.0;
  var speed = 0.0;
  for (final (k, n, a, v) in const [
    (SkyKind.clear, 2.0, 0.10, 14.0),
    (SkyKind.cloudy, 7.0, 0.17, 16.0),
    (SkyKind.windy, 5.0, 0.13, 42.0),
    (SkyKind.rain, 9.0, 0.15, 20.0),
    (SkyKind.snow, 6.0, 0.12, 12.0),
  ]) {
    final w = sky.weight(k);
    count += n * w;
    alpha += a * w;
    speed += v * w;
  }
  if (count < 0.5 || alpha <= 0) return;
  final span = FarmWorld.bakeArea.width + 700;
  for (var i = 0; i < count.ceil(); i++) {
    final seed = i * 3.7 + 1;
    final w = 420 + _hash(seed) * 320;
    final x =
        FarmWorld.bakeArea.left - 600 + (_hash(seed * 7.1) * span + t * speed * (0.8 + _hash(seed * 2.3) * 0.4)) % span;
    final y = FarmWorld.bakeArea.top + _hash(seed * 5.3) * FarmWorld.bakeArea.height - w * 0.3;
    final fade = i < count.floor() ? 1.0 : count - count.floor();
    puffAt(c, Rect.fromLTWH(x, y, w, w * 0.62), const Color(0xFF29384A).withValues(alpha: alpha * fade));
  }
}

// ---------------------------------------------------------------- 비·눈·바람·안개·폭염

/// 위에서 내려다본 비: 짧은 빗줄기가 떨어져 동그란 물방울 자국과 번진 얼룩을 남긴다.
void _rain(Canvas c, Rect area, double t, double k, double density) {
  final drops = (320 * density * k).round().clamp(0, 400);
  final streak = Paint()
    ..color = const Color(0xFFF2F7FA).withValues(alpha: 0.75 * k)
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;
  final ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3;
  const slant = Offset(-11, 26);
  for (var i = 0; i < drops; i++) {
    final seed = i * 1.913;
    final period = 0.55 + _hash(seed) * 0.3;
    final phase = t / period + _hash(seed * 3.1);
    final cycle = phase.floor().toDouble();
    final u = phase - cycle;
    final p = Offset(
      area.left + _hash(seed * 12.9 + cycle * 0.37) * area.width,
      area.top + _hash(seed * 78.2 + cycle * 0.53) * area.height,
    );
    if (u < 0.55) {
      final a = p - slant * (1 - u / 0.55);
      c.drawLine(a, a + slant * 0.6, streak);
    } else {
      final v = (u - 0.55) / 0.45;
      ring.color = const Color(0xFFEAF3F7).withValues(alpha: 0.8 * k * (1 - v));
      c.drawOval(Rect.fromCenter(center: p, width: 5 + v * 18, height: 4 + v * 12), ring);
    }
  }
  // 종이가 젖은 듯 번졌다 마르는 얼룩.
  final stains = (44 * density * k).round();
  for (var i = 0; i < stains; i++) {
    final seed = i * 4.77 + 0.5;
    final phase = t / 7 + _hash(seed);
    final cycle = phase.floor().toDouble();
    final u = phase - cycle;
    final p = Offset(
      area.left + _hash(seed * 9.1 + cycle) * area.width,
      area.top + _hash(seed * 3.3 + cycle) * area.height,
    );
    c.drawCircle(
      p,
      12 + _hash(seed * 2.2) * 18,
      fill(Tint.waterDeep.withValues(alpha: 0.16 * k * math.sin(math.pi * u))),
    );
  }
  // 연못과 물탱크에 퍼지는 파문.
  final pond = FarmWorld.pond;
  for (var i = 0; i < 9; i++) {
    final seed = i * 6.1 + 2;
    final phase = t / 1.4 + _hash(seed);
    final cycle = phase.floor().toDouble();
    final u = phase - cycle;
    final p = Offset(
      pond.left + pond.width * (0.2 + 0.6 * _hash(seed * 4.4 + cycle)),
      pond.top + pond.height * (0.25 + 0.5 * _hash(seed * 8.8 + cycle)),
    );
    ring.color = Colors.white.withValues(alpha: 0.7 * k * (1 - u));
    c.drawOval(Rect.fromCenter(center: p, width: 6 + u * 30, height: 4 + u * 18), ring);
  }
}

/// 비스듬히 흩날리는 눈송이. 오래 내릴수록 땅이 하얘진다([_washes]).
void _snow(Canvas c, Rect area, double t, double k, double density) {
  final flakes = (160 * density * k).round().clamp(0, 220);
  for (var i = 0; i < flakes; i++) {
    final seed = i * 2.71 + 0.3;
    final vx = 10 + _hash(seed) * 12;
    final vy = 18 + _hash(seed * 1.7) * 14;
    final x = area.left + (_hash(seed * 5.5) * area.width + t * vx + math.sin(t * 1.3 + seed) * 8) % area.width;
    final y = area.top + (_hash(seed * 9.9) * area.height + t * vy) % area.height;
    c.drawCircle(Offset(x, y), 2 + _hash(seed * 3.3) * 2.6, fill(Colors.white.withValues(alpha: 0.85 * k)));
  }
}

/// 바람: 나뭇잎이 날리고 하얀 바람결이 지나간다.
void _wind(Canvas c, Rect area, double t, double k, double density) {
  final leaves = (70 * density * k).round();
  for (var i = 0; i < leaves; i++) {
    final seed = i * 3.13 + 0.7;
    final vx = 90 + _hash(seed) * 70;
    final x = area.left + (_hash(seed * 6.6) * area.width + t * vx) % area.width;
    final y = area.top + _hash(seed * 2.9) * area.height + math.sin(t * 2.2 + seed) * 14;
    c.save();
    c.translate(x, y);
    c.rotate(t * 3 + seed);
    c.drawOval(
      const Rect.fromLTWH(-8, -3.5, 16, 7),
      fill((i.isEven ? Tint.leaf : Tint.hay).withValues(alpha: 0.85 * k)),
    );
    c.restore();
  }
  final gusts = (16 * density * k).round();
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.4
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < gusts; i++) {
    final seed = i * 5.9 + 1.1;
    final phase = t / 2.6 + _hash(seed);
    final cycle = phase.floor().toDouble();
    final u = phase - cycle;
    final start = Offset(
      area.left + _hash(seed * 3.7 + cycle) * area.width * 0.7 + u * 160,
      area.top + _hash(seed * 7.3 + cycle) * area.height,
    );
    stroke.color = Colors.white.withValues(alpha: 0.8 * k * math.sin(math.pi * u));
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(start.dx + 90, start.dy - 20, start.dx + 180, start.dy)
      ..quadraticBezierTo(start.dx + 225, start.dy + 12, start.dx + 210, start.dy + 28);
    c.drawPath(path, stroke);
  }
}

void _fog(Canvas c, double t, double k) {
  // 지도 전체에 고르게 깔리도록 3열 × 4행 자리에서 천천히 흘러간다.
  final b = FarmWorld.bakeArea;
  for (var i = 0; i < 12; i++) {
    final seed = i * 4.3 + 0.2;
    final w = 520 + _hash(seed) * 260;
    final span = b.width + w;
    final x =
        b.left - w * 0.6 + ((i % 3) / 3 * b.width + _hash(seed * 3.1) * 120 + t * (6 + _hash(seed * 2) * 5)) % span;
    final y = b.top + (i ~/ 3) / 4 * b.height + _hash(seed * 7.7) * 120 - w * 0.2;
    puffAt(c, Rect.fromLTWH(x, y, w, w * 0.55), const Color(0xFFFBF9F4).withValues(alpha: 0.55 * k));
  }
}

/// 폭염: 아지랑이처럼 일렁이는 빛줄기.
void _heat(Canvas c, Rect area, double t, double k) {
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  for (var i = 0; i < 7; i++) {
    final y = area.top + ((i / 7) * area.height - t * 12) % area.height;
    stroke.color = Colors.white.withValues(alpha: 0.09 * k);
    final path = Path()..moveTo(area.left, y);
    for (var x = area.left; x <= area.right; x += 24) {
      path.lineTo(x, y + math.sin(x / 40 + t * 2 + i) * 5);
    }
    c.drawPath(path, stroke);
  }
}

// ---------------------------------------------------------------- 무지개

/// 무지개가 떠 있는 동안 수확 보너스를 알리는 밭 위 반짝임(무지개 띠는 하늘에 그린다, sky_band.dart).
void _rainbow(Canvas c, double t, double k) {
  for (final zone in GameDefs.plotZones) {
    final r = FarmWorld.zones[zone]!;
    for (var i = 0; i < 4; i++) {
      final seed = zone.index * 9.1 + i * 2.3;
      final a = math.max(0.0, math.sin(t * 2.4 + seed * 3));
      if (a == 0) continue;
      final p = Offset(r.left + r.width * (0.15 + 0.7 * _hash(seed)), r.top + r.height * (0.2 + 0.6 * _hash(seed * 4)));
      _sparkle(c, p, 7 * a, const Color(0xFFFFF4C8).withValues(alpha: 0.95 * k * a));
    }
  }
}

void _sparkle(Canvas c, Offset p, double r, Color color) {
  final path = Path()
    ..moveTo(p.dx, p.dy - r)
    ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
    ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
    ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
    ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r)
    ..close();
  c.drawPath(path, fill(color));
}

// ---------------------------------------------------------------- 밤

void _nightLights(Canvas c, SkyView sky, double t, double d) {
  void glow(Offset p, double radius, Color color, double alpha) {
    c.drawCircle(
      p,
      radius,
      Paint()..shader = ui.Gradient.radial(p, radius, [color.withValues(alpha: alpha), color.withValues(alpha: 0)]),
    );
  }

  const lamp = Color(0xFFFFD27A);
  for (final p in FarmWorld.windows) {
    glow(p, 46, lamp, 0.55 * d);
    c.drawRect(Rect.fromCenter(center: p, width: 10, height: 8), fill(const Color(0xFFFFE6A8).withValues(alpha: d)));
  }
  final greenhouse = FarmWorld.zones[ZoneId.greenhouse]!;
  glow(greenhouse.center, 150, const Color(0xFFFFE9B0), 0.18 * d);

  // 연못에 비친 달.
  final pond = FarmWorld.pond;
  c.drawOval(
    Rect.fromCenter(center: pond.center + const Offset(18, -8), width: 26, height: 16),
    fill(const Color(0xFFF6F1DC).withValues(alpha: 0.55 * d * (1 - sky.weight(SkyKind.rain)))),
  );

  // 여름밤(5~9월) 맑거나 흐린 날의 반딧불.
  final calm = sky.weight(SkyKind.clear) + sky.weight(SkyKind.cloudy) + sky.weight(SkyKind.heat);
  if (sky.month < 5 || sky.month > 9 || calm <= 0) return;
  final spots = [FarmWorld.pond.inflate(40), FarmWorld.pasture, FarmWorld.zones[ZoneId.orchard]!];
  for (var i = 0; i < 24; i++) {
    final seed = i * 2.9 + 0.4;
    final r = spots[i % spots.length];
    final blink = math.max(0.0, math.sin(t * 1.8 + seed * 5));
    if (blink == 0) continue;
    final p = Offset(
      r.left + r.width * _hash(seed) + math.sin(t * 0.6 + seed) * 18,
      r.top + r.height * _hash(seed * 3.3) + math.cos(t * 0.5 + seed) * 14,
    );
    glow(p, 12, const Color(0xFFE8F59A), 0.5 * blink * d * calm);
    c.drawCircle(p, 2.2, fill(const Color(0xFFF4FFC2).withValues(alpha: blink * d * calm)));
  }
}
