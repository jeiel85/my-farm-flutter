import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/theme.dart';
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

  /// 지도 바탕색(전체 지도 화면 배경도 같은 색으로 둔다).
  static const groundColor = _P.paper;

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

/// 농지 도면처럼 보이는 지도 색. 그림자 없이 잉크 외곽선과 패턴(해칭·점)으로 구역을 구분한다.
abstract final class _P {
  static const paper = Color(0xFFEDE4CF);
  static const paperLight = Color(0xFFF6F0E1);
  static const ink = Color(0xFF2E3338);
  static const sage = Color(0xFFB8C49C);
  static const sageLight = Color(0xFFCFD8B6);
  static const sageDeep = Color(0xFF7F9467);
  static const olive = Color(0xFF9DAA78);
  static const ochre = Color(0xFFD9BC7E);
  static const ochreDeep = Color(0xFFB8924A);
  static const soil = Color(0xFFCBA588);
  static const soilDeep = Color(0xFF9C6F52);
  static const brick = Color(0xFFB4553A);
  static const building = Color(0xFFE3D3B8);
  static const roof = Color(0xFF8C6D5A);
  static const slate = Color(0xFF8FAFC4);
  static const slateDeep = Color(0xFF4E7590);
  static const glass = Color(0xFFDCE5E4);
  static const carrot = Color(0xFFD27D3E);
}

Paint _fill(Color c) => Paint()..color = c;
Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

final _inkLine = _stroke(_P.ink, 2.2);
final _inkThin = _stroke(_P.ink.withValues(alpha: 0.55), 1.2);

/// 잉크 외곽선이 있는 필지.
void _parcel(Canvas c, Rect r, Color fill, {double radius = 6}) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
  c.drawRRect(rr, _fill(fill));
  c.drawRRect(rr, _inkLine);
}

/// [r] 안을 [angle] 방향 평행선으로 채운다(해칭).
void _hatch(Canvas c, Rect r, double spacing, Paint paint, {double angle = 0, double radius = 6}) {
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
  c.translate(r.center.dx, r.center.dy);
  c.rotate(angle);
  final reach = (r.width + r.height);
  for (var y = -reach; y <= reach; y += spacing) {
    c.drawLine(Offset(-reach, y), Offset(reach, y), paint);
  }
  c.restore();
}

/// 점선(직선).
void _dashed(Canvas c, Offset a, Offset b, Paint paint, {double dash = 10, double gap = 8}) {
  final d = b - a;
  final len = d.distance;
  if (len == 0) return;
  final u = d / len;
  for (var s = 0.0; s < len; s += dash + gap) {
    c.drawLine(a + u * s, a + u * math.min(s + dash, len), paint);
  }
}

void _dashedRect(Canvas c, Rect r, Paint paint) {
  _dashed(c, r.topLeft, r.topRight, paint);
  _dashed(c, r.topRight, r.bottomRight, paint);
  _dashed(c, r.bottomRight, r.bottomLeft, paint);
  _dashed(c, r.bottomLeft, r.topLeft, paint);
}

/// 위에서 본 나무: 채운 원 + 잉크 테두리 + 가운데 점.
void _tree(Canvas c, Offset p, double r, {Color canopy = _P.sageDeep, Color? fruit, math.Random? rng}) {
  c.drawCircle(p, r, _fill(canopy));
  c.drawCircle(p, r, _inkThin);
  c.drawCircle(p, r * 0.55, _stroke(_P.ink.withValues(alpha: 0.25), 1));
  if (fruit != null && rng != null) {
    for (var i = 0; i < 5; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final d = rng.nextDouble() * r * 0.65;
      c.drawCircle(p + Offset(math.cos(a) * d, math.sin(a) * d), r * 0.13, _fill(fruit));
    }
  }
}

/// 건물 평면: 외곽선 + 용마루 선 + 지붕 한쪽 해칭.
void _building(Canvas c, Rect r, {bool vertical = false, Color fill = _P.building}) {
  _parcel(c, r, fill, radius: 2);
  final half = vertical
      ? Rect.fromLTRB(r.center.dx, r.top, r.right, r.bottom)
      : Rect.fromLTRB(r.left, r.center.dy, r.right, r.bottom);
  _hatch(c, half.deflate(1), 7, _stroke(_P.roof.withValues(alpha: 0.55), 1.2), angle: math.pi / 4, radius: 1);
  if (vertical) {
    c.drawLine(Offset(r.center.dx, r.top), Offset(r.center.dx, r.bottom), _inkLine);
  } else {
    c.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), _inkLine);
  }
}

void _hayBale(Canvas c, Offset p, double r) {
  c.drawCircle(p, r, _fill(_P.ochre));
  c.drawCircle(p, r, _inkThin);
  c.drawCircle(p, r * 0.5, _stroke(_P.ochreDeep, 1.2));
}

class _StaticPainter {
  _StaticPainter(this.c);

  final Canvas c;
  final rng = math.Random(11);

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
    c.drawRect(const Rect.fromLTWH(-1500, -1500, 4000, 4250), _fill(_P.paper));
    // 종이 결
    for (var i = 0; i < 700; i++) {
      final p = Offset(rng.nextDouble() * 2400 - 700, rng.nextDouble() * 2650 - 700);
      c.drawCircle(p, 0.8 + rng.nextDouble() * 1.4, _fill(_P.ink.withValues(alpha: 0.06)));
    }
    // 농장 바깥은 등고선으로 그린다.
    final contour = _stroke(_P.sageDeep.withValues(alpha: 0.35), 1.4);
    for (var i = 1; i <= 26; i++) {
      final base = FarmWorld.bounds.inflate(i * 34.0);
      final path = Path();
      const steps = 120;
      for (var s = 0; s <= steps; s++) {
        final t = s / steps * math.pi * 2;
        final wobble = 1 + 0.035 * math.sin(t * 3 + i * 0.7) + 0.02 * math.sin(t * 7 - i);
        final p = Offset(
          base.center.dx + math.cos(t) * base.width / 2 * 1.08 * wobble,
          base.center.dy + math.sin(t) * base.height / 2 * 1.06 * wobble,
        );
        s == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      c.drawPath(path, i % 5 == 0 ? _stroke(_P.sageDeep.withValues(alpha: 0.5), 2) : contour);
    }
    // 농장 경계
    c.drawRect(FarmWorld.bounds.deflate(10), _stroke(_P.ink.withValues(alpha: 0.5), 1.6));
    // 도로: 밝은 띠 + 양쪽 실선 + 가운데 점선. 지도 밖까지 이어져 진입로처럼 보인다(트랙터가 달린다).
    final road = _fill(_P.paperLight);
    final centre = _stroke(_P.ink.withValues(alpha: 0.4), 1.6);
    for (var row = 1; row < 4; row++) {
      final y = FarmWorld._y(row) - FarmWorld._road + 8;
      final r = Rect.fromLTWH(-1500, y, 4000, FarmWorld._road - 16);
      c.drawRect(r, road);
      c.drawLine(r.topLeft, r.topRight, _inkThin);
      c.drawLine(r.bottomLeft, r.bottomRight, _inkThin);
      _dashed(c, Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), centre, dash: 14, gap: 12);
    }
    final vx = FarmWorld._x(1) - FarmWorld._road + 8;
    final v = Rect.fromLTWH(vx, -1500, FarmWorld._road - 16, 4250);
    c.drawRect(v, road);
    c.drawLine(v.topLeft, v.bottomLeft, _inkThin);
    c.drawLine(v.topRight, v.bottomRight, _inkThin);
    _dashed(c, Offset(v.center.dx, v.top), Offset(v.center.dx, v.bottom), centre, dash: 14, gap: 12);
  }

  void _house(Rect r) {
    _parcel(c, r, _P.sageLight, radius: 10);
    // 진입로
    final drive = Rect.fromLTWH(r.left + 92, r.top + 150, 34, r.bottom - r.top - 150);
    c.drawRect(drive, _fill(_P.paperLight));
    c.drawLine(drive.topLeft, drive.bottomLeft, _inkThin);
    c.drawLine(drive.topRight, drive.bottomRight, _inkThin);
    _building(c, Rect.fromLTWH(r.left + 36, r.top + 40, 150, 110));
    // 주차 칸
    final park = Rect.fromLTWH(r.left + 136, r.top + 168, 40, 62);
    c.drawRect(park, _stroke(_P.ink.withValues(alpha: 0.45), 1.4));
    c.drawLine(park.topLeft, park.bottomRight, _stroke(_P.ink.withValues(alpha: 0.25), 1));
    // 텃밭: 점 격자
    final garden = Rect.fromLTWH(r.left + 220, r.top + 40, 120, 92);
    _parcel(c, garden, _P.soil, radius: 4);
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 4; x++) {
        c.drawCircle(Offset(garden.left + 20 + x * 27, garden.top + 22 + y * 25), 5, _fill(_P.sageDeep));
      }
    }
    _hayBale(c, Offset(r.left + 250, r.top + 190), 14);
    _hayBale(c, Offset(r.left + 282, r.top + 200), 14);
    for (var i = 0; i < 6; i++) {
      _tree(c, Offset(r.right - 36, r.top + 30 + i * 40), 15 + rng.nextDouble() * 4);
    }
    _tree(c, Offset(r.left + 26, r.top + 210), 17);
  }

  void _tomato(Rect r) {
    final bed = r.deflate(8);
    _parcel(c, bed, _P.soil);
    // 이랑: 가로줄 + 줄마다 열매 점
    final ridge = _stroke(_P.soilDeep.withValues(alpha: 0.7), 2);
    for (var y = bed.top + 24.0; y < bed.bottom - 8; y += 26) {
      c.drawLine(Offset(bed.left + 10, y), Offset(bed.right - 10, y), ridge);
      for (var x = bed.left + 20.0; x < bed.right - 12; x += 24) {
        c.drawCircle(Offset(x, y), 5.5, _fill(_P.sageDeep));
        c.drawCircle(Offset(x + 3, y - 3), 2.4, _fill(_P.brick));
      }
    }
  }

  void _vegetable(Rect r) {
    final bed = r.deflate(8);
    _parcel(c, bed, _P.soil);
    final left = Rect.fromLTRB(bed.left, bed.top, bed.center.dx - 4, bed.bottom);
    final right = Rect.fromLTRB(bed.center.dx + 4, bed.top, bed.right, bed.bottom);
    // 상추: 세로 줄무늬 띠
    for (var x = left.left + 10; x < left.right - 10; x += 26) {
      final strip = Rect.fromLTWH(x, left.top + 10, 14, left.height - 20);
      c.drawRRect(RRect.fromRectAndRadius(strip, const Radius.circular(7)), _fill(_P.olive));
    }
    c.drawLine(Offset(bed.center.dx, bed.top + 6), Offset(bed.center.dx, bed.bottom - 6), _inkThin);
    // 당근: 짧은 사선
    final carrot = _stroke(_P.carrot, 2.4);
    for (var y = right.top + 16; y < right.bottom - 8; y += 18) {
      for (var x = right.left + 12; x < right.right - 8; x += 16) {
        c.drawLine(Offset(x, y), Offset(x + 6, y - 6), carrot);
      }
    }
  }

  void _corn(Rect r) {
    final bed = r.deflate(8);
    _parcel(c, bed, _P.ochre);
    _hatch(c, bed, 11, _stroke(_P.ochreDeep.withValues(alpha: 0.75), 1.6), angle: -math.pi / 5);
    c.drawRRect(RRect.fromRectAndRadius(bed, const Radius.circular(6)), _inkLine);
  }

  void _animals(Rect r) {
    _parcel(c, r, _P.sage, radius: 10);
    final pasture = r.deflate(12);
    // 풀밭 점묘
    for (var i = 0; i < 160; i++) {
      final p = Offset(
        pasture.left + rng.nextDouble() * pasture.width,
        pasture.top + rng.nextDouble() * pasture.height,
      );
      c.drawCircle(p, 1.4, _fill(_P.sageDeep.withValues(alpha: 0.6)));
    }
    // 물웅덩이
    final mud = Rect.fromLTWH(r.left + 230, r.top + 160, 90, 46);
    c.drawOval(mud, _fill(_P.soil));
    c.drawOval(mud, _inkThin);
    _dashedRect(c, pasture, _stroke(_P.ink.withValues(alpha: 0.7), 1.8));
    _building(c, Rect.fromLTWH(r.left + 26, r.top + 26, 118, 82), vertical: true);
    _building(c, Rect.fromLTWH(r.left + 40, r.bottom - 74, 60, 44));
    _hayBale(c, Offset(r.left + 170, r.top + 52), 13);
    _hayBale(c, Offset(r.left + 200, r.top + 46), 13);
    _hayBale(c, Offset(r.left + 186, r.top + 76), 13);
    final trough = RRect.fromRectAndRadius(Rect.fromLTWH(r.right - 100, r.top + 34, 64, 18), const Radius.circular(4));
    c.drawRRect(trough, _fill(_P.slate));
    c.drawRRect(trough, _inkThin);
  }

  void _water(Rect r) {
    _parcel(c, r, _P.sageLight, radius: 10);
    // 물탱크(평면): 동심원
    final tank = Offset(r.left + 80, r.center.dy);
    c.drawCircle(tank, 56, _fill(_P.paperLight));
    c.drawCircle(tank, 56, _inkLine);
    c.drawCircle(tank, 46, _fill(_P.slate));
    c.drawCircle(tank, 46, _inkThin);
    // 배관: 두 줄
    final a = tank + const Offset(56, -4);
    final b = Offset(r.left + 190, r.center.dy - 4);
    c.drawLine(a, b, _inkThin);
    c.drawLine(a + const Offset(0, 8), b + const Offset(0, 8), _inkThin);
    final valve = Rect.fromCenter(center: Offset(r.left + 190, r.center.dy), width: 20, height: 20);
    c.drawRect(valve, _fill(_P.paperLight));
    c.drawRect(valve, _inkThin);
    // 연못: 바깥에서 안으로 등심선
    // 두 타원을 합친 하나의 윤곽(겹친 선이 생기지 않게).
    final pond = Path.combine(
      PathOperation.union,
      Path()..addOval(Rect.fromLTWH(r.left + 220, r.top + 22, 200, 110)),
      Path()..addOval(Rect.fromLTWH(r.left + 300, r.top + 60, 120, 76)),
    );
    c.drawPath(pond, _fill(_P.slate.withValues(alpha: 0.55)));
    c.drawPath(pond, _stroke(_P.slateDeep, 2));
    for (final k in const [0.78, 0.56, 0.34]) {
      c.save();
      c.translate(r.left + 330, r.top + 84);
      c.scale(k, k);
      c.translate(-(r.left + 330), -(r.top + 84));
      c.drawPath(pond, _stroke(_P.slateDeep.withValues(alpha: 0.55), 1.6 / k));
      c.restore();
    }
    _tree(c, Offset(r.right - 20, r.bottom - 20), 14);
  }

  void _storage(Rect r) {
    _parcel(c, r, _P.paperLight, radius: 8);
    final shed = Rect.fromLTWH(r.left + 26, r.top + 14, 190, r.height - 28);
    _parcel(c, shed, _P.building, radius: 2);
    _hatch(c, shed.deflate(2), 10, _stroke(_P.roof.withValues(alpha: 0.45), 1.2), angle: math.pi / 2, radius: 1);
    for (var i = 0; i < 2; i++) {
      final s = Offset(r.left + 270 + i * 70, r.center.dy);
      c.drawCircle(s, 28, _fill(_P.building));
      c.drawCircle(s, 28, _inkLine);
      c.drawLine(s - const Offset(18, 0), s + const Offset(18, 0), _inkThin);
      c.drawLine(s - const Offset(0, 18), s + const Offset(0, 18), _inkThin);
    }
    for (var i = 0; i < 3; i++) {
      final box = Rect.fromLTWH(r.right - 42, r.top + 14 + i * 22, 20, 18);
      c.drawRect(box, _fill(_P.ochre));
      c.drawRect(box, _inkThin);
    }
  }

  void _greenhouse(Rect r) {
    _parcel(c, r, _P.sageLight, radius: 10);
    for (var i = 0; i < 2; i++) {
      final g = Rect.fromLTWH(r.left + 18, r.top + 22 + i * 116, r.width - 36, 96);
      _parcel(c, g, _P.glass, radius: 4);
      final grid = _stroke(_P.slateDeep.withValues(alpha: 0.35), 1);
      for (var x = g.left + 16; x < g.right; x += 16) {
        c.drawLine(Offset(x, g.top), Offset(x, g.bottom), grid);
      }
      c.drawLine(Offset(g.left, g.center.dy), Offset(g.right, g.center.dy), _inkThin);
      // 딸기 점
      for (var y = g.top + 22; y < g.bottom - 10; y += 26) {
        for (var x = g.left + 24; x < g.right - 10; x += 32) {
          if (rng.nextDouble() < 0.6) c.drawCircle(Offset(x, y), 2.6, _fill(_P.brick));
        }
      }
    }
  }

  void _orchard(Rect r) {
    _parcel(c, r, _P.sage, radius: 10);
    // 꽃밭 점묘
    const flowers = [_P.ochre, _P.brick, _P.paperLight];
    for (var i = 0; i < 50; i++) {
      final p = Offset(r.left + 300 + rng.nextDouble() * 120, r.top + 180 + rng.nextDouble() * 70);
      c.drawCircle(p, 2, _fill(flowers[i % 3]));
    }
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        if (row == 2 && col >= 3) continue;
        final p = Offset(r.left + 50 + col * 92 + (row.isOdd ? 30 : 0), r.top + 46 + row * 78);
        _tree(c, p, 25, canopy: _P.olive, fruit: _P.brick, rng: rng);
      }
    }
    // 벌통
    for (var i = 0; i < 3; i++) {
      final b = Rect.fromLTWH(r.right - 120 + i * 36, r.bottom - 56, 26, 30);
      c.drawRect(b, _fill(_P.paperLight));
      _hatch(c, b, 6, _stroke(_P.ochreDeep, 1.4), radius: 0);
      c.drawRect(b, _inkThin);
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

// 동물·트랙터도 도면 기호처럼 단순한 도형 + 잉크 외곽선으로 그린다.
final _glyphLine = _stroke(_P.ink, 1.4);

void _drawCow(Canvas c, Offset p, Offset v) {
  c.save();
  c.translate(p.dx, p.dy);
  c.rotate(math.atan2(v.dy, v.dx));
  final body = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: 28, height: 15),
    const Radius.circular(7),
  );
  c.drawRRect(body, _fill(_P.paperLight));
  c.drawRRect(body, _glyphLine);
  c.drawCircle(const Offset(-5, -2), 3.2, _fill(_P.ink));
  c.drawCircle(const Offset(15, 0), 5, _fill(_P.paperLight));
  c.drawCircle(const Offset(15, 0), 5, _glyphLine);
  c.restore();
}

void _drawSheep(Canvas c, Offset p, Offset v) {
  c.save();
  c.translate(p.dx, p.dy);
  c.rotate(math.atan2(v.dy, v.dx));
  c.drawCircle(Offset.zero, 9, _fill(_P.paperLight));
  c.drawCircle(Offset.zero, 9, _glyphLine);
  c.drawCircle(const Offset(10, 0), 3.6, _fill(_P.ink));
  c.restore();
}

void _drawHen(Canvas c, Offset p, double t, int i) {
  final bob = math.sin(t * 6 + i) > 0.7 ? 1.5 : 0.0;
  c.drawCircle(p, 4.4, _fill(_P.carrot));
  c.drawCircle(p, 4.4, _stroke(_P.ink, 1));
  c.drawCircle(p + Offset(4 + bob, -2), 1.6, _fill(_P.brick));
}

void _drawTractor(Canvas c, double t) {
  final span = FarmWorld.size.width + 300;
  final x = (t * 46) % span - 150;
  final p = Offset(x, FarmWorld.tractorRoadY + 4);
  c.save();
  c.translate(p.dx, p.dy);
  for (final w in const [Offset(-12, -12), Offset(-12, 12), Offset(13, -9), Offset(13, 9)]) {
    c.drawRect(Rect.fromCenter(center: w, width: w.dx < 0 ? 14 : 8, height: 5), _fill(_P.ink));
  }
  final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-18, -9, 38, 18), const Radius.circular(3));
  c.drawRRect(body, _fill(AppMapColors.accent));
  c.drawRRect(body, _glyphLine);
  c.drawRect(const Rect.fromLTWH(-15, -6, 12, 12), _fill(_P.paperLight));
  c.drawRect(const Rect.fromLTWH(-15, -6, 12, 12), _stroke(_P.ink, 1));
  c.restore();
}

void _drawRipples(Canvas c, double t) {
  final pond = FarmWorld.zones[ZoneId.water]!;
  final centre = pond.topLeft + const Offset(330, 84);
  for (var i = 0; i < 2; i++) {
    final phase = ((t * 0.35) + i * 0.5) % 1.0;
    c.drawCircle(centre, 8 + phase * 40, _stroke(_P.slateDeep.withValues(alpha: (1 - phase) * 0.5), 1.4));
  }
}

void _drawSprinkler(Canvas c, double t) {
  final veg = FarmWorld.zones[ZoneId.vegetable]!;
  final centre = veg.center;
  final a = t * 1.4;
  final paint = Paint()..shader = ui.Gradient.radial(centre, 70, [const Color(0x554E7590), const Color(0x004E7590)]);
  c.drawArc(Rect.fromCircle(center: centre, radius: 70), a, 0.9, true, paint);
  c.drawCircle(centre, 4, _fill(_P.ink));
}

void _drawBees(Canvas c, double t) {
  final orchard = FarmWorld.zones[ZoneId.orchard]!;
  final hive = Offset(orchard.right - 70, orchard.bottom - 44);
  for (var i = 0; i < 7; i++) {
    final a = t * (1.6 + i * 0.25) + i;
    final r = 22 + 14 * math.sin(t * 0.9 + i * 2);
    final p = hive + Offset(math.cos(a) * r, math.sin(a * 1.3) * r * 0.7);
    c.drawCircle(p, 1.8, _fill(_P.ink));
  }
}

/// 물탱크 테두리의 수위 호(채운 비율만큼).
void _drawWaterLevel(Canvas c, double ratio, double t) {
  final r = FarmWorld.zones[ZoneId.water]!;
  final tank = Offset(r.left + 80, r.center.dy);
  c.drawArc(
    Rect.fromCircle(center: tank, radius: 51),
    -math.pi / 2,
    math.pi * 2 * ratio,
    false,
    _stroke(_P.slateDeep, 6),
  );
  final shimmer = (math.sin(t * 2) + 1) / 2;
  c.drawCircle(tank, 14 + shimmer * 6, _stroke(_P.paperLight.withValues(alpha: 0.6), 1.4));
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
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _P.ink, letterSpacing: 0.4),
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

    // 물이 필요한 밭: 물방울 표식(잉크 테두리) 둘레로 고리가 퍼진다.
    final pulse = (math.sin(t * 3) + 1) / 2;
    for (final zone in needsWater) {
      final r = FarmWorld.zones[zone]!;
      // 화면에서 늘 같은 크기로 보이도록 배율을 상쇄한다.
      final p = r.topRight + const Offset(-1, 1) * (20 / scale);
      canvas.drawCircle(
        p,
        (7 + pulse * 8) / scale,
        _stroke(_P.slateDeep.withValues(alpha: 0.6 * (1 - pulse)), 2 / scale),
      );
      canvas.drawCircle(p, 6 / scale, _fill(_P.slateDeep));
      canvas.drawCircle(p, 6 / scale, _stroke(_P.paperLight, 1.6 / scale));
    }

    // 고른 구역: 종이색 테두리 위에 주색 실선(도면에서 구역을 표시하듯).
    if (selected != null && selectionT > 0) {
      final r = FarmWorld.zones[selected]!.inflate(5);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(10));
      canvas.drawRRect(rr, _stroke(_P.paperLight.withValues(alpha: 0.8 * selectionT), 10 / scale));
      canvas.drawRRect(rr, _stroke(AppMapColors.accent.withValues(alpha: selectionT), 3.5 / scale));
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
    // 지도 범례처럼 각진 태그.
    final tag = RRect.fromRectAndRadius(box, Radius.circular(4 * k));
    canvas.drawRRect(tag, _fill(_P.paperLight.withValues(alpha: 0.95 * labelOpacity)));
    canvas.drawRRect(tag, _stroke(_P.ink.withValues(alpha: labelOpacity), 3 * k));
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
  static const icon = AppColors.primary;

  /// 트랙터·선택 테두리처럼 지도에서 눈에 띄어야 하는 요소.
  static const accent = AppColors.orange;
}
