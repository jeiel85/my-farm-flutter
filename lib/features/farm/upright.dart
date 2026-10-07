/// 눕힌 지도(디오라마) 위에 세워 그리는 구조물·나무·동물·말풍선·이름표.
///
/// 평면 지도는 위에서 본 그림이라 지도판을 눕히면 지붕이 바닥에 붙은 스티커처럼 보인다. 그래서 눕힌 동안에는
/// 각 물체가 땅에 닿는 점을 [FarmTilt] 변환으로 화면에 옮기고, 그 자리에 앞에서 본 모습을 멀수록 작게 세워 그린다.
/// 지도판 밖(변환 바깥)에 그리므로 누르기는 받지 않는다(IgnorePointer). 원본의 빨간 헛간 대신 판자벽에 청회색
/// 함석지붕을 얹은 외양간을 쓴다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/animal_painter.dart';
import '../../game/defs.dart';
import '../../game/sky.dart';
import 'building_look.dart';
import 'farm_world.dart';
import 'sky_band.dart';
import 'sky_layer.dart';
import 'storybook.dart';

class FarmUprightPainter extends CustomPainter {
  FarmUprightPainter({
    required this.view,
    required this.time,
    required this.k,
    required this.scene,
    required this.sky,
    required this.labelOpacity,
  }) : super(repaint: time);

  final Rect view;
  final ValueNotifier<double> time;

  /// 지도판을 눕힌 정도(0~1). 세운 그림은 이만큼 진하게 보인다.
  final double k;
  final FarmScene scene;
  final SkyView sky;
  final double labelOpacity;

  @override
  void paint(Canvas c, Size size) {
    if (k <= 0) return;
    final t = time.value;
    final matrix = FarmTilt.matrix(size, k);
    final scale = FarmMapPainter.scaleFor(view, size);
    final frame = (Offset.zero & size).inflate(30);
    Offset local(Offset world) => (world - view.center) * scale + size.center(Offset.zero);
    Offset screen(Offset world) => MatrixUtils.transformPoint(matrix, local(world));
    double unit(Offset world) =>
        (screen(world + const Offset(5, 0)) - screen(world - const Offset(5, 0))).distance / 10;

    final items = <(double, void Function())>[];
    final lights = <(Offset, double)>[];
    final look = _Look.of(sky);
    for (final p in scene.props) {
      if (!frame.contains(local(p.base))) continue;
      final at = screen(p.base);
      final u = unit(p.base);
      items.add((at.dy, () => _prop(c, p, at, u, look, lights)));
    }
    for (final a in animalPlacements(scene, sky, t)) {
      if (!frame.contains(local(a.at))) continue;
      final at = screen(a.at);
      final u = unit(a.at);
      items.add((at.dy, () => _animal(c, a, at, u)));
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));

    c.saveLayer(Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, k));
    for (final (_, draw) in items) {
      draw();
    }
    look.tint(c, size);
    for (final (p, r) in lights) {
      _glow(c, p, r, sky.darkness);
    }
    for (final b in mapBubbles(scene)) {
      if (!frame.contains(local(b.at))) continue;
      c.save();
      c.translate(screen(b.at).dx, screen(b.at).dy - 14 + b.bob(t) * 0.6);
      c.scale(0.6);
      paintBubble(c, Offset.zero, b.emoji, b.count, highlight: b.highlight);
      c.restore();
    }
    if (labelOpacity > 0) {
      for (final MapEntry(key: id, value: label) in scene.labels.entries) {
        final r = FarmWorld.lotRect(id);
        // 눕힌 지도에서는 칸 앞쪽 가운데에 세워, 안쪽의 구조물을 가리지 않게 한다.
        paintZoneTag(
          c,
          screen(Offset(r.center.dx, r.bottom - 4)),
          label,
          scene.icons[id] ?? Icons.place_outlined,
          0.42,
          labelOpacity,
          bottomCenter: true,
        );
      }
    }
    c.restore();
  }

  void _animal(Canvas c, AnimalPlacement a, Offset at, double u) {
    final width = switch (a.species) {
      Species.cow => 70.0,
      Species.goat || Species.sheep => 50.0,
      Species.chicken => 28.0,
    };
    final s = width / 100 * u * (a.young ? 0.62 : 1);
    final dir = a.heading.dx >= 0 ? 1.0 : -1.0;
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(s * dir, s);
    c.translate(-50, -86);
    paintAnimalSide(c, a.species, variant: a.index);
    c.restore();
  }

  @override
  bool shouldRepaint(FarmUprightPainter old) =>
      old.view != view || old.k != k || old.scene != scene || old.sky != sky || old.labelOpacity != labelOpacity;
}

/// 날씨·때·계절에 따른 빛깔(세운 그림은 지도판의 빛깔 레이어 밖에 있어 따로 입힌다).
class _Look {
  const _Look(this.sky, this.snow, this.season);

  factory _Look.of(SkyView sky) =>
      _Look(sky, math.max(sky.weight(SkyKind.snow), sky.season == Season.winter ? 0.55 : 0.0), sky.season);

  final SkyView sky;

  /// 지붕·나무에 쌓인 눈(0~1).
  final double snow;
  final Season season;

  /// 이미 그린 것 위에만 색을 덧입힌다(srcATop).
  void tint(Canvas c, Size size) {
    void over(Color color, double alpha) {
      if (alpha <= 0) return;
      c.drawRect(
        Offset.zero & size,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..blendMode = BlendMode.srcATop,
      );
    }

    over(const Color(0xFF6F8296), 0.2 * sky.weight(SkyKind.rain));
    over(const Color(0xFFF4F1EA), 0.35 * sky.weight(SkyKind.fog));
    over(const Color(0xFFFFC46B), 0.1 * sky.weight(SkyKind.heat));
    over(const Color(0xFFF2A65A), 0.2 * sky.duskGlow);
    over(const Color(0xFFF4C3CF), 0.14 * sky.dawnGlow);
    over(const Color(0xFF27315A), 0.5 * sky.darkness);
  }
}

double _hash(double x) => (math.sin(x) * 43758.5453).abs() % 1;

void _glow(Canvas c, Offset p, double r, double d) {
  if (d <= 0) return;
  c.drawCircle(
    p,
    r * 3.5,
    Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD27A).withValues(alpha: 0.5 * d),
          const Color(0x00FFD27A),
        ],
      ).createShader(Rect.fromCircle(center: p, radius: r * 3.5)),
  );
  c.drawRect(
    Rect.fromCenter(center: p, width: r * 1.6, height: r * 1.3),
    fill(const Color(0xFFFFE6A8).withValues(alpha: d)),
  );
}

// ---------------------------------------------------------------- 물체별 세운 모습(로컬 단위 = 월드 단위, 원점은 땅에 닿는 앞 가운데)

void _prop(Canvas c, FarmProp p, Offset at, double u, _Look look, List<(Offset, double)> lights) {
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(u);
  void light(Offset localPoint, double r) => lights.add((at + localPoint * u, r * u));
  switch (p.kind) {
    case PropKind.house:
      _building(
        c,
        width: 140,
        wallH: 52,
        roofH: 46,
        wall: Tint.wall,
        roof: Tint.roof,
        snow: look.snow,
        front: (c, a, h) {
          c.drawRect(Rect.fromLTWH(-11, -34, 22, 34), fill(Tint.wood));
          c.drawCircle(const Offset(6, -17), 1.6, fill(const Color(0xFFE2C077)));
          for (final x in [-a * 0.62, a * 0.5]) {
            _window(c, Offset(x, -32), 20, 16);
            light(Offset(x, -32), 7);
          }
          light(const Offset(0, -38), 5);
        },
        extra: (c, a, h, ridge) {
          // 굴뚝
          final chimney = Rect.fromLTWH(a * 0.42, ridge + 4, 12, 26);
          c.drawRect(chimney, fill(const Color(0xFF8C5A44)));
          c.drawRect(chimney, pen(Tint.line.withValues(alpha: 0.5), 1.2));
        },
      );
    case PropKind.barn:
      // 외양간: 판자벽 + 청회색 함석지붕 + 미닫이 판자문.
      _building(
        c,
        width: 112,
        wallH: 56,
        roofH: 34,
        wall: const Color(0xFF9A7650),
        roof: BuildingLook.cowBarnRoof,
        tin: true,
        snow: look.snow,
        front: (c, a, h) {
          final plank = pen(const Color(0x33000000), 1);
          for (var x = -a + 8; x < a; x += 9) {
            c.drawLine(Offset(x, -h + 2), Offset(x, -1), plank);
          }
          final door = Rect.fromLTWH(-20, -40, 40, 40);
          c.drawRect(door, fill(const Color(0xFF6B5038)));
          c.drawLine(const Offset(0, -40), const Offset(0, 0), pen(const Color(0x66000000), 1.4));
          c.drawLine(const Offset(-22, -42), const Offset(22, -42), pen(const Color(0xFF4E3A2A), 2.4));
          _window(c, Offset(0, -h + 10), 14, 9);
          light(const Offset(0, -44), 5);
        },
      );
    case PropKind.coop:
      _building(
        c,
        width: 62,
        wallH: 26,
        roofH: 18,
        wall: const Color(0xFFE2C79A),
        roof: BuildingLook.coopRoof,
        snow: look.snow,
        front: (c, a, h) {
          c.drawOval(
            Rect.fromCenter(center: const Offset(-4, -12), width: 12, height: 14),
            fill(const Color(0xFF4E3A2A)),
          );
          c.drawLine(const Offset(-4, -5), const Offset(12, 4), pen(Tint.wood, 3));
          light(const Offset(-4, -12), 3);
        },
      );
    case PropKind.goatShed || PropKind.sheepShed:
      // 염소·양 우리: 낮은 판자 헛간에 넓은 문. 양 우리는 이끼색 지붕.
      final sheep = p.kind == PropKind.sheepShed;
      _building(
        c,
        width: 96,
        wallH: 40,
        roofH: 26,
        wall: sheep ? const Color(0xFFD8CBB0) : const Color(0xFFB99872),
        roof: sheep ? BuildingLook.sheepRoof : BuildingLook.goatRoof,
        snow: look.snow,
        front: (c, a, h) {
          final plank = pen(const Color(0x33000000), 1);
          for (var x = -a + 8; x < a; x += 9) {
            c.drawLine(Offset(x, -h + 2), Offset(x, -1), plank);
          }
          c.drawRect(const Rect.fromLTWH(-15, -30, 30, 30), fill(const Color(0xFF6B5038)));
          light(const Offset(0, -34), 4);
        },
      );
    case PropKind.mill || PropKind.jamKitchen || PropKind.dairy || PropKind.bakery:
      _workshop(c, p.kind, look, light);
    case PropKind.warehouse:
      _building(
        c,
        width: 176,
        wallH: 46,
        roofH: 26,
        wall: const Color(0xFFCFC2A8),
        roof: BuildingLook.warehouseRoof,
        tin: true,
        snow: look.snow,
        front: (c, a, h) {
          final door = Rect.fromLTWH(-34, -36, 68, 36);
          c.drawRect(door, fill(const Color(0xFF9C8F7A)));
          for (var y = door.top + 5; y < door.bottom; y += 6) {
            c.drawLine(Offset(door.left + 2, y), Offset(door.right - 2, y), pen(const Color(0x33000000), 1));
          }
          c.drawRect(door, pen(Tint.line.withValues(alpha: 0.4), 1.2));
          light(const Offset(0, -40), 5);
        },
      );
    case PropKind.silo:
      _silo(c, p.footprint.width / 2, look.snow);
    case PropKind.hay:
      _hay(c, p.footprint.width / 2);
    case PropKind.tree:
      _tree(c, p.footprint.width / 2, p.seed, p.deep, look);
    case PropKind.scarecrow:
      _scarecrow(c, look);
  }
  c.restore();
}

/// 공방: 방앗간 물레방아, 잼 공방 줄무늬 차양, 치즈 공방 둥근 창, 빵집 굴뚝.
void _workshop(Canvas c, PropKind kind, _Look look, void Function(Offset, double) light) {
  final (wall, roof) = switch (kind) {
    PropKind.mill => (const Color(0xFFEDE3CF), BuildingLook.millRoof),
    PropKind.jamKitchen => (const Color(0xFFF3DCDD), BuildingLook.jamRoof),
    PropKind.dairy => (const Color(0xFFF4EFE3), BuildingLook.dairyRoof),
    _ => (const Color(0xFFC98A64), BuildingLook.bakeryRoof),
  };
  _building(
    c,
    width: 132,
    wallH: 52,
    roofH: 34,
    wall: wall,
    roof: roof,
    snow: look.snow,
    front: (c, a, h) {
      c.drawRect(Rect.fromLTWH(-12, -32, 24, 32), fill(Tint.wood));
      switch (kind) {
        case PropKind.jamKitchen:
          _window(c, Offset(a * 0.55, -30), 20, 14);
          for (var i = 0; i < 4; i++) {
            c.drawRect(
              Rect.fromLTWH(a * 0.55 - 14 + i * 7, -44, 7, 7),
              fill(i.isEven ? const Color(0xFFD9573F) : Colors.white),
            );
          }
        case PropKind.dairy:
          c.drawCircle(Offset(a * 0.55, -30), 9, fill(const Color(0xFFCFE0E6)));
          c.drawCircle(Offset(a * 0.55, -30), 9, pen(Tint.wood, 2));
        case PropKind.bakery:
          _window(c, Offset(a * 0.55, -28), 20, 16);
          for (var x = -a + 6; x < a; x += 12) {
            c.drawLine(Offset(x, -h + 4), Offset(x, -2), pen(const Color(0x22000000), 1));
          }
        default:
          _window(c, Offset(a * 0.55, -30), 18, 16);
      }
      light(const Offset(0, -36), 5);
    },
    extra: (c, a, h, ridge) {
      if (kind == PropKind.bakery) {
        final chimney = Rect.fromLTWH(a * 0.4, ridge + 2, 14, 28);
        c.drawRect(chimney, fill(const Color(0xFF8C5A44)));
        c.drawRect(chimney, pen(Tint.line.withValues(alpha: 0.5), 1.2));
      }
      if (kind == PropKind.mill) {
        // 왼쪽 옆 물레방아.
        final wheel = Offset(-a - 16, -26);
        c.drawCircle(wheel, 24, fill(Tint.wood));
        for (var i = 0; i < 8; i++) {
          final ang = i * math.pi / 4;
          c.drawLine(wheel, wheel + Offset(math.cos(ang), math.sin(ang)) * 24, pen(const Color(0xFF5E4630), 2.2));
        }
        c.drawCircle(wheel, 24, pen(Tint.line.withValues(alpha: 0.5), 1.4));
      }
    },
  );
}

void _window(Canvas c, Offset center, double w, double h) {
  final r = Rect.fromCenter(center: center, width: w, height: h);
  c.drawRect(r, fill(const Color(0xFFCFE0E6)));
  c.drawLine(r.topCenter, r.bottomCenter, pen(Tint.wood, 1.4));
  c.drawLine(r.centerLeft, r.centerRight, pen(Tint.wood, 1.4));
  c.drawRect(r, pen(Tint.wood, 1.8));
}

/// 앞에서 비스듬히 본 박공집. 앞벽·오른쪽 옆벽·옆면 박공·앞쪽 지붕면.
void _building(
  Canvas c, {
  required double width,
  required double wallH,
  required double roofH,
  required Color wall,
  required Color roof,
  required double snow,
  required void Function(Canvas c, double halfWidth, double wallH) front,
  void Function(Canvas c, double halfWidth, double wallH, double ridgeY)? extra,
  bool tin = false,
}) {
  final a = width * 0.46;
  final h = wallH;
  final d = Offset(width * 0.12, -width * 0.07); // 옆벽이 물러나는 방향
  final ink = pen(Tint.line.withValues(alpha: 0.55), 1.5);
  final side = Color.lerp(wall, Tint.line, 0.22)!;

  c.drawOval(
    Rect.fromCenter(center: Offset(d.dx * 0.6, 1), width: width * 1.15, height: width * 0.16),
    fill(Tint.shadow),
  );
  final sideWall = Path()
    ..moveTo(a, 0)
    ..lineTo(a + d.dx, d.dy)
    ..lineTo(a + d.dx, d.dy - h)
    ..lineTo(a, -h)
    ..close();
  c.drawPath(sideWall, fill(side));
  c.drawPath(sideWall, ink);
  final gable = Path()
    ..moveTo(a, -h)
    ..lineTo(a + d.dx, d.dy - h)
    ..lineTo(a + d.dx / 2, d.dy / 2 - h - roofH)
    ..close();
  c.drawPath(gable, fill(Color.lerp(wall, Tint.line, 0.12)!));
  c.drawPath(gable, ink);

  final face = Rect.fromLTRB(-a, -h, a, 0);
  c.drawRect(face, fill(wall));
  // 수채 번짐: 아래쪽이 조금 짙고 위쪽에 빛이 든다.
  c.drawRect(Rect.fromLTRB(-a, -h * 0.35, a, 0), fill(Tint.line.withValues(alpha: 0.06)));
  c.drawRect(Rect.fromLTRB(-a, -h, a, -h * 0.8), fill(Colors.white.withValues(alpha: 0.12)));
  front(c, a, h);
  c.drawRect(face, ink);

  final ridgeY = d.dy / 2 - h - roofH;
  const over = 6.0;
  final roofFace = Path()
    ..moveTo(-a - over, -h + 3)
    ..lineTo(a + over, -h + 3)
    ..lineTo(a + d.dx / 2 + over, ridgeY)
    ..lineTo(-a + d.dx / 2 - over, ridgeY)
    ..close();
  extra?.call(c, a, h, ridgeY);
  c.drawPath(roofFace, fill(roof));
  final roofBounds = roofFace.getBounds();
  c.save();
  c.clipPath(roofFace);
  if (tin) {
    // 함석 골: 처마에서 용마루로 가는 줄.
    for (var x = -a - over; x < a + over; x += 7) {
      final f = (x + a + over) / (2 * (a + over));
      c.drawLine(
        Offset(x, -h + 3),
        Offset(-a + d.dx / 2 - over + f * (2 * (a + over)), ridgeY),
        pen(Colors.white.withValues(alpha: 0.16), 1.6),
      );
    }
  } else {
    for (var y = -h + 3 - 8; y > ridgeY; y -= 9) {
      c.drawLine(Offset(roofBounds.left, y), Offset(roofBounds.right, y), pen(const Color(0x22000000), 1.2));
    }
  }
  // 처마 쪽 그늘, 용마루 쪽 빛.
  c.drawRect(Rect.fromLTRB(roofBounds.left, -h - 4, roofBounds.right, -h + 4), fill(Tint.line.withValues(alpha: 0.12)));
  if (snow > 0) {
    c.drawRect(
      Rect.fromLTRB(roofBounds.left, ridgeY, roofBounds.right, ridgeY + roofH * 0.55),
      fill(const Color(0xFFF8FAFC).withValues(alpha: 0.9 * snow)),
    );
  }
  c.restore();
  c.drawPath(roofFace, ink);
  c.drawLine(
    Offset(-a + d.dx / 2 - over, ridgeY),
    Offset(a + d.dx / 2 + over, ridgeY),
    pen(Color.lerp(roof, Tint.line, 0.4)!, 2.4),
  );
}

void _silo(Canvas c, double r, double snow) {
  final w = r * 1.8;
  const h = 96.0;
  final body = Rect.fromLTWH(-w / 2, -h, w, h);
  c.drawOval(Rect.fromCenter(center: const Offset(6, 1), width: w * 1.4, height: w * 0.3), fill(Tint.shadow));
  c.drawRect(
    body,
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE4DDCD), Tint.stone, Color(0xFFA9A091)],
        stops: [0, 0.45, 1],
      ).createShader(body),
  );
  for (var y = -h + 16; y < 0; y += 16) {
    c.drawLine(Offset(-w / 2, y), Offset(w / 2, y), pen(const Color(0x33402A10), 1.2));
  }
  c.drawLine(Offset(w * 0.28, -h + 4), Offset(w * 0.28, -4), pen(const Color(0x66402A10), 1.4));
  final dome = Rect.fromLTWH(-w / 2, -h - w * 0.36, w, w * 0.72);
  c.drawArc(dome, math.pi, math.pi, true, fill(const Color(0xFF9FA7A8)));
  if (snow > 0) c.drawArc(dome, math.pi, math.pi, true, fill(const Color(0xFFF8FAFC).withValues(alpha: 0.85 * snow)));
  c.drawArc(dome, math.pi, math.pi, true, pen(Tint.line.withValues(alpha: 0.5), 1.4));
  c.drawRect(body, pen(Tint.line.withValues(alpha: 0.5), 1.4));
}

void _hay(Canvas c, double r) {
  final body = RRect.fromRectAndRadius(Rect.fromLTWH(-r, -r * 1.5, r * 2, r * 1.5), Radius.circular(r * 0.5));
  c.drawOval(Rect.fromCenter(center: const Offset(3, 1), width: r * 2.6, height: r * 0.6), fill(Tint.shadow));
  c.drawRRect(body, fill(Tint.hay));
  final face = Rect.fromCenter(center: Offset(r * 0.55, -r * 0.75), width: r * 0.9, height: r * 1.4);
  c.drawOval(face, fill(const Color(0xFFEDD28E)));
  c.drawOval(face.deflate(r * 0.18), pen(const Color(0x66A07830), 1.2));
  c.drawRRect(body, pen(Tint.line.withValues(alpha: 0.45), 1.2));
}

/// 서 있는 허수아비: 막대, 팔 막대, 헝겊 옷, 밀짚 얼굴과 모자.
void _scarecrow(Canvas c, _Look look) {
  c.drawOval(Rect.fromCenter(center: const Offset(4, 1), width: 40, height: 10), fill(Tint.shadow));
  c.drawLine(Offset.zero, const Offset(0, -62), pen(Tint.wood, 4));
  c.drawLine(const Offset(-26, -44), const Offset(26, -44), pen(Tint.wood, 3.5));
  final coat = Path()
    ..moveTo(-16, -48)
    ..lineTo(16, -48)
    ..lineTo(20, -18)
    ..lineTo(-20, -18)
    ..close();
  c.drawPath(coat, fill(const Color(0xFF7E8FB0)));
  c.drawRect(const Rect.fromLTWH(-6, -40, 8, 8), fill(const Color(0xFFD9573F)));
  c.drawPath(coat, pen(Tint.line.withValues(alpha: 0.5), 1.4));
  c.drawCircle(const Offset(0, -58), 10, fill(Tint.hay));
  c.drawCircle(const Offset(0, -58), 10, pen(Tint.wood, 1.4));
  c.drawOval(Rect.fromCenter(center: const Offset(0, -67), width: 34, height: 9), fill(const Color(0xFFD6B25A)));
  c.drawRect(const Rect.fromLTWH(-9, -78, 18, 12), fill(const Color(0xFFD6B25A)));
  if (look.snow > 0) {
    c.drawOval(
      Rect.fromCenter(center: const Offset(0, -71), width: 30, height: 7),
      fill(const Color(0xFFF8FAFC).withValues(alpha: 0.9 * look.snow)),
    );
  }
}

/// 계절마다 잎 색이 바뀌는 둥근 나무.
void _tree(Canvas c, double r, int seed, bool deep, _Look look) {
  final pick = _hash(seed * 1.7);
  final leaf = switch (look.season) {
    Season.spring => deep ? Tint.leaf : const Color(0xFF9CC77E),
    Season.summer => deep ? Tint.leafDeep : Tint.leaf,
    Season.autumn => [
      const Color(0xFFD9573F),
      const Color(0xFFE9A23E),
      const Color(0xFFB8643A),
      Tint.leaf,
    ][(pick * 4).floor()],
    Season.winter => const Color(0xFF8E9A86),
  };
  final crown = Offset(0, -r * 0.9 - r * 0.8);
  c.drawOval(Rect.fromCenter(center: Offset(r * 0.3, 1), width: r * 2.2, height: r * 0.5), fill(Tint.shadow));
  c.drawRect(Rect.fromLTWH(-r * 0.12, -r * 1.1, r * 0.24, r * 1.1), fill(Tint.wood));
  for (final (o, rr) in [
    (const Offset(-0.45, 0.15), 0.62),
    (const Offset(0.45, 0.1), 0.64),
    (const Offset(0, -0.35), 0.7),
    (Offset.zero, 0.8),
  ]) {
    c.drawCircle(crown + o * r, rr * r, fill(leaf));
  }
  c.drawCircle(crown + Offset(r * 0.3, r * 0.3), r * 0.55, fill(Tint.line.withValues(alpha: 0.12)));
  c.drawCircle(crown - Offset(r * 0.3, r * 0.35), r * 0.38, fill(Colors.white.withValues(alpha: 0.18)));
  if (look.season == Season.spring) {
    for (var i = 0; i < 6; i++) {
      final a = _hash(seed + i * 3.3) * math.pi * 2;
      c.drawCircle(crown + Offset(math.cos(a), math.sin(a)) * r * 0.6, r * 0.1, fill(const Color(0xFFF3C6D3)));
    }
  }
  if (look.snow > 0) {
    c.drawOval(
      Rect.fromCenter(center: crown - Offset(0, r * 0.55), width: r * 1.3, height: r * 0.5),
      fill(const Color(0xFFF8FAFC).withValues(alpha: 0.9 * look.snow)),
    );
  }
}
