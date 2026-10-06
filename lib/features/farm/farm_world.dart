import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/theme.dart';
import '../../game/defs.dart';
import '../../game/state.dart';
import '../../game/todo.dart';
import '../../game/zone.dart';
import '../../l10n/l10n.dart';
import 'storybook.dart';

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

  /// 전체 지도 화면 배경색(구운 배경 밖).
  static const groundColor = Tint.grass;

  /// 트랙터가 다니는 가로 도로의 세로 중심.
  static double get tractorRoadY => _y(2) - _road / 2;

  static ZoneId? hitTest(Offset world) {
    for (final e in zones.entries) {
      if (e.value.inflate(6).contains(world)) return e.key;
    }
    return null;
  }

  /// 구역을 [aspect](가로/세로) 비율의 화면에 꽉 차게 보여 줄 카메라 영역.
  static Rect focusRect(ZoneId zone, double aspect) => _fit(zones[zone]!.inflate(58), aspect);

  /// 전체 지도를 담는 카메라 영역.
  static Rect overviewRect(double aspect) => _fit(bounds, aspect);

  static Rect _fit(Rect r, double aspect) {
    var w = r.width;
    var h = r.height;
    if (w / h > aspect) {
      h = w / aspect;
    } else {
      w = h * aspect;
    }
    return Rect.fromCenter(center: r.center, width: w, height: h);
  }

  /// 가축 우리 안에서 동물이 돌아다니는 영역(건물 옆 풀밭).
  static Rect get pasture {
    final r = zones[ZoneId.animals]!;
    return Rect.fromLTRB(r.left + 170, r.top + 90, r.right - 30, r.bottom - 30);
  }

  static Offset get tankCenter {
    final r = zones[ZoneId.water]!;
    return Offset(r.left + 82, r.center.dy);
  }

  static const tankRadius = 56.0;

  // ---------------------------------------------------------------- 구운 이미지

  /// 구운 이미지 해상도(월드 1단위당 픽셀). 수채 그림은 약간 부드러워도 어색하지 않다.
  static const _pixelRatio = 1.6;
  static final bakeArea = bounds.inflate(140);
  static ui.Image? _ground;

  /// 움직이지 않는 배경(땅·길·집·목장·물·창고). 처음 한 번만 굽는다.
  static ui.Image get ground => _ground ??= bake(bakeArea, _pixelRatio, _paintGround);

  static final _plotCache = <String, ui.Image>{};

  /// 작물 구역 그림(밭·작물 단계·온실 유리·과수원). 상태가 바뀔 때만 굽고, 최근 것만 남긴다.
  static ui.Image plotImage(ZoneId zone, CropId? crop, int? stage) {
    final key = '${zone.name}/${crop?.name}/$stage';
    final hit = _plotCache.remove(key);
    if (hit != null) return _plotCache[key] = hit;
    final r = zones[zone]!;
    final img = bake(r.inflate(14), _pixelRatio, (c) => _paintPlot(c, zone, r, crop, stage));
    _plotCache[key] = img;
    while (_plotCache.length > 16) {
      _plotCache.remove(_plotCache.keys.first)!.dispose();
    }
    return img;
  }

  static void _paintGround(Canvas c) {
    final rng = math.Random(7);
    paintMeadow(c, bakeArea, rng);
    // 바깥 나무
    for (var i = 0; i < 46; i++) {
      final p = Offset(
        bakeArea.left + rng.nextDouble() * bakeArea.width,
        bakeArea.top + rng.nextDouble() * bakeArea.height,
      );
      if (bounds.deflate(-6).contains(p)) continue;
      paintTree(c, p, 20 + rng.nextDouble() * 18, rng, leaf: i.isEven ? Tint.leaf : Tint.grassDeep);
    }
    // 길
    for (var row = 1; row < 4; row++) {
      paintRoad(c, Rect.fromLTWH(bakeArea.left, _y(row) - _road + 6, bakeArea.width, _road - 12), rng);
    }
    paintRoad(c, Rect.fromLTWH(_x(1) - _road + 6, bakeArea.top, _road - 12, bakeArea.height), rng);

    _paintHouse(c, zones[ZoneId.house]!, rng);
    _paintBarnyard(c, zones[ZoneId.animals]!, rng);
    _paintWater(c, zones[ZoneId.water]!, rng);
    _paintStorage(c, zones[ZoneId.storage]!, rng);
  }

  static void _paintHouse(Canvas c, Rect r, math.Random rng) {
    wash(c, wobblyRect(r, rng, radius: 24), const Color(0xFFC6D79A), rng, layers: 2, edge: false);
    paintRoad(c, Rect.fromLTWH(r.left + 92, r.top + 140, 34, r.bottom - r.top - 140), rng);
    paintGableHouse(c, Rect.fromLTWH(r.left + 34, r.top + 34, 156, 112), rng);
    c.drawRect(Rect.fromLTWH(r.left + 150, r.top + 44, 14, 18), fill(const Color(0xFF8C5A44)));
    final bed = wobblyOval(Rect.fromLTWH(r.left + 220, r.top + 40, 130, 80), rng, jitter: 0.08);
    wash(c, bed, Tint.soil, rng, layers: 2);
    for (var i = 0; i < 40; i++) {
      final p = Offset(r.left + 232 + rng.nextDouble() * 106, r.top + 52 + rng.nextDouble() * 56);
      c.drawCircle(p, 3.2, fill([Tint.flowerA, Tint.flowerB, Colors.white, Tint.tomato][i % 4]));
    }
    paintHayBale(c, Offset(r.left + 250, r.top + 190), 15, rng);
    paintHayBale(c, Offset(r.left + 284, r.top + 202), 15, rng);
    for (var i = 0; i < 5; i++) {
      paintTree(c, Offset(r.right - 34, r.top + 34 + i * 46), 18 + rng.nextDouble() * 5, rng);
    }
    paintTree(c, Offset(r.left + 28, r.top + 206), 20, rng);
  }

  static void _paintBarnyard(Canvas c, Rect r, math.Random rng) {
    final yard = wobblyRect(r.deflate(4), rng, radius: 26);
    wash(c, yard, const Color(0xFFC9D99C), rng, layers: 2);
    final mud = wobblyOval(Rect.fromLTWH(r.left + 250, r.top + 170, 96, 48), rng, jitter: 0.1);
    wash(c, mud, const Color(0xFFB58E66), rng, layers: 2);
    paintGableHouse(c, Rect.fromLTWH(r.left + 24, r.top + 24, 120, 86), rng, vertical: true);
    paintGableHouse(c, Rect.fromLTWH(r.left + 36, r.bottom - 82, 70, 50), rng, roof: const Color(0xFFB58A52));
    paintHayBale(c, Offset(r.left + 172, r.top + 34), 13, rng);
    final trough = wobblyRect(Rect.fromLTWH(r.right - 104, r.top + 28, 68, 20), rng, amp: 0.6, radius: 6);
    dropShadow(c, trough, offset: const Offset(3, 4));
    c.drawPath(trough, fill(const Color(0xFF9E8A6E)));
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(r.right - 99, r.top + 32, 58, 12), const Radius.circular(4)),
      fill(Tint.water),
    );
    paintFence(c, wobblyRect(r.deflate(12), rng, amp: 1.5, radius: 24));
  }

  static void _paintWater(Canvas c, Rect r, math.Random rng) {
    wash(c, wobblyRect(r, rng, radius: 22), const Color(0xFFC6D79A), rng, layers: 2, edge: false);
    paintTankBase(c, tankCenter, tankRadius, rng);
    final pipe = Path()
      ..moveTo(tankCenter.dx + tankRadius, tankCenter.dy)
      ..lineTo(r.left + 196, r.center.dy);
    c.drawPath(pipe, pen(const Color(0xFF7D8A8E), 6));
    paintPond(c, Rect.fromLTWH(r.left + 220, r.top + 18, 200, 118), rng);
  }

  static void _paintStorage(Canvas c, Rect r, math.Random rng) {
    wash(c, wobblyRect(r, rng, radius: 18), const Color(0xFFD9CDB2), rng, layers: 2, edge: false);
    paintGableHouse(c, Rect.fromLTWH(r.left + 22, r.top + 12, 190, r.height - 24), rng, roof: const Color(0xFF8E7A68));
    paintSilo(c, Offset(r.left + 262, r.center.dy), 30, rng);
    paintSilo(c, Offset(r.left + 330, r.center.dy), 30, rng);
  }

  static void _paintPlot(Canvas c, ZoneId zone, Rect r, CropId? crop, int? stage) {
    final rng = math.Random(zone.index * 31 + (crop?.index ?? 9) * 7 + (stage ?? 5));
    switch (GameDefs.zones[zone]?.plot) {
      case PlotKind.orchard:
        wash(c, wobblyRect(r, rng, radius: 22), const Color(0xFFBFD293), rng, layers: 2);
        paintOrchard(c, r, crop == null ? null : stage, rng);
      case PlotKind.greenhouse:
        wash(c, wobblyRect(r, rng, radius: 22), const Color(0xFFC6D79A), rng, layers: 2, edge: false);
        for (var i = 0; i < 2; i++) {
          final g = Rect.fromLTWH(r.left + 18, r.top + 20 + i * 118, r.width - 36, 100);
          paintBed(c, g.deflate(4), rng);
          if (crop != null && stage != null) paintCrops(c, g.deflate(4), crop, stage, rng);
          paintGlass(c, g, rng);
        }
      default:
        final bed = r.deflate(8);
        paintBed(c, bed, rng);
        if (crop != null && stage != null) paintCrops(c, bed, crop, stage, rng);
    }
  }
}

// ---------------------------------------------------------------- 지금 상태(그림 입력)

/// 지도 한 장을 그리는 데 필요한 게임 상태 요약.
@immutable
class FarmScene {
  const FarmScene({
    required this.plots,
    required this.ready,
    required this.locked,
    required this.animals,
    required this.stored,
    required this.waterRatio,
    required this.barnRatio,
    required this.labels,
    required this.semantics,
  });

  /// 작물 구역 → (작물, 단계). 빈 밭은 (null, null).
  final Map<ZoneId, (CropId?, int?)> plots;
  final Set<ZoneId> ready;

  /// 잠긴 구역 → 여는 레벨.
  final Map<ZoneId, int> locked;

  /// (종, 새끼인지). 우리에 있는 순서대로.
  final List<(Species, bool)> animals;
  final Map<Species, int> stored;
  final double waterRatio;
  final double barnRatio;
  final Map<ZoneId, String> labels;
  final Map<ZoneId, String> semantics;

  factory FarmScene.of(GameState s, AppLocalizations l) {
    final plots = <ZoneId, (CropId?, int?)>{};
    final ready = <ZoneId>{};
    for (final z in GameDefs.plotZones) {
      final f = s.fields[z] ?? FieldState.emptyField;
      plots[z] = (f.crop, cropStage(f));
      if (f.ready) ready.add(z);
    }
    final locked = {
      for (final e in GameDefs.zones.entries)
        if (!s.unlocked.contains(e.key)) e.key: e.value.unlockLevel,
    };
    final stored = <Species, int>{};
    for (final a in s.animals) {
      if (a.stored > 0) stored[a.species] = (stored[a.species] ?? 0) + a.stored;
    }
    String describe(ZoneId z) {
      final name = l.zone(z);
      if (locked.containsKey(z)) return l.mapZoneLocked(name, locked[z]!);
      final crop = plots[z]?.$1;
      if (ready.contains(z)) return l.mapZoneReady(name, l.crop(crop!));
      if (crop != null) return l.mapZoneGrowing(name, l.crop(crop));
      return name;
    }

    return FarmScene(
      plots: plots,
      ready: ready,
      locked: locked,
      animals: [for (final a in s.animals) (a.species, !a.adult)],
      stored: stored,
      waterRatio: s.water / GameDefs.waterCapacity,
      barnRatio: s.barnUsed / GameDefs.barnCapacity,
      labels: {for (final z in ZoneId.values) z: l.zoneShort(z)},
      semantics: {for (final z in ZoneId.values) z: describe(z)},
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FarmScene &&
      mapEquals(other.plots, plots) &&
      _setEquals(other.ready, ready) &&
      mapEquals(other.locked, locked) &&
      listEquals(other.animals, animals) &&
      mapEquals(other.stored, stored) &&
      other.waterRatio == waterRatio &&
      other.barnRatio == barnRatio &&
      mapEquals(other.labels, labels) &&
      mapEquals(other.semantics, semantics);

  @override
  int get hashCode => Object.hash(plots.length, ready.length, animals.length, waterRatio, barnRatio);
}

bool _setEquals<T>(Set<T> a, Set<T> b) => a.length == b.length && a.containsAll(b);

// ---------------------------------------------------------------- 매 프레임

final _textCache = <String, TextPainter>{};

TextPainter _text(String text, {double size = 22, FontWeight weight = FontWeight.w700, Color color = Tint.line}) =>
    _textCache.putIfAbsent(
      '$text/$size/${weight.value}/${color.toARGB32()}',
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: size, fontWeight: weight, color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );

TextPainter _icon(IconData icon, double size, Color color) => _textCache.putIfAbsent(
  'icon/${icon.codePoint}/$size/${color.toARGB32()}',
  () => TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(fontSize: size, fontFamily: icon.fontFamily, package: icon.fontPackage, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout(),
);

class FarmMapPainter extends CustomPainter {
  FarmMapPainter({
    required this.view,
    required this.time,
    required this.selected,
    required this.selectionT,
    required this.labelOpacity,
    required this.scene,
    this.onZoneTap,
    this.textDirection = TextDirection.ltr,
  }) : super(repaint: time);

  final Rect view;
  final ValueNotifier<double> time;
  final ZoneId? selected;
  final double selectionT;
  final double labelOpacity;
  final FarmScene scene;
  final ValueChanged<ZoneId>? onZoneTap;
  final TextDirection textDirection;

  static double scaleFor(Rect view, Size size) => math.max(size.width / view.width, size.height / view.height);

  static void _blit(Canvas c, ui.Image img, Rect dst) => c.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    dst,
    Paint()..filterQuality = FilterQuality.medium,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final scale = scaleFor(view, size);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, fill(FarmWorld.groundColor));
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-view.center.dx, -view.center.dy);

    _blit(canvas, FarmWorld.ground, FarmWorld.bakeArea);
    for (final e in scene.plots.entries) {
      _blit(canvas, FarmWorld.plotImage(e.key, e.value.$1, e.value.$2), FarmWorld.zones[e.key]!.inflate(14));
    }

    _drawWater(canvas, t);
    _drawCrates(canvas);
    _drawAnimals(canvas, t);
    _drawTractor(canvas, t);
    _drawStoredBubbles(canvas, t);
    _drawReady(canvas, t);
    _drawLocked(canvas);

    if (selected != null && selectionT > 0) {
      final r = FarmWorld.zones[selected]!.inflate(5);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(18));
      canvas.drawRRect(rr, pen(const Color(0xFFFFF8E6).withValues(alpha: 0.85 * selectionT), 10 / scale));
      canvas.drawRRect(rr, pen(AppColors.orange.withValues(alpha: selectionT), 3.5 / scale));
    }
    if (labelOpacity > 0) {
      for (final zone in ZoneId.values) {
        _drawLabel(canvas, zone, scale);
      }
    }
    canvas.restore();
  }

  void _drawWater(Canvas c, double t) {
    final center = FarmWorld.tankCenter;
    final r = FarmWorld.tankRadius * 0.84;
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));
    final top = center.dy + r - 2 * r * scene.waterRatio.clamp(0.0, 1.0);
    final wave = Path()..moveTo(center.dx - r, top);
    for (var x = -r; x <= r; x += 4) {
      wave.lineTo(center.dx + x, top + math.sin(x / 9 + t * 2) * 2);
    }
    wave
      ..lineTo(center.dx + r, center.dy + r)
      ..lineTo(center.dx - r, center.dy + r)
      ..close();
    c.drawPath(wave, fill(Tint.water));
    c.drawLine(
      Offset(center.dx - r * 0.5, top + 8),
      Offset(center.dx - r * 0.1, top + 8),
      pen(const Color(0x99FFFFFF), 2),
    );
    c.restore();
  }

  void _drawCrates(Canvas c) {
    final r = FarmWorld.zones[ZoneId.storage]!;
    final n = (scene.barnRatio * 6).ceil().clamp(0, 6);
    for (var i = 0; i < n; i++) {
      paintCrate(c, Rect.fromLTWH(r.right - 70 + (i % 2) * 24, r.top + 16 + (i ~/ 2) * 24, 20, 20));
    }
  }

  static double _hash(double x) => (math.sin(x) * 43758.5453).abs() % 1;

  void _drawAnimals(Canvas c, double t) {
    final area = FarmWorld.pasture;
    for (final (i, (species, young)) in scene.animals.indexed) {
      final seed = i * 7.31 + species.index * 2.17;
      final home = Offset(
        area.left + area.width * (0.12 + 0.76 * _hash(seed * 12.9898)),
        area.top + area.height * (0.12 + 0.76 * _hash(seed * 78.233)),
      );
      final speed = species == Species.chicken ? 0.55 : 0.14;
      final reach = species == Species.chicken ? 14.0 : 26.0;
      final p = home + Offset(math.sin(t * speed + seed) * reach, math.sin(t * speed * 1.3 + seed * 1.7) * reach * 0.6);
      final v = Offset(math.cos(t * speed + seed), math.cos(t * speed * 1.3 + seed * 1.7) * 0.78);
      final angle = math.atan2(v.dy, v.dx);
      final scale = young ? 0.62 : 1.0;
      switch (species) {
        case Species.cow:
          drawCow(c, p, angle, scale);
        case Species.goat:
          drawGoat(c, p, angle, scale);
        case Species.sheep:
          drawSheep(c, p, angle, scale);
        case Species.chicken:
          drawChicken(c, p, t, i, scale);
      }
    }
  }

  void _drawTractor(Canvas c, double t) {
    final span = FarmWorld.size.width + 300;
    final x = (t * 40) % span - 150;
    c.save();
    c.translate(x, FarmWorld.tractorRoadY + 2);
    c.drawOval(const Rect.fromLTWH(-20, -10, 44, 26), fill(Tint.shadow));
    for (final w in const [Offset(-12, -12), Offset(-12, 12), Offset(13, -9), Offset(13, 9)]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: w, width: w.dx < 0 ? 14 : 9, height: 6),
          const Radius.circular(2),
        ),
        fill(const Color(0xFF3B332C)),
      );
    }
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-18, -9, 38, 18), const Radius.circular(5));
    c.drawRRect(body, fill(AppColors.primary));
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-15, -6, 12, 12), const Radius.circular(2)),
      fill(const Color(0xFFDCE8EA)),
    );
    c.drawRRect(body, pen(Tint.line.withValues(alpha: 0.6), 1.2));
    c.restore();
  }

  /// 쌓인 생산물 말풍선(가축 우리 위쪽).
  void _drawStoredBubbles(Canvas c, double t) {
    final r = FarmWorld.zones[ZoneId.animals]!;
    var i = 0;
    for (final species in Species.values) {
      final n = scene.stored[species];
      if (n == null) continue;
      final bob = math.sin(t * 2.4 + i) * 3;
      _bubble(c, Offset(r.left + 230 + i * 70, r.top + 52 + bob), itemEmoji(GameDefs.animals[species]!.product), '$n');
      i++;
    }
  }

  void _drawReady(Canvas c, double t) {
    for (final zone in scene.ready) {
      final r = FarmWorld.zones[zone]!;
      final crop = scene.plots[zone]?.$1;
      if (crop == null) continue;
      _bubble(c, Offset(r.right - 46, r.top + 36 + math.sin(t * 3) * 4), cropEmoji(crop), null, highlight: true);
    }
  }

  void _bubble(Canvas c, Offset center, String emoji, String? count, {bool highlight = false}) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: count == null ? 46 : 66, height: 40),
      const Radius.circular(20),
    );
    c.drawRRect(body.shift(const Offset(2, 4)), fill(Tint.shadow));
    final tail = Path()
      ..moveTo(center.dx - 6, body.bottom - 1)
      ..lineTo(center.dx, body.bottom + 9)
      ..lineTo(center.dx + 6, body.bottom - 1)
      ..close();
    c.drawPath(tail, fill(const Color(0xFFFFFBF0)));
    c.drawRRect(body, fill(const Color(0xFFFFFBF0)));
    c.drawRRect(body, pen(highlight ? AppColors.orange : Tint.line.withValues(alpha: 0.5), highlight ? 3 : 1.6));
    final e = _text(emoji, size: 22);
    e.paint(c, Offset(count == null ? center.dx - e.width / 2 : center.dx - 26, center.dy - e.height / 2));
    if (count != null) {
      final n = _text(count, size: 18, weight: FontWeight.w800);
      n.paint(c, Offset(center.dx + 4, center.dy - n.height / 2));
    }
  }

  void _drawLocked(Canvas c) {
    for (final e in scene.locked.entries) {
      final r = FarmWorld.zones[e.key]!.deflate(2);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(20));
      c.drawRRect(rr, fill(const Color(0xFFF1EADB).withValues(alpha: 0.78)));
      c.drawRRect(rr, pen(Tint.line.withValues(alpha: 0.35), 2));
      final lock = _icon(Icons.lock_rounded, 40, Tint.line.withValues(alpha: 0.7));
      final label = _text('Lv ${e.value}', size: 24, weight: FontWeight.w800);
      lock.paint(c, Offset(r.center.dx - lock.width / 2, r.center.dy - lock.height + 2));
      label.paint(c, Offset(r.center.dx - label.width / 2, r.center.dy + 6));
    }
  }

  void _drawLabel(Canvas canvas, ZoneId zone, double scale) {
    final tp = _text(scene.labels[zone] ?? zone.name, size: 22);
    final icon = _icon(zone.icon, 22, AppColors.primary);
    final r = FarmWorld.zones[zone]!;
    // 화면에서 늘 같은 크기로 보이도록 배율을 상쇄한다.
    final k = 0.42 / scale;
    final w = (tp.width + 46) * k;
    final h = 40 * k;
    final box = Rect.fromLTWH(r.left + 10, r.top + 10, w, h);
    final tag = RRect.fromRectAndRadius(box, Radius.circular(h / 2));
    canvas.drawRRect(tag.shift(Offset(0, 2 * k)), fill(Tint.shadow.withValues(alpha: 0.2 * labelOpacity)));
    canvas.drawRRect(tag, fill(const Color(0xFFFFFBF0).withValues(alpha: 0.95 * labelOpacity)));
    canvas.drawRRect(tag, pen(Tint.line.withValues(alpha: 0.4 * labelOpacity), 2.4 * k));
    final opaque = labelOpacity >= 1;
    if (!opaque) canvas.saveLayer(box, Paint()..color = Colors.black.withValues(alpha: labelOpacity));
    canvas.save();
    canvas.translate(box.left + 14 * k, box.top + (h - tp.height * k) / 2);
    canvas.scale(k);
    icon.paint(canvas, Offset(0, (tp.height - icon.height) / 2));
    tp.paint(canvas, const Offset(26, 0));
    canvas.restore();
    if (!opaque) canvas.restore();
  }

  @override
  SemanticsBuilderCallback? get semanticsBuilder => scene.semantics.isEmpty ? null : _buildSemantics;

  /// 화면에 보이는 구역마다 탭할 수 있는 영역을 만든다(구역을 확대하면 보이는 구역만 남는다).
  List<CustomPainterSemantics> _buildSemantics(Size size) {
    final scale = scaleFor(view, size);
    final screen = Offset.zero & size;
    Offset toScreen(Offset world) => (world - view.center) * scale + size.center(Offset.zero);
    return [
      for (final zone in ZoneId.values)
        if (scene.semantics[zone] case final label?)
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
      oldDelegate.view != view || oldDelegate.selected != selected || oldDelegate.scene != scene;

  @override
  bool shouldRepaint(FarmMapPainter old) =>
      old.view != view ||
      old.selected != selected ||
      old.selectionT != selectionT ||
      old.labelOpacity != labelOpacity ||
      old.scene != scene;
}
