/// 수채 그림책 스타일 붓 도구와 요소 그림. 좌표는 지도 월드 단위다.
///
/// 정적인 그림은 무거우므로 [FarmWorld]가 한 번 이미지로 구워 쓴다. 흐림(blur)은 구울 때마다 화면 밖 렌더링이
/// 한 번씩 더 일어나 수백 번 쓰면 첫 화면이 수십 초 늦어지므로, 풀밭 얼룩 한 겹에만 쓰고 나머지는 반투명 겹칠로 번짐을 낸다.
/// 매 프레임 그리는 요소(동물·표식)는 번짐 없이 반투명 도형만 쓴다.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../game/defs.dart';

abstract final class Tint {
  static const line = Color(0xFF4A3B2E);
  static const grass = Color(0xFFB9CC8E);
  static const grassDeep = Color(0xFF8DAA62);
  static const leaf = Color(0xFF7FA25A);
  static const leafDeep = Color(0xFF5F8E3A);
  static const soil = Color(0xFFB9875E);
  static const soilLight = Color(0xFFCB9C70);
  static const path = Color(0xFFE2CFA4);
  static const roof = Color(0xFFC2694A);
  static const wall = Color(0xFFEFE2C8);
  static const wood = Color(0xFF8A6A48);
  static const water = Color(0xFF8DB9C9);
  static const waterDeep = Color(0xFF5E92A8);
  static const stone = Color(0xFFCFC6B4);
  static const hay = Color(0xFFE2C077);
  static const tomato = Color(0xFFD9573F);
  static const carrot = Color(0xFFE08A3C);
  static const corn = Color(0xFFF0C94E);
  static const berry = Color(0xFFD8404F);
  static const apple = Color(0xFFCF4A3A);
  static const flowerA = Color(0xFFF3D27A);
  static const flowerB = Color(0xFFF2B5C4);
  static const shadow = Color(0x33402A10);
}

Paint fill(Color c) => Paint()..color = c;
Paint pen(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// 손으로 그린 듯 흔들리는 타원.
Path wobblyOval(Rect r, math.Random rng, {double jitter = 0.06, int steps = 32}) {
  final p = Path();
  final phase = rng.nextDouble() * 6;
  for (var i = 0; i <= steps; i++) {
    final t = i / steps * math.pi * 2;
    final k = 1 + jitter * math.sin(t * 3 + phase) + jitter * 0.6 * math.sin(t * 5 - phase);
    final pt = Offset(r.center.dx + math.cos(t) * r.width / 2 * k, r.center.dy + math.sin(t) * r.height / 2 * k);
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

/// 손으로 그린 듯한 둥근 사각형.
Path wobblyRect(Rect r, math.Random rng, {double amp = 2.2, double radius = 18}) {
  final base = Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
  final out = Path();
  final phase = rng.nextDouble() * 10;
  for (final metric in base.computeMetrics()) {
    var first = true;
    for (var d = 0.0; d <= metric.length; d += 6) {
      final tan = metric.getTangentForOffset(d)!;
      final n = Offset(-tan.vector.dy, tan.vector.dx);
      final o = tan.position + n * (amp * math.sin(d / 23 + phase));
      first ? out.moveTo(o.dx, o.dy) : out.lineTo(o.dx, o.dy);
      first = false;
    }
    out.close();
  }
  return out;
}

/// 수채 얼룩: 같은 모양을 조금씩 어긋나게 옅게 겹쳐 칠하고, 가장자리를 조금 진하게.
void wash(Canvas c, Path shape, Color color, math.Random rng, {int layers = 3, bool edge = true}) {
  for (var i = 0; i < layers; i++) {
    final o = Offset(rng.nextDouble() * 4 - 2, rng.nextDouble() * 4 - 2);
    c.drawPath(shape.shift(o), fill(color.withValues(alpha: 0.45)));
  }
  c.drawPath(shape, fill(color.withValues(alpha: 0.35)));
  if (edge) c.drawPath(shape, pen(Color.lerp(color, Tint.line, 0.3)!.withValues(alpha: 0.35), 2));
}

void dropShadow(Canvas c, Path shape, {Offset offset = const Offset(6, 9)}) {
  c.drawPath(shape.shift(offset), fill(Tint.shadow));
}

void inkOutline(Canvas c, Path shape, {double width = 1.6, double alpha = 0.55}) {
  c.drawPath(shape, pen(Tint.line.withValues(alpha: alpha), width));
}

// ---------------------------------------------------------------- 땅·길

void paintMeadow(Canvas c, Rect r, math.Random rng) {
  c.drawRect(r, fill(Tint.grass));
  const tones = [Color(0xFF9FBA72), Color(0xFFC9D79C), Color(0xFFA8C27E), Color(0xFFD3DCA2)];
  final area = r.width * r.height;
  // 얼룩을 한 겹에 모아 한 번만 번지게 한다(얼룩마다 번지면 구울 때 수백 번 흐림 처리가 일어난다).
  c.saveLayer(r, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10));
  for (var i = 0; i < area / 9000; i++) {
    final p = Offset(r.left + rng.nextDouble() * r.width, r.top + rng.nextDouble() * r.height);
    final s = 30 + rng.nextDouble() * 90;
    c.drawPath(
      wobblyOval(Rect.fromCenter(center: p, width: s * 1.6, height: s), rng),
      fill(tones[i % 4].withValues(alpha: 0.35)),
    );
  }
  c.restore();
  for (var i = 0; i < area / 900; i++) {
    final p = Offset(r.left + rng.nextDouble() * r.width, r.top + rng.nextDouble() * r.height);
    final h = 3 + rng.nextDouble() * 5;
    c.drawLine(
      p,
      p + Offset(rng.nextDouble() * 2 - 1, -h),
      pen(Color.lerp(const Color(0xFF7E9C55), const Color(0xFF5E7E3C), rng.nextDouble())!.withValues(alpha: 0.5), 1.2),
    );
  }
  for (var i = 0; i < area / 5000; i++) {
    final p = Offset(r.left + rng.nextDouble() * r.width, r.top + rng.nextDouble() * r.height);
    c.drawCircle(p, 2 + rng.nextDouble() * 1.5, fill((i.isEven ? Tint.flowerA : Tint.flowerB).withValues(alpha: 0.8)));
  }
}

/// 흙길: 그림자·바탕·자갈.
void paintRoad(Canvas c, Rect r, math.Random rng) {
  final shape = wobblyRect(r, rng, amp: 1.6, radius: r.shortestSide / 2);
  c.drawPath(shape.shift(const Offset(0, 4)), fill(Tint.shadow));
  c.drawPath(shape, fill(Tint.path));
  c.drawPath(shape, fill(const Color(0x22704A20)));
  final n = (r.width * r.height / 260).round();
  for (var i = 0; i < n; i++) {
    final p = Offset(r.left + rng.nextDouble() * r.width, r.top + rng.nextDouble() * r.height);
    c.drawCircle(p, 0.8 + rng.nextDouble() * 1.6, fill(const Color(0x55806040)));
  }
}

// ---------------------------------------------------------------- 나무·건물

void paintTree(Canvas c, Offset p, double r, math.Random rng, {Color leaf = Tint.leaf, Color? fruit, int fruits = 7}) {
  final crown = wobblyOval(Rect.fromCircle(center: p, radius: r), rng, jitter: 0.09);
  dropShadow(c, crown, offset: Offset(r * 0.35, r * 0.45));
  wash(c, crown, leaf, rng, layers: 4);
  c.drawPath(
    wobblyOval(Rect.fromCircle(center: p - Offset(r * 0.3, r * 0.3), radius: r * 0.5), rng),
    fill(const Color(0x55F3F0C8)),
  );
  for (var i = 0; i < 8; i++) {
    final a = rng.nextDouble() * math.pi * 2;
    final d = rng.nextDouble() * r * 0.7;
    final q = p + Offset(math.cos(a) * d, math.sin(a) * d);
    c.drawArc(Rect.fromCircle(center: q, radius: r * 0.22), a, 1.8, false, pen(Tint.line.withValues(alpha: 0.2), 1.2));
  }
  if (fruit != null) {
    for (var i = 0; i < fruits; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final d = rng.nextDouble() * r * 0.65;
      final q = p + Offset(math.cos(a) * d, math.sin(a) * d);
      c.drawCircle(q, r * 0.12, fill(fruit));
      c.drawCircle(q - Offset(r * 0.03, r * 0.03), r * 0.04, fill(const Color(0xAAFFFFFF)));
    }
  }
}

/// 위에서 본 박공지붕 건물: 그림자, 지붕 두 면, 용마루, 판자 결.
void paintGableHouse(Canvas c, Rect r, math.Random rng, {Color roof = Tint.roof, bool vertical = false}) {
  final shape = wobblyRect(r, rng, amp: 1.0, radius: 5);
  dropShadow(c, shape, offset: const Offset(10, 14));
  wash(c, shape, roof, rng, layers: 3);
  final half = Path()
    ..addRect(
      vertical
          ? Rect.fromLTRB(r.center.dx, r.top, r.right, r.bottom)
          : Rect.fromLTRB(r.left, r.center.dy, r.right, r.bottom),
    );
  c.drawPath(Path.combine(PathOperation.intersect, shape, half), fill(const Color(0x2A402A10)));
  final plank = pen(const Color(0x22000000), 1);
  if (vertical) {
    for (var y = r.top + 10; y < r.bottom; y += 12) {
      c.drawLine(Offset(r.left + 4, y), Offset(r.right - 4, y), plank);
    }
    c.drawLine(
      Offset(r.center.dx, r.top + 4),
      Offset(r.center.dx, r.bottom - 4),
      pen(Tint.line.withValues(alpha: 0.6), 1.8),
    );
  } else {
    for (var x = r.left + 10; x < r.right; x += 12) {
      c.drawLine(Offset(x, r.top + 4), Offset(x, r.bottom - 4), plank);
    }
    c.drawLine(
      Offset(r.left + 4, r.center.dy),
      Offset(r.right - 4, r.center.dy),
      pen(Tint.line.withValues(alpha: 0.6), 1.8),
    );
  }
  inkOutline(c, shape);
}

void paintHayBale(Canvas c, Offset p, double r, math.Random rng) {
  final b = wobblyOval(Rect.fromCircle(center: p, radius: r), rng, jitter: 0.05);
  dropShadow(c, b, offset: const Offset(3, 4));
  wash(c, b, Tint.hay, rng, layers: 2);
  c.drawCircle(p, r * 0.55, pen(const Color(0x66A07830), 1.4));
  c.drawCircle(p, r * 0.22, pen(const Color(0x66A07830), 1.2));
  inkOutline(c, b, width: 1.2);
}

/// 울타리: 경계를 따라 말뚝과 가로대.
void paintFence(Canvas c, Path boundary) {
  c.drawPath(boundary.shift(const Offset(1, 3)), pen(const Color(0x33402A10), 3));
  c.drawPath(boundary, pen(Tint.wood, 3));
  for (final m in boundary.computeMetrics()) {
    for (var d = 0.0; d < m.length; d += 30) {
      final t = m.getTangentForOffset(d)!.position;
      c.drawCircle(t + const Offset(1.5, 2.5), 4, fill(Tint.shadow));
      c.drawCircle(t, 3.6, fill(const Color(0xFF7A5A3A)));
    }
  }
}

void paintPond(Canvas c, Rect r, math.Random rng) {
  final shape = wobblyOval(r, rng, jitter: 0.08);
  c.drawPath(shape.shift(const Offset(0, 4)), fill(Tint.shadow));
  wash(c, shape, Tint.water, rng, layers: 4);
  c.drawPath(
    wobblyOval(r.deflate(r.shortestSide * 0.22), rng, jitter: 0.1),
    fill(Tint.waterDeep.withValues(alpha: 0.35)),
  );
  for (var i = 0; i < 3; i++) {
    final y = r.top + r.height * (0.32 + i * 0.16);
    c.drawLine(
      Offset(r.left + r.width * 0.28 + i * 10, y),
      Offset(r.left + r.width * 0.52 + i * 10, y),
      pen(const Color(0x88FFFFFF), 2),
    );
  }
  for (final q in [
    r.topLeft + Offset(r.width * 0.72, r.height * 0.3),
    r.topLeft + Offset(r.width * 0.25, r.height * 0.68),
  ]) {
    final pad = wobblyOval(Rect.fromCircle(center: q, radius: 9), rng, jitter: 0.1);
    wash(c, pad, Tint.leaf, rng, layers: 2);
    c.drawCircle(q + const Offset(3, -2), 2.4, fill(Tint.flowerB));
  }
}

/// 둥근 물탱크(테두리만). 수위는 매 프레임 따로 그린다.
void paintTankBase(Canvas c, Offset center, double r, math.Random rng) {
  final rim = wobblyOval(Rect.fromCircle(center: center, radius: r), rng, jitter: 0.02);
  dropShadow(c, rim, offset: const Offset(6, 9));
  c.drawPath(rim, fill(const Color(0xFFB9B2A2)));
  c.drawCircle(center, r * 0.86, fill(const Color(0xFF6E8F98)));
  for (var i = 0; i < 12; i++) {
    final a = i / 12 * math.pi * 2;
    c.drawCircle(center + Offset(math.cos(a), math.sin(a)) * (r * 0.93), 1.6, fill(const Color(0x885A5246)));
  }
  inkOutline(c, rim);
}

void paintSilo(Canvas c, Offset p, double r, math.Random rng) {
  final s = wobblyOval(Rect.fromCircle(center: p, radius: r), rng, jitter: 0.02);
  dropShadow(c, s, offset: const Offset(5, 7));
  wash(c, s, Tint.stone, rng, layers: 2);
  c.drawCircle(p, r * 0.55, pen(const Color(0x55402A10), 1.4));
  c.drawCircle(p - Offset(r * 0.3, r * 0.3), r * 0.25, fill(const Color(0x66FFFFFF)));
  inkOutline(c, s);
}

void paintCrate(Canvas c, Rect r) {
  c.drawRect(r.shift(const Offset(2, 3)), fill(const Color(0x33402A10)));
  c.drawRect(r, fill(const Color(0xFFC79A64)));
  c.drawLine(r.topLeft, r.bottomRight, pen(const Color(0x55402A10), 1.2));
  c.drawRect(r, pen(Tint.line.withValues(alpha: 0.5), 1.2));
}

// ---------------------------------------------------------------- 밭·작물

/// 갈아 놓은 밭(이랑). 작물은 [paintCrops]로 그 위에 그린다.
void paintBed(Canvas c, Rect r, math.Random rng) {
  final shape = wobblyRect(r, rng, radius: 20);
  dropShadow(c, shape);
  wash(c, shape, Tint.soil, rng, layers: 3);
  for (final y in bedRows(r)) {
    final row = Path()..moveTo(r.left + 14, y);
    for (var x = r.left + 14.0; x <= r.right - 14; x += 10) {
      row.lineTo(x, y + math.sin(x / 17) * 1.6);
    }
    c.drawPath(row.shift(const Offset(0, 6)), pen(const Color(0x40402A10), 7));
    c.drawPath(row, pen(Tint.soilLight.withValues(alpha: 0.9), 6));
  }
  inkOutline(c, shape);
}

Iterable<double> bedRows(Rect r) sync* {
  for (var y = r.top + 28.0; y < r.bottom - 12; y += 32) {
    yield y;
  }
}

/// [crop]의 [stage](0 싹 · 1 잎 · 2 거의 다 자람 · 3 다 자람) 그림을 이랑마다 그린다.
void paintCrops(Canvas c, Rect r, CropId crop, int stage, math.Random rng) {
  for (final y in bedRows(r)) {
    for (var x = r.left + 30.0; x < r.right - 20; x += 30) {
      final p = Offset(x + rng.nextDouble() * 4 - 2, y - 2);
      _plant(c, p, crop, stage, rng);
    }
  }
}

void _plant(Canvas c, Offset p, CropId crop, int stage, math.Random rng) {
  if (stage == 0) {
    c.drawLine(p, p + const Offset(-4, -7), pen(const Color(0xFF7DAA4E), 2.4));
    c.drawLine(p, p + const Offset(4, -7), pen(const Color(0xFF94BE5E), 2.4));
    return;
  }
  final big = stage >= 2;
  switch (crop) {
    case CropId.corn:
      // 옥수수: 키 큰 잎 다발, 다 자라면 노란 이삭.
      final h = big ? 18.0 : 11.0;
      for (final a in [-0.9, -0.3, 0.3, 0.9]) {
        c.drawLine(p, p + Offset(math.sin(a) * h, -math.cos(a) * h), pen(const Color(0xFF6E9E44), big ? 3.2 : 2.4));
      }
      if (stage == 3) {
        c.drawOval(Rect.fromCenter(center: p + const Offset(4, -6), width: 6, height: 11), fill(Tint.corn));
      }
    case CropId.wheat:
      // 밀: 가는 줄기 다발, 자라면 금빛 이삭.
      final h = big ? 16.0 : 10.0;
      final stalk = stage == 3 ? const Color(0xFFD6B25A) : const Color(0xFF8DAE55);
      for (final a in [-0.5, -0.2, 0.1, 0.4]) {
        final tip = p + Offset(math.sin(a) * h * 0.6, -h);
        c.drawLine(p, tip, pen(stalk, 1.6));
        if (big) c.drawOval(Rect.fromCenter(center: tip, width: 3.4, height: 7), fill(stalk));
      }
    case CropId.potato:
      // 감자: 낮게 퍼진 잎 덤불, 꽃이 피면 보랏빛.
      final w = big ? 24.0 : 16.0;
      final bush = wobblyOval(
        Rect.fromCenter(center: p - const Offset(0, 4), width: w, height: w * 0.7),
        rng,
        jitter: 0.16,
      );
      c.drawPath(bush, fill(const Color(0xFF6F9A4C).withValues(alpha: 0.9)));
      if (stage >= 2) {
        for (var i = 0; i < 3; i++) {
          c.drawCircle(
            p + Offset(rng.nextDouble() * 14 - 7, -4 - rng.nextDouble() * 6),
            2.2,
            fill(const Color(0xFFB9A3D6)),
          );
        }
      }
      if (stage == 3) {
        c.drawOval(Rect.fromCenter(center: p + const Offset(5, 3), width: 9, height: 7), fill(const Color(0xFFC8A56E)));
      }
    case CropId.pumpkin:
      // 호박: 넓은 잎 덩굴, 자라면 주황 호박.
      final w = big ? 26.0 : 18.0;
      final leaf = wobblyOval(
        Rect.fromCenter(center: p - const Offset(4, 6), width: w, height: w * 0.8),
        rng,
        jitter: 0.18,
      );
      c.drawPath(leaf, fill(const Color(0xFF5E8E3E).withValues(alpha: 0.9)));
      c.drawPath(leaf, pen(Tint.line.withValues(alpha: 0.2), 1));
      if (stage >= 2) {
        final r = stage == 3 ? 7.5 : 4.0;
        final q = p + const Offset(6, -2);
        c.drawOval(
          Rect.fromCenter(center: q, width: r * 2.3, height: r * 1.8),
          fill(stage == 3 ? Tint.carrot : const Color(0xFFB9C66A)),
        );
        c.drawLine(q - Offset(0, r * 0.9), q - Offset(-2, r * 1.4), pen(Tint.wood, 1.6));
      }
    case CropId.carrot:
      for (final a in [-0.6, 0.0, 0.6]) {
        c.drawLine(p, p + Offset(math.sin(a) * 9, -math.cos(a) * (big ? 12 : 8)), pen(const Color(0xFF6FA244), 2.2));
      }
      if (stage == 3) {
        c.drawOval(Rect.fromCenter(center: p + const Offset(0, 2), width: 9, height: 6), fill(Tint.carrot));
      }
    default:
      final w = big ? 26.0 : 20.0;
      final leaf = wobblyOval(
        Rect.fromCenter(center: p - const Offset(0, 6), width: w, height: w * 0.82),
        rng,
        jitter: 0.12,
      );
      c.drawPath(leaf.shift(const Offset(2, 3)), fill(const Color(0x22402A10)));
      c.drawPath(leaf, fill((crop == CropId.lettuce ? const Color(0xFF8DBE58) : Tint.leafDeep).withValues(alpha: 0.9)));
      c.drawPath(leaf, pen(Tint.line.withValues(alpha: 0.25), 1));
      if (crop == CropId.lettuce && big) {
        c.drawPath(
          wobblyOval(Rect.fromCenter(center: p - const Offset(0, 6), width: w * 0.5, height: w * 0.4), rng),
          fill(const Color(0xFFC6E39A)),
        );
      }
      final fruit = switch (crop) {
        CropId.tomato => Tint.tomato,
        CropId.strawberry => Tint.berry,
        _ => null,
      };
      if (fruit != null && stage == 3) {
        for (var i = 0; i < 3; i++) {
          final q = p + Offset(rng.nextDouble() * 14 - 7, -rng.nextDouble() * 12);
          c.drawCircle(q, 3.6, fill(fruit));
          c.drawCircle(q - const Offset(1, 1), 1.2, fill(const Color(0xBBFFFFFF)));
        }
      } else if (fruit != null && stage == 2) {
        c.drawCircle(p + const Offset(3, -8), 2, fill(Tint.flowerA));
      }
  }
}

/// 온실 유리(작물 위에 덮는다).
void paintGlass(Canvas c, Rect r, math.Random rng) {
  final shape = wobblyRect(r, rng, amp: 0.8, radius: 10);
  c.drawPath(shape, fill(const Color(0x55E6F2F2)));
  for (var x = r.left + 18; x < r.right; x += 18) {
    c.drawLine(Offset(x, r.top + 2), Offset(x, r.bottom - 2), pen(const Color(0x99FFFFFF), 1.6));
  }
  c.drawLine(Offset(r.left + 4, r.center.dy), Offset(r.right - 4, r.center.dy), pen(const Color(0xCCFFFFFF), 2.4));
  c.drawLine(r.topLeft + const Offset(20, 14), r.topLeft + const Offset(80, 14), pen(const Color(0x88FFFFFF), 4));
  inkOutline(c, shape, width: 1.8, alpha: 0.6);
}

/// 과수원 나무 자리: 칸 크기에 맞춰 엇갈린 줄로 심는다(한 그루 약 80×75).
/// 평면 그림과 하늘 보기의 세운 나무(upright.dart)가 같은 자리에 서도록 함께 쓴다.
List<Offset> orchardSpots(Rect r) {
  final cols = math.max(2, (r.width / 80).floor());
  final rows = math.max(2, (r.height / 75).floor());
  final dx = r.width / cols;
  final dy = r.height / rows;
  return [
    for (var row = 0; row < rows; row++)
      for (var col = 0; col < cols; col++)
        if (!(row.isOdd && col == cols - 1))
          Offset(r.left + dx * (col + 0.5) + (row.isOdd ? dx / 2 : 0), r.top + dy * (row + 0.5)),
  ];
}

/// 과수원 나무의 단계별 반지름(0 묘목 · 1 어린 나무 · 2 이상 다 큰 나무).
double orchardTreeRadius(int stage) => switch (stage) {
  0 => 11.0,
  1 => 18.0,
  _ => 25.0,
};

/// 과수원 나무: 단계에 따라 크기·꽃·열매가 바뀐다. 비어 있으면 말뚝만.
void paintOrchard(Canvas c, Rect r, int? stage, math.Random rng) {
  for (final p in orchardSpots(r)) {
    if (stage == null) {
      c.drawLine(p + const Offset(0, 6), p - const Offset(0, 10), pen(Tint.wood, 3));
      c.drawCircle(p + const Offset(0, 6), 6, fill(const Color(0x55806040)));
      continue;
    }
    paintTree(
      c,
      p,
      orchardTreeRadius(stage),
      rng,
      leaf: const Color(0xFF7FA857),
      fruit: stage == 3 ? Tint.apple : (stage == 2 ? Tint.flowerB : null),
      fruits: stage == 3 ? 8 : 5,
    );
  }
}

// ---------------------------------------------------------------- 꾸미기

/// 위에서 본 허수아비: 십자 막대, 밀짚모자, 헝겊 옷.
void paintScarecrowFlat(Canvas c, Offset p, math.Random rng) {
  c.drawOval(Rect.fromCenter(center: p + const Offset(6, 8), width: 60, height: 22), fill(Tint.shadow));
  c.drawLine(p + const Offset(-30, 0), p + const Offset(30, 0), pen(Tint.wood, 4));
  c.drawLine(p + const Offset(0, -10), p + const Offset(0, 26), pen(Tint.wood, 4));
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: p + const Offset(0, 6), width: 30, height: 22),
      const Radius.circular(6),
    ),
    fill(const Color(0xFF7E8FB0)),
  );
  c.drawCircle(p + const Offset(0, -8), 13, fill(Tint.hay));
  c.drawCircle(p + const Offset(0, -8), 13, pen(Tint.wood, 1.6));
  c.drawCircle(p + const Offset(0, -8), 5, fill(const Color(0xFFD9573F)));
}

/// 꽃밭: 줄지어 핀 여러 빛깔 꽃 무리.
void paintFlowerBed(Canvas c, Rect r, math.Random rng) {
  const colors = [Tint.flowerA, Tint.flowerB, Colors.white, Tint.tomato, Color(0xFFB9A3D6)];
  for (var row = 0; row < 5; row++) {
    final bed = wobblyOval(Rect.fromLTWH(r.left + 18, r.top + 22 + row * 44, r.width - 36, 30), rng, jitter: 0.06);
    wash(c, bed, Tint.soil, rng, layers: 2, edge: false);
    for (var i = 0; i < 22; i++) {
      final p = Offset(r.left + 26 + rng.nextDouble() * (r.width - 52), r.top + 28 + row * 44 + rng.nextDouble() * 18);
      c.drawCircle(p + const Offset(1, 2), 4, fill(Tint.shadow));
      c.drawCircle(p, 4, fill(colors[(i + row) % colors.length]));
      c.drawCircle(p, 1.4, fill(Tint.flowerA));
    }
  }
}

// ---------------------------------------------------------------- 아직 넓히지 않은 땅의 장애물

/// 장애물 종류(좌표로 정해지는 그림만 다르다): 0 덤불 · 1 돌무더기 · 2 그루터기 · 3 갈대밭.
const wildKinds = 4;

/// 거친 풀밭 위에 장애물 무리를 그린다.
void paintWild(Canvas c, Rect r, int kind, math.Random rng) {
  wash(c, wobblyRect(r.deflate(2), rng, radius: 26), const Color(0xFF9DB57A), rng, layers: 2, edge: false);
  for (var i = 0; i < 26; i++) {
    final p = Offset(r.left + 14 + rng.nextDouble() * (r.width - 28), r.top + 14 + rng.nextDouble() * (r.height - 28));
    c.drawLine(p, p + Offset(rng.nextDouble() * 4 - 2, -6 - rng.nextDouble() * 6), pen(const Color(0x885E7E3C), 1.4));
  }
  final center = r.center;
  switch (kind) {
    case 0: // 덤불
      for (var i = 0; i < 7; i++) {
        final p = center + Offset(rng.nextDouble() * 140 - 70, rng.nextDouble() * 110 - 55);
        final shape = wobblyOval(Rect.fromCircle(center: p, radius: 20 + rng.nextDouble() * 16), rng, jitter: 0.14);
        dropShadow(c, shape, offset: const Offset(4, 6));
        wash(c, shape, i.isEven ? Tint.grassDeep : Tint.leafDeep, rng, layers: 3);
        for (var j = 0; j < 4; j++) {
          c.drawCircle(
            p + Offset(rng.nextDouble() * 20 - 10, rng.nextDouble() * 20 - 10),
            2.2,
            fill(const Color(0xFFB8463A)),
          );
        }
      }
    case 1: // 돌무더기
      for (var i = 0; i < 8; i++) {
        final p = center + Offset(rng.nextDouble() * 150 - 75, rng.nextDouble() * 110 - 55);
        final rock = wobblyOval(
          Rect.fromCenter(center: p, width: 26 + rng.nextDouble() * 30, height: 18 + rng.nextDouble() * 18),
          rng,
          jitter: 0.1,
        );
        dropShadow(c, rock, offset: const Offset(3, 5));
        wash(c, rock, i.isEven ? Tint.stone : const Color(0xFFB4AC9C), rng, layers: 2);
        inkOutline(c, rock, width: 1.2, alpha: 0.4);
      }
    case 2: // 그루터기와 쓰러진 통나무
      for (var i = 0; i < 3; i++) {
        final p = center + Offset(rng.nextDouble() * 140 - 70, rng.nextDouble() * 100 - 50);
        final stump = Rect.fromCircle(center: p, radius: 16 + rng.nextDouble() * 6);
        c.drawOval(stump.shift(const Offset(3, 5)), fill(Tint.shadow));
        c.drawOval(stump, fill(const Color(0xFFC09A6B)));
        c.drawOval(stump.deflate(5), pen(const Color(0x66704A28), 1.4));
        c.drawOval(stump.deflate(10), pen(const Color(0x66704A28), 1.2));
        c.drawOval(stump, pen(Tint.wood, 2));
      }
      final log = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center + const Offset(10, 44), width: 120, height: 22),
        const Radius.circular(11),
      );
      c.drawRRect(log.shift(const Offset(3, 5)), fill(Tint.shadow));
      c.drawRRect(log, fill(Tint.wood));
      c.drawLine(
        log.outerRect.centerLeft + const Offset(14, 0),
        log.outerRect.centerRight - const Offset(14, 0),
        pen(const Color(0x33000000), 1.4),
      );
    default: // 갈대밭
      final pool = wobblyOval(Rect.fromCenter(center: center, width: 150, height: 90), rng, jitter: 0.12);
      wash(c, pool, Tint.water, rng, layers: 2);
      for (var i = 0; i < 46; i++) {
        final a = rng.nextDouble() * math.pi * 2;
        final d = 50 + rng.nextDouble() * 50;
        final p = center + Offset(math.cos(a) * d * 1.2, math.sin(a) * d * 0.8);
        c.drawLine(
          p,
          p + Offset(rng.nextDouble() * 6 - 3, -18 - rng.nextDouble() * 14),
          pen(const Color(0xFF8A9A5A), 2),
        );
        if (i % 3 == 0) {
          c.drawOval(Rect.fromCenter(center: p + const Offset(0, -26), width: 5, height: 12), fill(Tint.wood));
        }
      }
  }
}

// ---------------------------------------------------------------- 동물(매 프레임, 번짐 없음)

void drawCow(Canvas c, Offset p, double angle, double scale) {
  c.save();
  c.translate(p.dx, p.dy);
  c.rotate(angle);
  c.scale(scale);
  c.drawOval(const Rect.fromLTWH(-17, -8, 40, 24), fill(Tint.shadow));
  final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-20, -12, 40, 24), const Radius.circular(12));
  c.drawRRect(body, fill(const Color(0xFFFBF6EC)));
  c.drawOval(const Rect.fromLTWH(-12, -9, 12, 10), fill(const Color(0xFF4A3B33)));
  c.drawOval(const Rect.fromLTWH(2, 1, 9, 8), fill(const Color(0xFF4A3B33)));
  c.drawCircle(const Offset(24, 0), 8, fill(const Color(0xFFFBF6EC)));
  c.drawOval(const Rect.fromLTWH(27, -5, 7, 10), fill(const Color(0xFFF0B6A8)));
  c.drawRRect(body, pen(Tint.line.withValues(alpha: 0.6), 1.3));
  c.drawCircle(const Offset(24, 0), 8, pen(Tint.line.withValues(alpha: 0.6), 1.3));
  c.restore();
}

void drawGoat(Canvas c, Offset p, double angle, double scale) {
  c.save();
  c.translate(p.dx, p.dy);
  c.rotate(angle);
  c.scale(scale);
  c.drawOval(const Rect.fromLTWH(-12, -5, 28, 16), fill(Tint.shadow));
  final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-14, -8, 28, 16), const Radius.circular(8));
  c.drawRRect(body, fill(const Color(0xFFE9D7BC)));
  c.drawOval(const Rect.fromLTWH(-6, -6, 10, 8), fill(const Color(0xFFB98E62)));
  c.drawCircle(const Offset(17, 0), 6, fill(const Color(0xFFE9D7BC)));
  c.drawLine(const Offset(16, -5), const Offset(12, -10), pen(const Color(0xFF7A6A58), 1.8));
  c.drawLine(const Offset(16, 5), const Offset(12, 10), pen(const Color(0xFF7A6A58), 1.8));
  c.drawRRect(body, pen(Tint.line.withValues(alpha: 0.55), 1.2));
  c.restore();
}

void drawSheep(Canvas c, Offset p, double angle, double scale) {
  c.save();
  c.translate(p.dx, p.dy);
  c.rotate(angle);
  c.scale(scale);
  c.drawCircle(const Offset(3, 4), 12, fill(Tint.shadow));
  for (final o in const [Offset(-6, -5), Offset(-6, 5), Offset(3, -5), Offset(3, 5), Offset(-1, 0), Offset(-9, 0)]) {
    c.drawCircle(o, 7, fill(const Color(0xFFF8F4EA)));
    c.drawCircle(o, 7, pen(Tint.line.withValues(alpha: 0.25), 1));
  }
  c.drawOval(const Rect.fromLTWH(8, -4.5, 9, 9), fill(const Color(0xFF3E3430)));
  c.restore();
}

void drawChicken(Canvas c, Offset p, double t, int i, double scale) {
  final bob = math.sin(t * 6 + i) > 0.7 ? 1.5 : 0.0;
  c.save();
  c.translate(p.dx, p.dy);
  c.scale(scale);
  c.drawCircle(const Offset(2, 3), 7, fill(Tint.shadow));
  c.drawCircle(Offset.zero, 7, fill(const Color(0xFFF7EEDD)));
  c.drawCircle(Offset(5 + bob, -4), 2.6, fill(const Color(0xFFD9573F)));
  c.drawCircle(Offset.zero, 7, pen(Tint.line.withValues(alpha: 0.5), 1.1));
  c.restore();
}

/// 구운 이미지를 만든다(번짐이 들어간 그림을 매 프레임 다시 그리지 않으려고).
ui.Image bake(Rect area, double pixelRatio, void Function(Canvas c) draw) {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.scale(pixelRatio);
  c.translate(-area.left, -area.top);
  draw(c);
  final pic = rec.endRecording();
  final img = pic.toImageSync((area.width * pixelRatio).ceil(), (area.height * pixelRatio).ceil());
  pic.dispose();
  return img;
}
