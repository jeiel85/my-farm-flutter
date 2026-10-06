import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../data/models.dart';

/// 위에서 내려다본 농장 지도. 좌표는 모두 월드 단위(1000 x 1250)다.
abstract final class FarmWorld {
  static const size = Size(1000, 1250);
  static const _margin = 34.0;
  static const _road = 44.0;
  static const _colW = (1000 - 2 * _margin - _road) / 2;
  static const _rowH = (1250 - 2 * _margin - 3 * _road) / 4;

  static double _x(int col) => _margin + col * (_colW + _road);
  static double _y(int row) => _margin + row * (_rowH + _road);
  static Rect _cell(int col, int row) => Rect.fromLTWH(_x(col), _y(row), _colW, _rowH);

  static final Map<ZoneId, Rect> zones = {
    ZoneId.house: _cell(0, 0),
    ZoneId.tomato: _cell(1, 0),
    ZoneId.vegetable: _cell(0, 1),
    ZoneId.corn: _cell(1, 1),
    ZoneId.animals: _cell(0, 2),
    ZoneId.water: Rect.fromLTWH(_x(1), _y(2), _colW, 150),
    ZoneId.storage: Rect.fromLTWH(_x(1), _y(2) + 162, _colW, _rowH - 162),
    ZoneId.greenhouse: _cell(0, 3),
    ZoneId.orchard: _cell(1, 3),
  };

  static Rect get bounds => Offset.zero & size;

  /// 가로 도로(행 사이) 중 트랙터가 다니는 도로의 세로 중심.
  static double get tractorRoadY => _y(2) - _road / 2;

  static ZoneId? hitTest(Offset world) {
    for (final e in zones.entries) {
      if (e.value.inflate(6).contains(world)) return e.key;
    }
    return null;
  }

  /// 구역을 [aspect](가로/세로) 비율의 화면에 꽉 차게 보여 줄 카메라 영역.
  static Rect focusRect(ZoneId zone, double aspect) {
    final r = zones[zone]!.inflate(58);
    var w = r.width;
    var h = r.height;
    if (w / h > aspect) {
      h = w / aspect;
    } else {
      w = h * aspect;
    }
    return Rect.fromCenter(center: r.center, width: w, height: h);
  }

  /// 전체 지도를 담는 카메라 영역.
  static Rect overviewRect(double aspect) {
    final r = bounds;
    var w = r.width;
    var h = r.height;
    if (w / h > aspect) {
      h = w / aspect;
    } else {
      w = h * aspect;
    }
    return Rect.fromCenter(center: r.center, width: w, height: h);
  }

  static ui.Picture? _static;

  /// 움직이지 않는 지형·건물·작물은 한 번만 그려 재사용한다.
  static ui.Picture get staticLayer {
    final cached = _static;
    if (cached != null) return cached;
    final recorder = ui.PictureRecorder();
    _StaticPainter(Canvas(recorder)).paint();
    return _static = recorder.endRecording();
  }
}

// ---------------------------------------------------------------- 팔레트

abstract final class _P {
  static const grass = Color(0xFF94C46A);
  static const grassDark = Color(0xFF7FB25A);
  static const grassLight = Color(0xFFA9D27E);
  static const road = Color(0xFFDCCA9E);
  static const roadEdge = Color(0xFFC9B482);
  static const soil = Color(0xFF8C5E3B);
  static const soilDark = Color(0xFF6F4529);
  static const soilLight = Color(0xFFA27548);
  static const leaf = Color(0xFF4C8C36);
  static const leafLight = Color(0xFF7CC456);
  static const treeDark = Color(0xFF3C7A35);
  static const tree = Color(0xFF4F9442);
  static const roofRed = Color(0xFFC9473C);
  static const roofRedDark = Color(0xFFA7362E);
  static const wood = Color(0xFF8A6239);
  static const water = Color(0xFF4AA3DF);
  static const waterDeep = Color(0xFF2F82C2);
  static const waterLight = Color(0xFF8CCBF0);
  static const steel = Color(0xFF9AA6AE);
  static const steelDark = Color(0xFF6E7C86);
  static const hay = Color(0xFFE6BE55);
  static const shadow = Color(0x33000000);
}

Paint _fill(Color c) => Paint()..color = c;
Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round;

void _tree(Canvas c, Offset p, double r, {Color canopy = _P.tree, Color? fruit, math.Random? rng}) {
  c.drawCircle(p + Offset(r * 0.25, r * 0.3), r, _fill(_P.shadow));
  c.drawCircle(p, r, _fill(_P.treeDark));
  c.drawCircle(p - Offset(r * 0.18, r * 0.18), r * 0.78, _fill(canopy));
  c.drawCircle(p - Offset(r * 0.35, r * 0.35), r * 0.32, _fill(Colors.white.withValues(alpha: 0.12)));
  if (fruit != null && rng != null) {
    for (var i = 0; i < 6; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final d = rng.nextDouble() * r * 0.7;
      c.drawCircle(p + Offset(math.cos(a) * d, math.sin(a) * d), r * 0.12, _fill(fruit));
    }
  }
}

void _hayBale(Canvas c, Offset p, double r) {
  c.drawCircle(p + const Offset(2, 3), r, _fill(_P.shadow));
  c.drawCircle(p, r, _fill(_P.hay));
  c.drawCircle(p, r * 0.62, _stroke(const Color(0xFFC99A35), 1.6));
  c.drawCircle(p, r * 0.28, _stroke(const Color(0xFFC99A35), 1.4));
}

/// 위에서 본 박공지붕 건물.
void _gableRoof(Canvas c, Rect r, Color light, Color dark, {bool vertical = false}) {
  c.drawRRect(RRect.fromRectAndRadius(r.shift(const Offset(5, 7)), const Radius.circular(4)), _fill(_P.shadow));
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), _fill(light));
  final half = vertical
      ? Rect.fromLTRB(r.center.dx, r.top, r.right, r.bottom)
      : Rect.fromLTRB(r.left, r.center.dy, r.right, r.bottom);
  c.drawRRect(RRect.fromRectAndRadius(half, const Radius.circular(4)), _fill(dark));
  if (vertical) {
    c.drawLine(Offset(r.center.dx, r.top + 2), Offset(r.center.dx, r.bottom - 2), _stroke(Colors.white24, 2));
  } else {
    c.drawLine(Offset(r.left + 2, r.center.dy), Offset(r.right - 2, r.center.dy), _stroke(Colors.white24, 2));
  }
}

void _soilBed(Canvas c, Rect r, {Color color = _P.soil}) {
  final rr = RRect.fromRectAndRadius(r, const Radius.circular(14));
  c.drawRRect(rr.shift(const Offset(0, 4)), _fill(_P.shadow));
  c.drawRRect(rr, _fill(color));
  c.drawRRect(rr.deflate(3), _stroke(_P.soilDark.withValues(alpha: 0.5), 3));
}

void _fence(Canvas c, Rect r) {
  final rail = _stroke(const Color(0xFFB08A5A), 2.4);
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)), rail);
  final post = _fill(const Color(0xFF7E5B34));
  for (double x = r.left; x <= r.right; x += 22) {
    c.drawCircle(Offset(x, r.top), 2.8, post);
    c.drawCircle(Offset(x, r.bottom), 2.8, post);
  }
  for (double y = r.top; y <= r.bottom; y += 22) {
    c.drawCircle(Offset(r.left, y), 2.8, post);
    c.drawCircle(Offset(r.right, y), 2.8, post);
  }
}

class _StaticPainter {
  _StaticPainter(this.c);

  final Canvas c;
  final rng = math.Random(7);

  void paint() {
    _ground();
    final z = FarmWorld.zones;
    _house(z[ZoneId.house]!);
    _tomato(z[ZoneId.tomato]!);
    _vegetable(z[ZoneId.vegetable]!);
    _corn(z[ZoneId.corn]!);
    _animals(z[ZoneId.animals]!);
    _water(z[ZoneId.water]!);
    _storage(z[ZoneId.storage]!);
    _greenhouse(z[ZoneId.greenhouse]!);
    _orchard(z[ZoneId.orchard]!);
  }

  void _ground() {
    // 카메라가 월드 밖을 비춰도 비어 보이지 않도록 넉넉히 칠한다.
    c.drawRect(const Rect.fromLTWH(-1500, -1500, 4000, 4250), _fill(_P.grass));
    for (var i = 0; i < 900; i++) {
      final p = Offset(rng.nextDouble() * 2400 - 700, rng.nextDouble() * 2650 - 700);
      c.drawCircle(p, 2 + rng.nextDouble() * 5, _fill(_P.grassDark.withValues(alpha: 0.55)));
    }
    // 바깥 숲
    for (var i = 0; i < 140; i++) {
      final p = Offset(rng.nextDouble() * 2400 - 700, rng.nextDouble() * 2650 - 700);
      if (FarmWorld.bounds.inflate(10).contains(p)) continue;
      _tree(c, p, 16 + rng.nextDouble() * 16);
    }
    // 도로
    final road = _fill(_P.road);
    final edge = _stroke(_P.roadEdge, 2);
    final w = FarmWorld.size.width;
    for (var row = 1; row < 4; row++) {
      final y = FarmWorld._y(row) - FarmWorld._road + 8;
      final r = Rect.fromLTWH(-1500, y, 4000, FarmWorld._road - 16);
      c.drawRect(r, road);
      c.drawLine(r.topLeft, r.topRight, edge);
      c.drawLine(r.bottomLeft, r.bottomRight, edge);
    }
    final vx = FarmWorld._x(1) - FarmWorld._road + 8;
    final v = Rect.fromLTWH(vx, -1500, FarmWorld._road - 16, 4250);
    c.drawRect(v, road);
    c.drawLine(v.topLeft, v.bottomLeft, edge);
    c.drawLine(v.topRight, v.bottomRight, edge);
    // 바퀴 자국
    final rut = _stroke(_P.roadEdge.withValues(alpha: 0.6), 1.2);
    for (var row = 1; row < 4; row++) {
      final y = FarmWorld._y(row) - FarmWorld._road / 2;
      c.drawLine(Offset(-1500, y - 6), Offset(w + 1500, y - 6), rut);
      c.drawLine(Offset(-1500, y + 6), Offset(w + 1500, y + 6), rut);
    }
  }

  void _house(Rect r) {
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(18)), _fill(_P.grassLight));
    // 진입로
    final path = Rect.fromLTWH(r.left + 92, r.top + 150, 34, r.bottom - r.top - 150);
    c.drawRect(path, _fill(_P.road));
    _gableRoof(c, Rect.fromLTWH(r.left + 36, r.top + 40, 150, 110), _P.roofRed, _P.roofRedDark);
    c.drawRect(Rect.fromLTWH(r.left + 150, r.top + 50, 14, 18), _fill(const Color(0xFF6B4B3A)));
    // 자동차
    final car = RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 140, r.top + 172, 30, 52), const Radius.circular(8));
    c.drawRRect(car.shift(const Offset(3, 4)), _fill(_P.shadow));
    c.drawRRect(car, _fill(const Color(0xFF2E5C8A)));
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 144, r.top + 184, 22, 14), const Radius.circular(3)),
      _fill(const Color(0xFF9CC7E8)),
    );
    // 텃밭
    final garden = Rect.fromLTWH(r.left + 220, r.top + 40, 120, 92);
    _soilBed(c, garden, color: _P.soilLight);
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 4; x++) {
        c.drawCircle(Offset(garden.left + 20 + x * 27, garden.top + 22 + y * 25), 8, _fill(_P.leafLight));
      }
    }
    _hayBale(c, Offset(r.left + 250, r.top + 190), 15);
    _hayBale(c, Offset(r.left + 284, r.top + 200), 15);
    // 우체통·벤치
    c.drawRect(Rect.fromLTWH(r.left + 60, r.bottom - 26, 10, 10), _fill(_P.roofRed));
    for (var i = 0; i < 6; i++) {
      _tree(c, Offset(r.right - 36, r.top + 30 + i * 40), 16 + rng.nextDouble() * 5);
    }
    _tree(c, Offset(r.left + 26, r.top + 210), 18);
  }

  void _plantRows(Rect bed, double dx, double dy, void Function(Offset p) draw) {
    for (var y = bed.top + dy * 0.8; y < bed.bottom - dy * 0.4; y += dy) {
      for (var x = bed.left + dx * 0.8; x < bed.right - dx * 0.4; x += dx) {
        draw(Offset(x, y));
      }
    }
  }

  void _tomato(Rect r) {
    final bed = r.deflate(8);
    _soilBed(c, bed);
    final furrow = _stroke(_P.soilDark.withValues(alpha: 0.6), 3);
    for (var y = bed.top + 22.0; y < bed.bottom - 10; y += 26) {
      c.drawLine(Offset(bed.left + 12, y + 11), Offset(bed.right - 12, y + 11), furrow);
    }
    _plantRows(bed, 24, 26, (p) {
      c.drawCircle(p + const Offset(1.5, 2), 9, _fill(_P.shadow));
      c.drawCircle(p, 9, _fill(_P.leaf));
      c.drawCircle(p - const Offset(2, 2), 5, _fill(_P.leafLight));
      for (var i = 0; i < 3; i++) {
        final a = rng.nextDouble() * math.pi * 2;
        c.drawCircle(p + Offset(math.cos(a) * 5, math.sin(a) * 5), 2.6, _fill(const Color(0xFFE2453A)));
      }
    });
  }

  void _vegetable(Rect r) {
    final bed = r.deflate(8);
    _soilBed(c, bed);
    final left = Rect.fromLTRB(bed.left, bed.top, bed.center.dx - 4, bed.bottom);
    final right = Rect.fromLTRB(bed.center.dx + 4, bed.top, bed.right, bed.bottom);
    _plantRows(left, 32, 32, (p) {
      c.drawCircle(p + const Offset(1.5, 2), 12, _fill(_P.shadow));
      c.drawCircle(p, 12, _fill(const Color(0xFF5FAE3E)));
      c.drawCircle(p, 8, _fill(_P.leafLight));
      c.drawCircle(p, 3.5, _fill(const Color(0xFFC6EC9C)));
    });
    final stem = _stroke(const Color(0xFF5DA93B), 1.6);
    _plantRows(right, 14, 26, (p) {
      c.drawCircle(p + const Offset(0, 5), 2.6, _fill(const Color(0xFFEE8A2E)));
      for (var i = -1; i <= 1; i++) {
        c.drawLine(p + const Offset(0, 3), p + Offset(i * 4.0, -6), stem);
      }
    });
  }

  void _corn(Rect r) {
    final bed = r.deflate(8);
    _soilBed(c, bed, color: const Color(0xFF9B7A4C));
    final leaf = _stroke(const Color(0xFF9DB84A), 2.2);
    final leafDark = _stroke(const Color(0xFF6E9136), 2.2);
    for (var x = bed.left + 18.0; x < bed.right - 10; x += 18) {
      for (var y = bed.top + 16.0; y < bed.bottom - 10; y += 15) {
        final p = Offset(x, y);
        c.drawLine(p, p + const Offset(-7, -4), leafDark);
        c.drawLine(p, p + const Offset(7, -3), leaf);
        c.drawLine(p, p + const Offset(-5, 5), leaf);
        c.drawLine(p, p + const Offset(6, 5), leafDark);
        c.drawCircle(p, 2.2, _fill(const Color(0xFFF1D35A)));
      }
    }
  }

  void _animals(Rect r) {
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(18)), _fill(const Color(0xFFA2CF72)));
    final pasture = r.deflate(12);
    for (var i = 0; i < 40; i++) {
      final p = Offset(
        pasture.left + rng.nextDouble() * pasture.width,
        pasture.top + rng.nextDouble() * pasture.height,
      );
      c.drawCircle(p, 3 + rng.nextDouble() * 6, _fill(_P.grassLight));
    }
    // 진흙
    c.drawOval(Rect.fromLTWH(r.left + 230, r.top + 160, 90, 46), _fill(const Color(0xFFB59468).withValues(alpha: 0.7)));
    _fence(c, pasture);
    _gableRoof(c, Rect.fromLTWH(r.left + 26, r.top + 26, 118, 82), _P.roofRed, _P.roofRedDark, vertical: true);
    // 축사 문
    c.drawRect(Rect.fromLTWH(r.left + 70, r.top + 106, 30, 6), _fill(Colors.white));
    // 닭장
    _gableRoof(c, Rect.fromLTWH(r.left + 40, r.bottom - 74, 60, 44), _P.wood, const Color(0xFF6E4D2C));
    // 건초·물통
    _hayBale(c, Offset(r.left + 170, r.top + 52), 14);
    _hayBale(c, Offset(r.left + 202, r.top + 46), 14);
    _hayBale(c, Offset(r.left + 186, r.top + 76), 14);
    final trough = RRect.fromRectAndRadius(Rect.fromLTWH(r.right - 100, r.top + 34, 64, 18), const Radius.circular(6));
    c.drawRRect(trough, _fill(_P.steel));
    c.drawRRect(trough.deflate(3), _fill(_P.water));
  }

  void _water(Rect r) {
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(18)), _fill(const Color(0xFFA6D27C)));
    // 물탱크
    final tank = Offset(r.left + 80, r.center.dy);
    c.drawCircle(tank + const Offset(5, 7), 56, _fill(_P.shadow));
    c.drawCircle(tank, 56, _fill(_P.steel));
    c.drawCircle(tank, 50, _fill(_P.waterDeep));
    c.drawCircle(tank, 42, _fill(_P.water));
    c.drawCircle(tank - const Offset(14, 14), 14, _fill(Colors.white.withValues(alpha: 0.25)));
    // 배관
    final pipe = _stroke(_P.steelDark, 6);
    c.drawLine(tank + const Offset(56, 0), Offset(r.left + 190, r.center.dy), pipe);
    c.drawRect(Rect.fromLTWH(r.left + 176, r.center.dy - 12, 24, 24), _fill(_P.steelDark));
    // 연못
    final pond = Path()
      ..addOval(Rect.fromLTWH(r.left + 220, r.top + 22, 200, 110))
      ..addOval(Rect.fromLTWH(r.left + 300, r.top + 60, 120, 76));
    c.drawPath(pond.shift(const Offset(3, 5)), _fill(_P.shadow));
    c.drawPath(pond, _fill(_P.waterLight));
    c.save();
    c.translate(r.left + 320, r.top + 82);
    c.scale(0.88, 0.84);
    c.translate(-(r.left + 320), -(r.top + 82));
    c.drawPath(pond, _fill(_P.water));
    c.restore();
    for (final p in [
      Offset(r.left + 260, r.top + 70),
      Offset(r.left + 380, r.top + 110),
      Offset(r.left + 350, r.top + 50),
    ]) {
      c.drawCircle(p, 8, _fill(const Color(0xFF5DA94A)));
      c.drawCircle(p + const Offset(3, -2), 2.5, _fill(const Color(0xFFF2A7C3)));
    }
    _tree(c, Offset(r.right - 20, r.bottom - 20), 15);
  }

  void _storage(Rect r) {
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(16)), _fill(const Color(0xFFC9C3B2)));
    final shed = Rect.fromLTWH(r.left + 26, r.top + 14, 190, r.height - 28);
    c.drawRect(shed.shift(const Offset(5, 7)), _fill(_P.shadow));
    c.drawRect(shed, _fill(const Color(0xFF5E6E80)));
    final rib = _stroke(const Color(0xFF7F90A3), 2);
    for (var x = shed.left + 8; x < shed.right; x += 10) {
      c.drawLine(Offset(x, shed.top + 2), Offset(x, shed.bottom - 2), rib);
    }
    for (var i = 0; i < 2; i++) {
      final s = Offset(r.left + 270 + i * 70, r.center.dy);
      c.drawCircle(s + const Offset(4, 6), 30, _fill(_P.shadow));
      c.drawCircle(s, 30, _fill(_P.steel));
      c.drawCircle(s, 22, _stroke(_P.steelDark, 2));
      c.drawCircle(s, 8, _fill(_P.steelDark));
    }
    // 상자
    for (var i = 0; i < 3; i++) {
      c.drawRect(Rect.fromLTWH(r.right - 42, r.top + 14 + i * 22, 20, 18), _fill(_P.wood));
    }
  }

  void _greenhouse(Rect r) {
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(18)), _fill(_P.grassLight));
    for (var i = 0; i < 2; i++) {
      final g = Rect.fromLTWH(r.left + 18, r.top + 22 + i * 116, r.width - 36, 96);
      final rr = RRect.fromRectAndRadius(g, const Radius.circular(10));
      c.drawRRect(rr.shift(const Offset(4, 6)), _fill(_P.shadow));
      c.drawRRect(rr, _fill(const Color(0xFF6E9C58)));
      // 딸기 줄
      for (var y = g.top + 22; y < g.bottom - 10; y += 26) {
        for (var x = g.left + 16; x < g.right - 10; x += 18) {
          c.drawCircle(Offset(x, y), 6, _fill(_P.leafLight));
          if (rng.nextDouble() < 0.5) c.drawCircle(Offset(x + 3, y + 3), 2.4, _fill(const Color(0xFFE23F4F)));
        }
      }
      c.drawRRect(rr, _fill(const Color(0x88E6F4F7)));
      final rib = _stroke(Colors.white.withValues(alpha: 0.8), 1.6);
      for (var x = g.left + 16; x < g.right; x += 16) {
        c.drawLine(Offset(x, g.top), Offset(x, g.bottom), rib);
      }
      c.drawLine(Offset(g.left, g.center.dy), Offset(g.right, g.center.dy), _stroke(Colors.white, 2.4));
      c.drawRRect(rr, _stroke(Colors.white, 2.4));
    }
  }

  void _orchard(Rect r) {
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(18)), _fill(const Color(0xFF9DCB6E)));
    // 꽃밭
    const flowers = [Color(0xFFF6D04D), Color(0xFFF29BC0), Colors.white];
    for (var i = 0; i < 60; i++) {
      final p = Offset(r.left + 300 + rng.nextDouble() * 120, r.top + 180 + rng.nextDouble() * 70);
      c.drawCircle(p, 2.4, _fill(flowers[i % 3]));
    }
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        if (row == 2 && col >= 3) continue;
        final p = Offset(r.left + 50 + col * 92 + (row.isOdd ? 30 : 0), r.top + 46 + row * 78);
        _tree(c, p, 26, canopy: const Color(0xFF4E9A45), fruit: const Color(0xFFE0453B), rng: rng);
      }
    }
    // 벌통
    for (var i = 0; i < 3; i++) {
      final b = Rect.fromLTWH(r.right - 120 + i * 36, r.bottom - 56, 26, 30);
      c.drawRect(b.shift(const Offset(3, 4)), _fill(_P.shadow));
      c.drawRect(b, _fill(const Color(0xFFF3E7C6)));
      c.drawRect(Rect.fromLTWH(b.left, b.top + 8, b.width, 5), _fill(_P.hay));
      c.drawRect(Rect.fromLTWH(b.left, b.top + 18, b.width, 5), _fill(_P.hay));
    }
  }
}

// ---------------------------------------------------------------- 움직이는 요소

class _Wanderer {
  const _Wanderer(this.home, this.ax, this.ay, this.wx, this.wy, this.phase);

  final Offset home;
  final double ax, ay, wx, wy, phase;

  Offset at(double t) => home + Offset(ax * math.sin(t * wx + phase), ay * math.sin(t * wy + phase * 1.7));

  Offset velocity(double t) =>
      Offset(ax * wx * math.cos(t * wx + phase), ay * wy * 1.0 * math.cos(t * wy + phase * 1.7));
}

final _animalZone = FarmWorld.zones[ZoneId.animals]!;
final _cows = [
  for (var i = 0; i < 6; i++)
    _Wanderer(
      _animalZone.topLeft + Offset(200 + (i % 3) * 70.0, 120 + (i ~/ 3) * 70.0),
      40 + i * 6.0,
      22 + i * 3.0,
      0.11 + i * 0.013,
      0.17 + i * 0.011,
      i * 1.3,
    ),
];
final _sheep = [
  for (var i = 0; i < 3; i++)
    _Wanderer(_animalZone.topLeft + Offset(330 + i * 26.0, 70), 24, 16, 0.14 + i * 0.02, 0.19, i * 2.1),
];
final _hens = [
  for (var i = 0; i < 5; i++)
    _Wanderer(
      _animalZone.topLeft + Offset(140 + i * 18.0, _animalZone.height - 44),
      16,
      9,
      0.5 + i * 0.07,
      0.6,
      i * 1.9,
    ),
];

void _drawCow(Canvas c, Offset p, Offset v) {
  c.save();
  c.translate(p.dx, p.dy);
  c.rotate(math.atan2(v.dy, v.dx));
  c.drawOval(Rect.fromCenter(center: const Offset(2, 3), width: 30, height: 18), _fill(_P.shadow));
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: 30, height: 18), _fill(Colors.white));
  c.drawCircle(const Offset(-6, -3), 4.5, _fill(const Color(0xFF222222)));
  c.drawCircle(const Offset(5, 4), 3.6, _fill(const Color(0xFF222222)));
  c.drawOval(Rect.fromCenter(center: const Offset(17, 0), width: 11, height: 10), _fill(Colors.white));
  c.drawOval(Rect.fromCenter(center: const Offset(21, 0), width: 5, height: 7), _fill(const Color(0xFFF2A6A0)));
  c.drawCircle(const Offset(15, -5), 2, _fill(const Color(0xFF222222)));
  c.drawCircle(const Offset(15, 5), 2, _fill(const Color(0xFF222222)));
  c.restore();
}

void _drawSheep(Canvas c, Offset p, Offset v) {
  c.save();
  c.translate(p.dx, p.dy);
  c.rotate(math.atan2(v.dy, v.dx));
  c.drawCircle(const Offset(2, 3), 11, _fill(_P.shadow));
  for (final o in const [Offset(-5, -4), Offset(-5, 4), Offset(3, -4), Offset(3, 4), Offset(-1, 0)]) {
    c.drawCircle(o, 6.5, _fill(const Color(0xFFF7F3EA)));
  }
  c.drawOval(Rect.fromCenter(center: const Offset(11, 0), width: 8, height: 7), _fill(const Color(0xFF3A3330)));
  c.restore();
}

void _drawHen(Canvas c, Offset p, double t, int i) {
  final bob = math.sin(t * 6 + i) > 0.7 ? 1.5 : 0.0;
  c.drawCircle(p + const Offset(1, 2), 5, _fill(_P.shadow));
  c.drawCircle(p, 5, _fill(const Color(0xFFB8642F)));
  c.drawCircle(p + Offset(4 + bob, -2), 3, _fill(const Color(0xFFC8783F)));
  c.drawCircle(p + Offset(5 + bob, -4), 1.4, _fill(const Color(0xFFE2453A)));
}

void _drawTractor(Canvas c, double t) {
  final span = FarmWorld.size.width + 300;
  final x = (t * 46) % span - 150;
  final p = Offset(x, FarmWorld.tractorRoadY + 4);
  c.save();
  c.translate(p.dx, p.dy);
  c.drawRect(const Rect.fromLTWH(-20, -12, 40, 28), _fill(_P.shadow));
  for (final w in const [Offset(-12, -13), Offset(-12, 13)]) {
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: w, width: 16, height: 7), const Radius.circular(2)),
      _fill(const Color(0xFF2B2B2B)),
    );
  }
  for (final w in const [Offset(13, -10), Offset(13, 10)]) {
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: w, width: 9, height: 5), const Radius.circular(2)),
      _fill(const Color(0xFF2B2B2B)),
    );
  }
  c.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(-18, -9, 38, 18), const Radius.circular(4)),
    _fill(const Color(0xFFD23B30)),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(-16, -7, 14, 14), const Radius.circular(3)),
    _fill(const Color(0xFF9FD0EE)),
  );
  c.drawCircle(const Offset(12, -5), 2, _fill(const Color(0xFF555555)));
  c.restore();
}

void _drawRipples(Canvas c, double t) {
  final pond = FarmWorld.zones[ZoneId.water]!;
  final centers = [pond.topLeft + const Offset(300, 70), pond.topLeft + const Offset(360, 100)];
  for (var i = 0; i < centers.length; i++) {
    final phase = ((t * 0.45) + i * 0.5) % 1.0;
    c.drawCircle(centers[i], 6 + phase * 26, _stroke(Colors.white.withValues(alpha: (1 - phase) * 0.6), 1.6));
  }
}

void _drawSprinkler(Canvas c, double t) {
  final veg = FarmWorld.zones[ZoneId.vegetable]!;
  final center = veg.center;
  final a = t * 1.4;
  final paint = Paint()..shader = ui.Gradient.radial(center, 70, [const Color(0x669CD8F5), const Color(0x009CD8F5)]);
  c.drawArc(Rect.fromCircle(center: center, radius: 70), a, 0.9, true, paint);
  c.drawCircle(center, 4, _fill(_P.steelDark));
}

void _drawBees(Canvas c, double t) {
  final orchard = FarmWorld.zones[ZoneId.orchard]!;
  final hive = Offset(orchard.right - 70, orchard.bottom - 44);
  for (var i = 0; i < 7; i++) {
    final a = t * (1.6 + i * 0.25) + i;
    final r = 22 + 14 * math.sin(t * 0.9 + i * 2);
    final p = hive + Offset(math.cos(a) * r, math.sin(a * 1.3) * r * 0.7);
    c.drawCircle(p, 2.2, _fill(const Color(0xFF2B2B2B)));
    c.drawCircle(p + const Offset(-0.6, 0), 1.6, _fill(const Color(0xFFF6C744)));
  }
}

void _drawWaterLevel(Canvas c, double ratio, double t) {
  final r = FarmWorld.zones[ZoneId.water]!;
  final tank = Offset(r.left + 80, r.center.dy);
  final arc = _stroke(Colors.white.withValues(alpha: 0.85), 4);
  c.drawArc(Rect.fromCircle(center: tank, radius: 53), -math.pi / 2, math.pi * 2 * ratio, false, arc);
  final shimmer = (math.sin(t * 2) + 1) / 2;
  c.drawCircle(tank + const Offset(10, 8), 10 + shimmer * 4, _fill(Colors.white.withValues(alpha: 0.10)));
}

// ---------------------------------------------------------------- 라벨

final _labelCache = <String, TextPainter>{};
final _iconCache = <ZoneId, TextPainter>{};

TextPainter _iconLabel(ZoneId zone) => _iconCache.putIfAbsent(
  zone,
  () => TextPainter(
    text: TextSpan(
      text: String.fromCharCode(zone.icon.codePoint),
      style: TextStyle(
        fontSize: 22,
        fontFamily: zone.icon.fontFamily,
        package: zone.icon.fontPackage,
        color: AppMapColors.icon,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(),
);

TextPainter _label(String text) => _labelCache.putIfAbsent(text, () {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1C211E)),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return tp;
});

/// 지도 전체를 그린다. [view]는 화면에 담을 월드 영역이다.
class FarmMapPainter extends CustomPainter {
  FarmMapPainter({
    required this.view,
    required this.time,
    required this.selected,
    required this.selectionT,
    required this.labelOpacity,
    required this.tankRatio,
    required this.needsWater,
    required this.zoneLabels,
    this.zoneSemantics = const {},
    this.onZoneTap,
    this.textDirection = TextDirection.ltr,
  }) : super(repaint: time);

  final Rect view;
  final ValueNotifier<double> time;
  final ZoneId? selected;
  final double selectionT;
  final double labelOpacity;
  final double tankRatio;
  final Set<ZoneId> needsWater;

  /// 구역 라벨(현재 언어).
  final Map<ZoneId, String> zoneLabels;

  /// 스크린리더가 읽을 구역 이름(물 필요 여부 포함). 지도는 그림이라 이것이 없으면 구역을 고를 수 없다.
  final Map<ZoneId, String> zoneSemantics;
  final ValueChanged<ZoneId>? onZoneTap;
  final TextDirection textDirection;

  static double scaleFor(Rect view, Size size) => math.max(size.width / view.width, size.height / view.height);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final scale = scaleFor(view, size);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-view.center.dx, -view.center.dy);

    canvas.drawPicture(FarmWorld.staticLayer);
    _drawSprinkler(canvas, t);
    _drawRipples(canvas, t);
    _drawWaterLevel(canvas, tankRatio, t);
    for (var i = 0; i < _hens.length; i++) {
      _drawHen(canvas, _hens[i].at(t), t, i);
    }
    for (final s in _sheep) {
      _drawSheep(canvas, s.at(t), s.velocity(t));
    }
    for (final cow in _cows) {
      _drawCow(canvas, cow.at(t), cow.velocity(t));
    }
    _drawBees(canvas, t);
    _drawTractor(canvas, t);

    // 물이 필요한 밭은 파란 점이 숨 쉬듯 깜빡인다.
    final pulse = (math.sin(t * 3) + 1) / 2;
    for (final zone in needsWater) {
      final r = FarmWorld.zones[zone]!;
      // 화면에서 늘 같은 크기로 보이도록 배율을 상쇄한다.
      final p = r.topRight + const Offset(-1, 1) * (20 / scale);
      canvas.drawCircle(p, (6 + pulse * 7) / scale, _fill(_P.water.withValues(alpha: 0.35 * (1 - pulse))));
      canvas.drawCircle(p, 6 / scale, _fill(Colors.white));
      canvas.drawCircle(p, 4.5 / scale, _fill(_P.water));
    }

    if (selected != null && selectionT > 0) {
      final r = FarmWorld.zones[selected]!.inflate(4);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(20));
      canvas.drawRRect(rr, _stroke(Colors.white.withValues(alpha: 0.45 * selectionT), 12 / scale));
      canvas.drawRRect(rr, _stroke(Colors.white.withValues(alpha: selectionT), 4 / scale));
    }

    if (labelOpacity > 0) {
      for (final zone in ZoneId.values) {
        _drawLabel(canvas, zone, scale);
      }
    }
    canvas.restore();
  }

  void _drawLabel(Canvas canvas, ZoneId zone, double scale) {
    final tp = _label(zoneLabels[zone] ?? zone.name);
    final r = FarmWorld.zones[zone]!;
    // 화면 크기가 일정하게 보이도록 배율을 상쇄한다.
    final k = 0.42 / scale;
    final w = (tp.width + 46) * k;
    final h = 40 * k;
    final box = Rect.fromLTWH(r.left + 10, r.top + 10, w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(h / 2)),
      _fill(Colors.white.withValues(alpha: 0.92 * labelOpacity)),
    );
    final opaque = labelOpacity >= 1;
    if (!opaque) canvas.saveLayer(box, Paint()..color = Colors.black.withValues(alpha: labelOpacity));
    canvas.save();
    canvas.translate(box.left + 14 * k, box.top + (h - tp.height * k) / 2);
    canvas.scale(k);
    final icon = _iconLabel(zone);
    icon.paint(canvas, Offset(0, (tp.height - icon.height) / 2));
    tp.paint(canvas, const Offset(26, 0));
    canvas.restore();
    if (!opaque) canvas.restore();
  }

  @override
  SemanticsBuilderCallback? get semanticsBuilder => zoneSemantics.isEmpty ? null : _buildSemantics;

  /// 화면에 보이는 구역마다 탭할 수 있는 영역을 만든다(구역을 확대하면 보이는 구역만 남는다).
  List<CustomPainterSemantics> _buildSemantics(Size size) {
    final scale = scaleFor(view, size);
    final screen = Offset.zero & size;
    Offset toScreen(Offset world) => (world - view.center) * scale + size.center(Offset.zero);
    return [
      for (final zone in ZoneId.values)
        if (zoneSemantics[zone] case final label?)
          if (Rect.fromPoints(toScreen(FarmWorld.zones[zone]!.topLeft), toScreen(FarmWorld.zones[zone]!.bottomRight))
              case final rect when rect.overlaps(screen))
            CustomPainterSemantics(
              key: ValueKey(zone),
              rect: rect.intersect(screen),
              properties: SemanticsProperties(
                label: label,
                textDirection: textDirection,
                button: true,
                selected: zone == selected,
                onTap: onZoneTap == null ? null : () => onZoneTap!(zone),
              ),
            ),
    ];
  }

  @override
  bool shouldRebuildSemantics(FarmMapPainter oldDelegate) =>
      oldDelegate.view != view ||
      oldDelegate.selected != selected ||
      !mapEquals(oldDelegate.zoneSemantics, zoneSemantics);

  @override
  bool shouldRepaint(FarmMapPainter old) =>
      old.view != view ||
      old.selected != selected ||
      old.selectionT != selectionT ||
      old.labelOpacity != labelOpacity ||
      old.tankRatio != tankRatio ||
      !setEquals(old.needsWater, needsWater) ||
      old.zoneLabels[ZoneId.house] != zoneLabels[ZoneId.house];
}

bool setEquals<T>(Set<T> a, Set<T> b) => a.length == b.length && a.containsAll(b);

abstract final class AppMapColors {
  static const icon = Color(0xFF1F4D2C);
}
