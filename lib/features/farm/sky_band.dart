/// 기울인 지도(디오라마)의 원근과, 그 뒤의 하늘·먼 능선, 지도 끝을 가리는 앞 능선.
///
/// 전체 지도에서는 지도판을 뒤로 눕혀 하늘이 보이게 하고, 구역을 확대하면 다시 평평하게 편다([FarmTilt]의 k).
/// 하늘은 실제 시각을 따라 해·달이 지나가고, 지평선은 계절마다 빛깔이 바뀌는 수채 산 능선이다.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../game/sky.dart';
import 'farm_world.dart';
import 'sky_layer.dart';
import 'storybook.dart';

abstract final class FarmTilt {
  /// 다 눕혔을 때 기울기(라디안).
  static const maxAngle = 0.75;

  /// [size] 화면에 그린 지도를 아래 가운데를 축으로 [k](0~1)만큼 눕히는 변환.
  /// 앞쪽(아래)은 조금 커지고 뒤쪽(위)은 작아져, 지도판이 지평선까지 이어져 보인다.
  static Matrix4 matrix(Size size, double k) {
    if (k <= 0) return Matrix4.identity();
    // 세로로 더 늘려 눕힌 뒤에도 지평선이 화면 위쪽 30% 근처에 오게 하고, 가로는 조금만 늘려 앞쪽 양옆이
    // 덜 잘리게 한다.
    final sx = 1 + 0.12 * k;
    final sy = 1 + 0.35 * k;
    final persp = Matrix4.identity()..setEntry(3, 2, -0.6 * k / (size.height * sy));
    return Matrix4.translationValues(size.width / 2, size.height, 0)
      ..multiply(persp)
      ..rotateX(maxAngle * k)
      ..scaleByDouble(sx, sy, 1, 1)
      ..translateByDouble(-size.width / 2, -size.height, 0, 1);
  }

  /// 눕힌 지도의 먼 끝(지평선)의 화면 높이.
  static double horizonY(Size size, double k) =>
      k <= 0 ? 0 : MatrixUtils.transformPoint(matrix(size, k), Offset(size.width / 2, 0)).dy;
}

double _hash(double x) => (math.sin(x) * 43758.5453).abs() % 1;

/// 계절별 능선 빛깔(먼 → 가까운). 꽃·단풍·눈 같은 점 색과 함께.
(List<Color>, List<Color>) _ridgeColors(Season season) => switch (season) {
  Season.spring => (
    const [Color(0xFFBCCDB9), Color(0xFFA9C795), Color(0xFF98BC7E)],
    const [Color(0xFFF3C6D3), Color(0xFFFBE3EA)],
  ),
  Season.summer => (const [Color(0xFFA3BBB0), Color(0xFF84A971), Color(0xFF6F9C5E)], const [Color(0xFF5E8A4C)]),
  Season.autumn => (
    const [Color(0xFFC7BAA2), Color(0xFFC9925E), Color(0xFFB27A45)],
    const [Color(0xFFD9573F), Color(0xFFE9A23E), Color(0xFFC0453A)],
  ),
  Season.winter => (const [Color(0xFFCBD3DB), Color(0xFFB7C1CA), Color(0xFFA9B4A6)], const [Color(0xFFF7FAFC)]),
};

Path _ridge(double width, double base, double amp, double seed, {double? bottom}) {
  final floor = bottom ?? base + amp * 2;
  final path = Path()..moveTo(-10, floor);
  for (var x = -10.0; x <= width + 10; x += 8) {
    final y =
        base -
        amp *
            (0.55 +
                0.3 * math.sin(x / 61 + seed) +
                0.18 * math.sin(x / 23 + seed * 2.3) +
                0.08 * math.sin(x / 9 + seed * 5.1));
    path.lineTo(x, y);
  }
  return path
    ..lineTo(width + 10, floor)
    ..close();
}

Color _night(Color c, double d) => Color.lerp(c, const Color(0xFF2E3A55), 0.6 * d)!;

/// 하늘과 먼 능선. 눕힌 지도 뒤에 그린다.
class SkyBackPainter extends CustomPainter {
  SkyBackPainter({required this.sky, required this.time, required this.horizon, required this.k})
    : super(repaint: time);

  final SkyView sky;
  final ValueNotifier<double> time;
  final double horizon;
  final double k;

  @override
  void paint(Canvas c, Size size) {
    final t = time.value;
    final w = size.width;
    final h = horizon;
    c.drawRect(Rect.fromLTRB(0, h - 2, w, size.height), fill(FarmWorld.groundColor));
    final skyRect = Rect.fromLTRB(0, 0, w, h + 2);
    final (top, bottom) = _skyColors();
    c.drawRect(skyRect, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [top, bottom]));
    c.save();
    c.clipRect(skyRect);
    _stars(c, w, h, t);
    _sunAndMoon(c, w, h);
    _rainbow(c, w, h);
    _clouds(c, w, h, t);
    _fall(c, w, h, t);
    _ridges(c, w, h);
    c.restore();
  }

  (Color, Color) _skyColors() {
    var top = const Color(0xFF9CC6DE);
    var bottom = const Color(0xFFF3EEDF);
    for (final (kind, tTop, tBottom) in const [
      (SkyKind.cloudy, Color(0xFFAEB9C3), Color(0xFFE8E6DF)),
      (SkyKind.rain, Color(0xFF8796A5), Color(0xFFD5D9DA)),
      (SkyKind.snow, Color(0xFFC6D0D9), Color(0xFFF1F3F2)),
      (SkyKind.fog, Color(0xFFD6DAD6), Color(0xFFF2EFE8)),
      (SkyKind.heat, Color(0xFFB4D3E0), Color(0xFFFBEBC6)),
    ]) {
      final wgt = sky.weight(kind);
      top = Color.lerp(top, tTop, wgt)!;
      bottom = Color.lerp(bottom, tBottom, wgt)!;
    }
    top = Color.lerp(top, const Color(0xFFC7B3DA), sky.dawnGlow * 0.8)!;
    bottom = Color.lerp(bottom, const Color(0xFFF7D2D6), sky.dawnGlow * 0.8)!;
    top = Color.lerp(top, const Color(0xFFE59A72), sky.duskGlow * 0.85)!;
    bottom = Color.lerp(bottom, const Color(0xFFF7D49E), sky.duskGlow * 0.85)!;
    top = Color.lerp(top, const Color(0xFF1C2645), sky.darkness)!;
    bottom = Color.lerp(bottom, const Color(0xFF3A4870), sky.darkness)!;
    return (top, bottom);
  }

  /// 구름·비·눈·안개가 하늘을 가리는 정도(0~1).
  double get _overcast =>
      (sky.weight(SkyKind.cloudy) * 0.45 +
              sky.weight(SkyKind.rain) * 0.9 +
              sky.weight(SkyKind.snow) * 0.8 +
              sky.weight(SkyKind.fog) * 0.85)
          .clamp(0.0, 1.0);

  void _stars(Canvas c, double w, double h, double t) {
    final a = sky.darkness * (1 - _overcast);
    if (a <= 0) return;
    for (var i = 0; i < 46; i++) {
      final seed = i * 7.13 + 0.9;
      final twinkle = 0.55 + 0.45 * math.sin(t * (1 + _hash(seed) * 2) + seed);
      c.drawCircle(
        Offset(_hash(seed) * w, _hash(seed * 3.7) * h * 0.85),
        0.8 + _hash(seed * 5.1) * 1.3,
        fill(const Color(0xFFFFF8DC).withValues(alpha: a * twinkle)),
      );
    }
  }

  /// 해는 6시에 왼쪽 지평선에서 떠 18시 30분에 오른쪽으로 지고, 달은 그 반대 시간에 지나간다.
  void _sunAndMoon(Canvas c, double w, double h) {
    final m = sky.minuteOfDay;
    final seen = 1 - _overcast * 0.85;
    Offset arc(double u) => Offset(w * (0.08 + 0.84 * u), h * (0.92 - 0.72 * math.sin(math.pi * u)));
    if (m >= 360 && m <= 1110) {
      final u = (m - 360) / 750;
      final p = arc(u);
      final low = 1 - math.sin(math.pi * u);
      final core = Color.lerp(const Color(0xFFF6D77A), const Color(0xFFF08A4F), low * low)!;
      final glow = math.min(w, h) * 0.32;
      c.drawCircle(
        p,
        glow,
        Paint()..shader = ui.Gradient.radial(p, glow, [core.withValues(alpha: 0.45 * seen), core.withValues(alpha: 0)]),
      );
      c.drawCircle(p, 15, fill(core.withValues(alpha: seen)));
    } else {
      final u = ((m - 1110 + 1440) % 1440) / 690;
      if (u > 1) return;
      final p = arc(u.clamp(0.0, 1.0));
      final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: p, radius: 12)),
        Path()..addOval(Rect.fromCircle(center: p + const Offset(5, -3), radius: 10.5)),
      );
      c.drawCircle(
        p,
        34,
        Paint()
          ..shader = ui.Gradient.radial(p, 34, [
            const Color(0xFFF6F1DC).withValues(alpha: 0.25 * seen),
            const Color(0x00F6F1DC),
          ]),
      );
      c.drawPath(moon, fill(const Color(0xFFF6F1DC).withValues(alpha: seen)));
    }
  }

  void _rainbow(Canvas c, double w, double h) {
    if (sky.rainbow <= 0) return;
    const colors = [
      Color(0xFFE07A6A),
      Color(0xFFEFA65E),
      Color(0xFFF1D26E),
      Color(0xFF9CC77E),
      Color(0xFF7DB4C9),
      Color(0xFF8A93C9),
      Color(0xFFB08BC2),
    ];
    final center = Offset(w * 0.34, h * 1.12);
    final band = w * 0.018;
    for (var i = 0; i < colors.length; i++) {
      c.drawCircle(
        center,
        h * 0.95 - i * band,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = band + 1.5
          ..color = colors[i].withValues(alpha: 0.5 * sky.rainbow),
      );
    }
  }

  void _clouds(Canvas c, double w, double h, double t) {
    var count = 0.0;
    var speed = 0.0;
    var grey = 0.0;
    for (final (kind, n, v, g) in const [
      (SkyKind.clear, 3.0, 5.0, 0.0),
      (SkyKind.windy, 5.0, 18.0, 0.1),
      (SkyKind.cloudy, 8.0, 6.0, 0.25),
      (SkyKind.rain, 10.0, 8.0, 0.6),
      (SkyKind.snow, 7.0, 4.0, 0.35),
      (SkyKind.fog, 6.0, 3.0, 0.15),
      (SkyKind.heat, 1.0, 3.0, 0.0),
    ]) {
      final wgt = sky.weight(kind);
      count += n * wgt;
      speed += v * wgt;
      grey += g * wgt;
    }
    final base = Color.lerp(const Color(0xFFFFFFFF), const Color(0xFF8A96A3), grey)!;
    final color = Color.lerp(base, const Color(0xFF55607E), sky.darkness * 0.8)!;
    final span = w + 260;
    for (var i = 0; i < count.ceil(); i++) {
      final seed = i * 2.91 + 0.4;
      final cw = w * (0.32 + _hash(seed) * 0.28);
      final x = -cw + (_hash(seed * 5.3) * span + t * speed * (0.7 + _hash(seed * 1.9) * 0.6)) % span;
      final y = h * (0.06 + _hash(seed * 8.1) * 0.5);
      final fade = i < count.floor() ? 1.0 : count - count.floor();
      // 번진 테두리 위에 물감 덩어리 몇 개를 겹쳐 수채 구름처럼 보이게 한다.
      puffAt(c, Rect.fromLTWH(x, y, cw, cw * 0.5), color.withValues(alpha: 0.55 * fade));
      for (var j = 0; j < 5; j++) {
        final r = cw * (0.1 + _hash(seed * 3 + j) * 0.07);
        final p = Offset(x + cw * (0.25 + j * 0.12), y + cw * (0.27 - (j == 1 || j == 3 ? 0.06 : 0)));
        c.drawCircle(p, r, fill(color.withValues(alpha: 0.5 * fade)));
      }
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x + cw * 0.16, y + cw * 0.26, cw * 0.66, cw * 0.1), Radius.circular(cw)),
        fill(color.withValues(alpha: 0.6 * fade)),
      );
    }
  }

  /// 하늘에서 떨어지는 비·눈.
  void _fall(Canvas c, double w, double h, double t) {
    final rain = sky.weight(SkyKind.rain);
    if (rain > 0) {
      final pen = Paint()
        ..color = const Color(0xFFF1F5F8).withValues(alpha: 0.6 * rain)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 70; i++) {
        final seed = i * 1.37 + 0.2;
        final x = _hash(seed) * (w + 40);
        final y = (_hash(seed * 4.1) * h + t * (260 + _hash(seed * 2.2) * 80)) % (h + 20) - 20;
        c.drawLine(Offset(x, y), Offset(x - 5, y + 16), pen);
      }
    }
    final snow = sky.weight(SkyKind.snow);
    if (snow > 0) {
      for (var i = 0; i < 50; i++) {
        final seed = i * 2.17 + 0.6;
        final x = (_hash(seed) * w + math.sin(t + seed) * 10 + t * 8) % w;
        final y = (_hash(seed * 3.9) * h + t * (22 + _hash(seed * 1.3) * 16)) % h;
        c.drawCircle(Offset(x, y), 1.6 + _hash(seed * 7) * 1.8, fill(Colors.white.withValues(alpha: 0.9 * snow)));
      }
    }
  }

  /// 겹겹이 물러나는 먼 산 능선(가장 가까운 능선은 [HorizonFrontPainter]가 지도 위에 그린다).
  void _ridges(Canvas c, double w, double h) {
    final (ridge, dots) = _ridgeColors(sky.season);
    final d = sky.darkness;
    final haze = sky.weight(SkyKind.fog) * 0.5;
    for (final (i, base, amp) in [(0, h + 2, h * 0.34), (1, h + 2, h * 0.2)]) {
      final color = Color.lerp(_night(ridge[i], d), const Color(0xFFF2EFE8), haze)!;
      final shape = _ridge(w, base, amp, i * 3.3 + 1);
      c.drawPath(shape, fill(color.withValues(alpha: 0.85)));
      c.drawPath(shape.shift(const Offset(0, 3)), fill(color.withValues(alpha: 0.5)));
      if (i == 1) {
        for (var j = 0; j < 40; j++) {
          final seed = j * 3.71 + 0.5;
          final x = _hash(seed) * w;
          final y = base - amp * (0.15 + _hash(seed * 2.7) * 0.45);
          c.drawCircle(
            Offset(x, y),
            1.6 + _hash(seed * 4.4) * 2.2,
            fill(_night(dots[j % dots.length], d).withValues(alpha: 0.75)),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(SkyBackPainter old) => old.sky != sky || old.horizon != horizon || old.k != k;
}

/// 가장 가까운 능선과 나무 줄. 눕힌 지도의 먼 끝선을 가린다(누르기는 통과한다).
class HorizonFrontPainter extends CustomPainter {
  HorizonFrontPainter({required this.sky, required this.horizon, required this.k});

  final SkyView sky;
  final double horizon;
  final double k;

  @override
  void paint(Canvas c, Size size) {
    if (k <= 0) return;
    final w = size.width;
    final (ridge, dots) = _ridgeColors(sky.season);
    final d = sky.darkness;
    final base = horizon + 6 * k;
    // 지도 먼 끝선만 살짝 덮도록 바닥을 지평선 바로 아래에서 닫는다.
    final shape = _ridge(w, base, 14 * k, 7.7, bottom: horizon + 7 * k);
    final color = _night(ridge[2], d);
    c.drawPath(shape, fill(color.withValues(alpha: k)));
    c.drawPath(shape, pen(Tint.line.withValues(alpha: 0.25 * k), 1.2));
    // 능선을 따라 둥근 나무 줄.
    final rng = math.Random(5);
    for (var x = 6.0; x < w; x += 9 + rng.nextDouble() * 14) {
      final r = (2.4 + rng.nextDouble() * 2.6) * k;
      final y = base - 7 * k - rng.nextDouble() * 6 * k;
      final leaf = _night(rng.nextBool() ? dots.first : ridge[1], d);
      c.drawCircle(Offset(x, y), r, fill(Color.lerp(leaf, ridge[2], 0.35)!.withValues(alpha: k)));
    }
  }

  @override
  bool shouldRepaint(HorizonFrontPainter old) => old.sky != sky || old.horizon != horizon || old.k != k;
}
