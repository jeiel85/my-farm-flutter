import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/theme.dart';
import '../../game/defs.dart';
import '../../game/lots.dart';
import '../../game/state.dart';
import '../../game/todo.dart';
import '../../l10n/l10n.dart';
import 'building_look.dart';
import 'sky_layer.dart';
import 'storybook.dart';

/// 위에서 내려다본 농장 지도. 땅은 [landCols] × [landRows] 칸이고, 좌표는 모두 월드 단위다.
abstract final class FarmWorld {
  static const lotSize = 260.0;
  static const road = 40.0;
  static const margin = 40.0;
  static const _pitch = lotSize + road;
  static const size = Size(
    margin * 2 + landCols * lotSize + (landCols - 1) * road,
    margin * 2 + landRows * lotSize + (landRows - 1) * road,
  );

  static Rect lotRect(LotId l) => Rect.fromLTWH(margin + l.col * _pitch, margin + l.row * _pitch, lotSize, lotSize);

  static Rect get bounds => Offset.zero & size;

  /// 전체 지도 화면 배경색(구운 배경 밖).
  static const groundColor = Tint.grass;

  /// 트랙터가 다니는 가로 길(2행과 3행 사이)의 세로 중심.
  static double get tractorRoadY => margin + 3 * _pitch - road / 2;

  /// [world] 자리의 칸(칸 사이 길 절반까지 그 칸으로 친다).
  static LotId? hitTest(Offset world) {
    final col = ((world.dx - margin + road / 2) / _pitch).floor();
    final row = ((world.dy - margin + road / 2) / _pitch).floor();
    final id = LotId(col, row);
    return id.inLand ? id : null;
  }

  /// 칸을 [aspect](가로/세로) 비율의 화면에 꽉 차게 보여 줄 카메라 영역.
  static Rect focusRect(LotId lot, double aspect) => _fit(lotRect(lot).inflate(46), aspect);

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

  // ---------------------------------------------------------------- 구운 이미지

  /// 구운 이미지 해상도(월드 1단위당 픽셀). 수채 그림은 약간 부드러워도 어색하지 않다.
  static const _pixelRatio = 1.5;
  static final bakeArea = bounds.inflate(140);
  static ui.Image? _ground;

  /// 움직이지 않는 바닥(풀밭·칸 사이 길). 처음 한 번만 굽는다.
  static ui.Image get ground => _ground ??= bake(bakeArea, _pixelRatio, _paintGround);

  static void _paintGround(Canvas c) {
    final rng = math.Random(7);
    paintMeadow(c, bakeArea, rng);
    for (var row = 1; row < landRows; row++) {
      final y = margin + row * _pitch - road;
      paintRoad(c, Rect.fromLTWH(bakeArea.left, y + 6, bakeArea.width, road - 12), rng);
    }
    for (var col = 1; col < landCols; col++) {
      final x = margin + col * _pitch - road;
      paintRoad(c, Rect.fromLTWH(x + 6, bakeArea.top, road - 12, bakeArea.height), rng);
    }
  }

  /// 농장 바깥 나무(길 위에는 심지 않는다).
  static final List<FarmProp> outerTrees = () {
    final rng = math.Random(17);
    final out = <FarmProp>[];
    bool onRoad(Offset p, double r) {
      for (var row = 1; row < landRows; row++) {
        if ((p.dy - (margin + row * _pitch - road / 2)).abs() < r + road / 2) return true;
      }
      for (var col = 1; col < landCols; col++) {
        if ((p.dx - (margin + col * _pitch - road / 2)).abs() < r + road / 2) return true;
      }
      return false;
    }

    for (var i = 0; i < 60; i++) {
      final p = Offset(
        bakeArea.left + rng.nextDouble() * bakeArea.width,
        bakeArea.top + rng.nextDouble() * bakeArea.height,
      );
      final r = 20 + rng.nextDouble() * 18;
      if (bounds.deflate(-r).contains(p) || onRoad(p, r)) continue;
      out.add(
        FarmProp(
          PropKind.tree,
          Rect.fromCircle(center: p, radius: r),
          seed: 100 + i,
          deep: i.isOdd,
        ),
      );
    }
    return out;
  }();

  static final _lotCache = <String, ui.Image>{};

  /// 칸 바닥 그림(밭과 작물 단계, 마당, 장애물 등). 상태가 바뀔 때만 굽고, 최근 것만 남긴다.
  static ui.Image lotImage(LotVisual v) {
    final key = v.key;
    final hit = _lotCache.remove(key);
    if (hit != null) return _lotCache[key] = hit;
    final r = lotRect(v.id);
    final img = bake(r.inflate(14), _pixelRatio, (c) => paintLotBase(c, v, r));
    _lotCache[key] = img;
    while (_lotCache.length > 48) {
      _lotCache.remove(_lotCache.keys.first)!.dispose();
    }
    return img;
  }

  static String? _propsKey;
  static ui.Image? _propsImage;

  /// 위에서 본 구조물·나무(투명 바탕). 지은 건물이 바뀔 때만 다시 굽는다.
  static ui.Image propsFlat(List<FarmProp> props, String key) {
    if (_propsKey == key && _propsImage != null) return _propsImage!;
    _propsImage?.dispose();
    _propsKey = key;
    return _propsImage = bake(bakeArea, _pixelRatio, (c) {
      for (final p in props) {
        paintPropFlat(c, p);
      }
    });
  }
}

// ---------------------------------------------------------------- 칸 그림

/// 칸 한 곳을 그리는 데 필요한 것. [key]가 같으면 구운 그림을 다시 쓴다.
@immutable
class LotVisual {
  const LotVisual.built(this.id, BuildingId this.building, {this.level = 1, this.crop, this.stage})
    : wild = null,
      reachable = false,
      skyBase = false;

  /// 하늘 보기용 바닥: 세워 그리는 것(작물·과수원 나무·온실 유리)을 뺀 칸.
  const LotVisual._skyBase(this.id, BuildingId this.building, this.level)
    : crop = null,
      stage = null,
      wild = null,
      reachable = false,
      skyBase = true;
  const LotVisual.empty(this.id)
    : skyBase = false,
      building = null,
      level = 0,
      crop = null,
      stage = null,
      wild = null,
      reachable = false;
  const LotVisual.wild(this.id, int this.wild, {required this.reachable})
    : skyBase = false,
      building = null,
      level = 0,
      crop = null,
      stage = null;

  final LotId id;
  final BuildingId? building;
  final int level;
  final CropId? crop;
  final int? stage;

  /// 아직 넓히지 않은 칸이면 장애물 종류.
  final int? wild;

  /// 가진 땅에 붙어 있어 넓힐 수 있는 자리(레벨·코인은 따로).
  final bool reachable;

  /// [bare]로 만든 하늘 보기용 바닥인지.
  final bool skyBase;

  bool get isEmpty => building == null && wild == null;

  /// 하늘 보기에서 작물·나무를 세워 그리는 칸(심어 둔 밭·온실·과수원). upright.dart가 그린다.
  bool get hasUprightCrop =>
      crop != null &&
      stage != null &&
      (building == BuildingId.field || building == BuildingId.greenhouse || building == BuildingId.orchard);

  /// 하늘 보기에서 바닥 그림을 [bare]로 바꾸는 칸. 온실은 비어 있어도 유리 상자를 세우므로 늘 바꾼다.
  bool get swapsInSky => hasUprightCrop || building == BuildingId.greenhouse;

  /// 세워 그리는 것(작물·과수원 나무·온실 유리)을 뺀 같은 칸. 하늘 보기에서는 평면 그림을 이 그림으로 서서히 바꿔,
  /// 세운 그림과 겹쳐 보이지 않게 한다.
  LotVisual get bare => LotVisual._skyBase(id, building!, level);

  String get key => '${id.key}/${building?.name}/$level/${crop?.name}/$stage/$wild${skyBase ? '/sky' : ''}';

  @override
  bool operator ==(Object other) => other is LotVisual && other.key == key && other.reachable == reachable;

  @override
  int get hashCode => Object.hash(key, reachable);
}

/// 좌표로 정해지는 장애물 종류(저장하지 않는다).
int wildKindOf(LotId id) => (id.col * 7 + id.row * 13 + id.col * id.row) % wildKinds;

void paintLotBase(Canvas c, LotVisual v, Rect r) {
  final rng = math.Random(v.id.col * 131 + v.id.row * 17 + (v.crop?.index ?? 9) * 7 + (v.stage ?? 5));
  if (v.wild != null) return paintWild(c, r, v.wild!, rng);
  final building = v.building;
  if (building == null) {
    // 빈 땅: 고른 풀밭에 점선 테두리.
    wash(c, wobblyRect(r.deflate(4), rng, radius: 24), const Color(0xFFD3DFA8), rng, layers: 2, edge: false);
    final outline = Path()..addRRect(RRect.fromRectAndRadius(r.deflate(12), const Radius.circular(22)));
    for (final m in outline.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 22) {
        c.drawPath(m.extractPath(d, d + 12), pen(Tint.line.withValues(alpha: 0.35), 2.4));
      }
    }
    return;
  }
  switch (building) {
    case BuildingId.farmhouse:
      wash(c, wobblyRect(r, rng, radius: 24), const Color(0xFFC6D79A), rng, layers: 2, edge: false);
      final house = LotLayout.house(r);
      paintRoad(c, Rect.fromLTWH(house.center.dx - 14, house.bottom - 6, 28, r.bottom - house.bottom), rng);
      final bed = wobblyOval(Rect.fromLTWH(r.left + 16, r.bottom - 86, 98, 58), rng, jitter: 0.08);
      wash(c, bed, Tint.soil, rng, layers: 2);
      for (var i = 0; i < 26; i++) {
        final p = Offset(r.left + 26 + rng.nextDouble() * 78, r.bottom - 78 + rng.nextDouble() * 42);
        c.drawCircle(p, 3.2, fill([Tint.flowerA, Tint.flowerB, Colors.white, Tint.tomato][i % 4]));
      }
      paintTankBase(c, LotLayout.tank(r), LotLayout.tankRadius, rng);
    case BuildingId.storehouse:
      wash(c, wobblyRect(r, rng, radius: 18), const Color(0xFFD9CDB2), rng, layers: 2, edge: false);
    case BuildingId.field:
      final bed = r.deflate(10);
      paintBed(c, bed, rng);
      if (v.crop != null && v.stage != null) paintCrops(c, bed, v.crop!, v.stage!, rng);
    case BuildingId.greenhouse:
      wash(c, wobblyRect(r, rng, radius: 22), const Color(0xFFC6D79A), rng, layers: 2, edge: false);
      for (final g in LotLayout.greenhouseBeds(r)) {
        paintBed(c, g.deflate(4), rng);
        if (v.crop != null && v.stage != null) paintCrops(c, g.deflate(4), v.crop!, v.stage!, rng);
        if (!v.skyBase) paintGlass(c, g, rng);
      }
    case BuildingId.orchard:
      wash(c, wobblyRect(r, rng, radius: 22), const Color(0xFFBFD293), rng, layers: 2);
      paintOrchard(c, r.deflate(6), v.crop == null ? null : v.stage, rng);
    case BuildingId.mill || BuildingId.jamKitchen || BuildingId.dairy || BuildingId.bakery:
      // 공방: 다진 흙 마당과 앞길, 나무통.
      wash(c, wobblyRect(r.deflate(4), rng, radius: 22), const Color(0xFFDCCFAE), rng, layers: 2, edge: false);
      final shop = LotLayout.workshop(r);
      paintRoad(c, Rect.fromLTWH(shop.center.dx - 16, shop.bottom - 6, 32, r.bottom - shop.bottom - 6), rng);
      for (var i = 0; i < 3; i++) {
        final barrel = Rect.fromCircle(center: Offset(r.right - 36, r.bottom - 44 - i * 26), radius: 11);
        c.drawOval(barrel.shift(const Offset(2, 3)), fill(Tint.shadow));
        c.drawOval(barrel, fill(Tint.wood));
        c.drawOval(barrel.deflate(3), pen(const Color(0x55000000), 1.2));
      }
    case BuildingId.pond:
      wash(c, wobblyRect(r.deflate(4), rng, radius: 24), const Color(0xFFC6D79A), rng, layers: 2, edge: false);
      paintPond(c, LotLayout.pond(r), rng);
    case BuildingId.scarecrow:
      // 허수아비가 지키는 작은 풀밭(허수아비 자체는 서 있는 것으로 따로 그린다).
      wash(c, wobblyRect(r.deflate(4), rng, radius: 24), const Color(0xFFCBDB9E), rng, layers: 2, edge: false);
      for (var i = 0; i < 18; i++) {
        final p = Offset(
          r.left + 20 + rng.nextDouble() * (r.width - 40),
          r.top + 20 + rng.nextDouble() * (r.height - 40),
        );
        c.drawCircle(p, 3, fill((i.isEven ? Tint.flowerA : Colors.white).withValues(alpha: 0.85)));
      }
    case BuildingId.flowerBed:
      wash(c, wobblyRect(r.deflate(4), rng, radius: 24), const Color(0xFFCBDB9E), rng, layers: 2, edge: false);
      paintFlowerBed(c, r, rng);
    case BuildingId.coop || BuildingId.goatPen || BuildingId.sheepPen || BuildingId.cowBarn:
      wash(c, wobblyRect(r.deflate(4), rng, radius: 26), const Color(0xFFC9D99C), rng, layers: 2);
      final pasture = LotLayout.pasture(r, building);
      final mud = wobblyOval(
        Rect.fromCenter(center: pasture.center + const Offset(24, 18), width: 82, height: 40),
        rng,
        jitter: 0.1,
      );
      wash(c, mud, const Color(0xFFB58E66), rng, layers: 2);
      final troughRect = LotLayout.trough(r);
      final trough = wobblyRect(troughRect, rng, amp: 0.6, radius: 6);
      dropShadow(c, trough, offset: const Offset(3, 4));
      c.drawPath(trough, fill(const Color(0xFF9E8A6E)));
      c.drawRRect(RRect.fromRectAndRadius(troughRect.deflate(4), const Radius.circular(4)), fill(Tint.water));
      paintFence(c, wobblyRect(r.deflate(10), rng, amp: 1.5, radius: 24));
  }
}

/// 건물별 칸 안 배치(월드 좌표). 바닥 그림·세운 그림·동물·말풍선이 같은 자리를 쓴다.
abstract final class LotLayout {
  static Rect house(Rect r) => Rect.fromLTWH(r.left + 18, r.top + 22, 140, 100);
  static Offset tank(Rect r) => Offset(r.right - 58, r.bottom - 60);
  static const tankRadius = 42.0;

  /// 온실 안 두 줄 화단(유리를 덮는 자리).
  static List<Rect> greenhouseBeds(Rect r) {
    final h = (r.height - 50) / 2;
    return [for (var i = 0; i < 2; i++) Rect.fromLTWH(r.left + 16, r.top + 18 + i * (h + 14), r.width - 32, h)];
  }

  static Rect warehouse(Rect r) => Rect.fromLTWH(r.left + 14, r.top + 40, 150, 104);
  static List<Offset> silos(Rect r) => [Offset(r.right - 44, r.top + 64), Offset(r.right - 44, r.top + 132)];
  static Rect shed(Rect r, BuildingId b) => b == BuildingId.coop
      ? Rect.fromLTWH(r.left + 18, r.top + 18, 76, 54)
      : Rect.fromLTWH(r.left + 16, r.top + 16, 108, 78);
  static Rect pasture(Rect r, BuildingId b) =>
      Rect.fromLTRB(r.left + 30, r.top + (b == BuildingId.coop ? 92 : 112), r.right - 30, r.bottom - 28);
  static Offset door(Rect r, BuildingId b) => shed(r, b).bottomCenter + const Offset(0, 14);
  static Rect trough(Rect r) => Rect.fromLTWH(r.right - 94, r.top + 30, 62, 18);
  static Rect workshop(Rect r) => Rect.fromLTWH(r.left + 36, r.top + 40, 152, 104);
  static Rect pond(Rect r) => r.deflate(34);
  static Offset scarecrow(Rect r) => r.center + const Offset(0, 20);

  /// 공방 굴뚝 끝(연기가 나는 곳).
  static Offset chimney(Rect r) => workshop(r).topRight + const Offset(-30, 12);
}

// ---------------------------------------------------------------- 서 있는 것들

enum PropKind {
  house,
  barn,
  coop,
  goatShed,
  sheepShed,
  warehouse,
  silo,
  hay,
  tree,
  mill,
  jamKitchen,
  dairy,
  bakery,
  scarecrow,
}

/// 땅 위에 서 있는 구조물·나무. [footprint]는 땅에 닿는 자리(월드 좌표)다.
@immutable
class FarmProp {
  const FarmProp(this.kind, this.footprint, {this.seed = 0, this.deep = false});

  final PropKind kind;
  final Rect footprint;
  final int seed;

  /// 나무: 짙은 잎(바깥 나무를 두 가지 색으로 섞는다).
  final bool deep;

  /// 세운 모습을 놓을 자리(앞쪽 가운데. 둥근 것은 가운데).
  Offset get base => switch (kind) {
    PropKind.tree || PropKind.silo || PropKind.hay || PropKind.scarecrow => footprint.center,
    _ => footprint.bottomCenter,
  };
}

/// 지은 건물에 딸린 구조물·나무.
List<FarmProp> propsForLot(LotId id, BuildingId building) {
  final r = FarmWorld.lotRect(id);
  final seed = id.col * 10 + id.row * 100;
  return switch (building) {
    BuildingId.farmhouse => [
      FarmProp(PropKind.house, LotLayout.house(r), seed: seed + 1),
      FarmProp(PropKind.tree, Rect.fromCircle(center: Offset(r.right - 34, r.top + 38), radius: 19), seed: seed + 2),
      FarmProp(PropKind.tree, Rect.fromCircle(center: Offset(r.right - 74, r.top + 30), radius: 15), seed: seed + 3),
      FarmProp(PropKind.hay, Rect.fromCircle(center: Offset(r.left + 140, r.bottom - 44), radius: 13), seed: seed + 4),
    ],
    BuildingId.storehouse => [
      FarmProp(PropKind.warehouse, LotLayout.warehouse(r), seed: seed + 1),
      for (final (i, p) in LotLayout.silos(r).indexed)
        FarmProp(PropKind.silo, Rect.fromCircle(center: p, radius: 26), seed: seed + 2 + i),
    ],
    BuildingId.coop => [FarmProp(PropKind.coop, LotLayout.shed(r, building), seed: seed + 1)],
    BuildingId.goatPen => [FarmProp(PropKind.goatShed, LotLayout.shed(r, building), seed: seed + 1)],
    BuildingId.sheepPen => [FarmProp(PropKind.sheepShed, LotLayout.shed(r, building), seed: seed + 1)],
    BuildingId.cowBarn => [FarmProp(PropKind.barn, LotLayout.shed(r, building), seed: seed + 1)],
    BuildingId.mill => [FarmProp(PropKind.mill, LotLayout.workshop(r), seed: seed + 1)],
    BuildingId.jamKitchen => [FarmProp(PropKind.jamKitchen, LotLayout.workshop(r), seed: seed + 1)],
    BuildingId.dairy => [FarmProp(PropKind.dairy, LotLayout.workshop(r), seed: seed + 1)],
    BuildingId.bakery => [FarmProp(PropKind.bakery, LotLayout.workshop(r), seed: seed + 1)],
    BuildingId.scarecrow => [
      FarmProp(PropKind.scarecrow, Rect.fromCircle(center: LotLayout.scarecrow(r), radius: 30), seed: seed + 1),
    ],
    BuildingId.field ||
    BuildingId.greenhouse ||
    BuildingId.orchard ||
    BuildingId.pond ||
    BuildingId.flowerBed => const [],
  };
}

/// 위에서 본 모습(평면 지도).
void paintPropFlat(Canvas c, FarmProp p) {
  final rng = math.Random(p.seed);
  final r = p.footprint;
  switch (p.kind) {
    case PropKind.house:
      paintGableHouse(c, r, rng);
      c.drawRect(Rect.fromLTWH(r.left + 104, r.top + 10, 14, 18), fill(const Color(0xFF8C5A44)));
    case PropKind.barn:
      paintGableHouse(c, r, rng, roof: BuildingLook.cowBarnRoof);
    case PropKind.coop:
      paintGableHouse(c, r, rng, roof: BuildingLook.coopRoof);
    case PropKind.goatShed:
      paintGableHouse(c, r, rng, roof: BuildingLook.goatRoof);
    case PropKind.sheepShed:
      paintGableHouse(c, r, rng, roof: BuildingLook.sheepRoof);
    case PropKind.warehouse:
      paintGableHouse(c, r, rng, roof: BuildingLook.warehouseRoof);
    case PropKind.mill:
      paintGableHouse(c, r, rng, roof: BuildingLook.millRoof);
      // 옆에 물레방아.
      final wheel = Offset(r.left - 6, r.center.dy);
      c.drawCircle(wheel, 22, fill(Tint.wood));
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        c.drawLine(wheel, wheel + Offset(math.cos(a), math.sin(a)) * 22, pen(const Color(0xFF5E4630), 2));
      }
    case PropKind.jamKitchen:
      paintGableHouse(c, r, rng, roof: BuildingLook.jamRoof);
    case PropKind.dairy:
      paintGableHouse(c, r, rng, roof: BuildingLook.dairyRoof);
    case PropKind.bakery:
      paintGableHouse(c, r, rng, roof: BuildingLook.bakeryRoof);
      c.drawRect(Rect.fromLTWH(r.right - 38, r.top + 8, 16, 20), fill(const Color(0xFF8C5A44)));
    case PropKind.silo:
      paintSilo(c, r.center, r.width / 2, rng);
    case PropKind.hay:
      paintHayBale(c, r.center, r.width / 2, rng);
    case PropKind.tree:
      paintTree(c, r.center, r.width / 2, rng, leaf: p.deep ? Tint.grassDeep : Tint.leaf);
    case PropKind.scarecrow:
      paintScarecrowFlat(c, r.center, rng);
  }
}

// ---------------------------------------------------------------- 지금 상태(그림 입력)

/// 지도 한 장을 그리는 데 필요한 게임 상태 요약.
@immutable
class FarmScene {
  const FarmScene({
    required this.lots,
    required this.props,
    required this.propsKey,
    required this.animals,
    required this.stored,
    required this.ready,
    required this.crafts,
    required this.expandable,
    required this.waterRatio,
    required this.barnRatio,
    required this.labels,
    required this.icons,
    required this.semantics,
  });

  /// 땅 전체 칸(위에서 아래, 왼쪽에서 오른쪽).
  final List<LotVisual> lots;

  /// 지은 건물의 구조물과 바깥 나무.
  final List<FarmProp> props;
  final String propsKey;

  /// (종, 새끼인지, 사는 우리). 들인 순서대로.
  final List<(Species, bool, LotId)> animals;

  /// 우리별 쌓인 생산물(종, 개수).
  final Map<LotId, (Species, int)> stored;

  /// 다 자란 작물이 있는 칸.
  final Map<LotId, CropId> ready;

  /// 공방 칸 → (만드는 가공품, 다 만들었는지).
  final Map<LotId, (ItemId, bool)> crafts;

  /// 지금 넓힐 수 있는 칸(가진 땅에 붙어 있고 레벨 한도가 남았다).
  final Set<LotId> expandable;
  final double waterRatio;
  final double barnRatio;

  /// 칸 이름표(없으면 표시하지 않는다)와 그 아이콘.
  final Map<LotId, String> labels;
  final Map<LotId, IconData> icons;
  final Map<LotId, String> semantics;

  LotVisual lot(LotId id) => lots[id.row * landCols + id.col];

  /// 지은 건물 칸들(종류별로 찾을 때).
  Iterable<(LotId, BuildingId)> get buildings sync* {
    for (final v in lots) {
      if (v.building case final b?) yield (v.id, b);
    }
  }

  factory FarmScene.of(GameState s, AppLocalizations l) {
    final visuals = <LotVisual>[];
    final labels = <LotId, String>{};
    final icons = <LotId, IconData>{};
    final semantics = <LotId, String>{};
    final ready = <LotId, CropId>{};
    final props = <FarmProp>[];
    final keyParts = <String>[];
    final expandable = <LotId>{};
    final crafts = <LotId, (ItemId, bool)>{};
    final nextLevel = s.expansions ~/ 2 + 2;
    final cost = s.nextExpansionCost;
    for (final id in LotId.all) {
      final lot = s.lots[id];
      if (lot != null) {
        final f = lot.field;
        visuals.add(
          LotVisual.built(id, lot.building, level: lot.level, crop: f?.crop, stage: f == null ? null : cropStage(f)),
        );
        props.addAll(propsForLot(id, lot.building));
        keyParts.add('${id.key}:${lot.building.name}');
        final name = l.building(lot.building);
        labels[id] = lot.level > 1 ? l.lotLevelLabel(name, lot.level) : name;
        icons[id] = BuildingLook.icon(lot.building);
        if (f?.ready ?? false) ready[id] = f!.crop!;
        if (lot.job case final job? when lot.def.recipe != null) crafts[id] = (lot.def.recipe!.output, job.done);
        semantics[id] = switch (f) {
          FieldState(ready: true, :final crop?) => l.mapZoneReady(name, l.crop(crop)),
          FieldState(:final crop?) => l.mapZoneGrowing(name, l.crop(crop)),
          _ => switch (lot.job) {
            WorkshopJob(done: true) => l.mapWorkshopDone(name),
            WorkshopJob() => l.mapWorkshopWorking(name),
            null => name,
          },
        };
      } else if (s.owned.contains(id)) {
        visuals.add(LotVisual.empty(id));
        labels[id] = l.emptyLot;
        icons[id] = Icons.add_rounded;
        semantics[id] = l.mapLotEmpty;
      } else {
        final kind = wildKindOf(id);
        final reachable = s.touchesOwned(id);
        visuals.add(LotVisual.wild(id, kind, reachable: reachable));
        final name = l.wild(kind);
        if (reachable && cost != null) {
          if (s.expansionsLeft > 0) {
            expandable.add(id);
            labels[id] = '🪙$cost';
            semantics[id] = l.mapLotExpand(name, cost);
          } else {
            labels[id] = l.levelShort(nextLevel);
            semantics[id] = l.mapLotExpandLevel(name, nextLevel);
          }
          icons[id] = Icons.landscape_outlined;
        } else {
          semantics[id] = name;
        }
      }
    }
    props.addAll(FarmWorld.outerTrees);
    final stored = <LotId, (Species, int)>{};
    for (final a in s.animals) {
      if (a.stored > 0) stored[a.home] = (a.species, (stored[a.home]?.$2 ?? 0) + a.stored);
    }
    return FarmScene(
      lots: visuals,
      props: props,
      propsKey: keyParts.join(';'),
      animals: [for (final a in s.animals) (a.species, !a.adult, a.home)],
      stored: stored,
      ready: ready,
      crafts: crafts,
      expandable: expandable,
      waterRatio: s.water / s.waterCapacity,
      barnRatio: s.barnUsed / s.barnCapacity,
      labels: labels,
      icons: icons,
      semantics: semantics,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FarmScene &&
      listEquals(other.lots, lots) &&
      listEquals(other.animals, animals) &&
      mapEquals(other.stored, stored) &&
      mapEquals(other.ready, ready) &&
      mapEquals(other.crafts, crafts) &&
      other.expandable.length == expandable.length &&
      other.expandable.containsAll(expandable) &&
      other.waterRatio == waterRatio &&
      other.barnRatio == barnRatio &&
      mapEquals(other.labels, labels) &&
      mapEquals(other.semantics, semantics);

  @override
  int get hashCode => Object.hash(propsKey, ready.length, animals.length, waterRatio, barnRatio);
}

/// 날씨·밤 그림이 쓰는 자리(물·창문·온실·반딧불·작물 칸).
SkySpots skySpotsOf(FarmScene scene) {
  final waters = <Rect>[];
  final windows = <Offset>[];
  final glows = <Offset>[];
  final fireflies = <Rect>[];
  final plots = <Rect>[];
  for (final (id, b) in scene.buildings) {
    final r = FarmWorld.lotRect(id);
    switch (b) {
      case BuildingId.farmhouse:
        final tank = LotLayout.tank(r);
        waters.add(Rect.fromCircle(center: tank, radius: LotLayout.tankRadius * 0.8));
        final house = LotLayout.house(r);
        windows.addAll([house.bottomCenter + const Offset(0, 8), house.bottomLeft + const Offset(26, 8)]);
        fireflies.add(Rect.fromCircle(center: tank, radius: 70));
      case BuildingId.storehouse:
        windows.add(LotLayout.warehouse(r).bottomCenter + const Offset(0, 8));
      case BuildingId.coop || BuildingId.goatPen || BuildingId.sheepPen || BuildingId.cowBarn:
        windows.add(LotLayout.door(r, b));
        fireflies.add(LotLayout.pasture(r, b));
      case BuildingId.greenhouse:
        glows.add(r.center);
        plots.add(r);
      case BuildingId.orchard:
        fireflies.add(r);
        plots.add(r);
      case BuildingId.field:
        plots.add(r);
      case BuildingId.mill || BuildingId.jamKitchen || BuildingId.dairy || BuildingId.bakery:
        windows.add(LotLayout.workshop(r).bottomCenter + const Offset(0, 8));
      case BuildingId.pond:
        waters.add(LotLayout.pond(r).deflate(10));
        fireflies.add(r);
      case BuildingId.flowerBed:
        fireflies.add(r);
      case BuildingId.scarecrow:
        break;
    }
  }
  return SkySpots(waters: waters, windows: windows, glows: glows, fireflies: fireflies, plots: plots);
}

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

/// 지도 위 말풍선: 쌓인 생산물(우리 위쪽)과 다 자란 작물.
typedef MapBubble = ({Offset at, String emoji, String? count, bool highlight, double Function(double t) bob});

List<MapBubble> mapBubbles(FarmScene scene) {
  final out = <MapBubble>[];
  for (final (i, MapEntry(key: id, value: (species, n))) in scene.stored.entries.indexed) {
    final building = scene.lot(id).building;
    if (building == null) continue;
    final pasture = LotLayout.pasture(FarmWorld.lotRect(id), building);
    final phase = i.toDouble();
    out.add((
      at: Offset(pasture.center.dx + 36, pasture.top - 6),
      emoji: itemEmoji(GameDefs.animals[species]!.product),
      count: '$n',
      highlight: false,
      bob: (t) => math.sin(t * 2.4 + phase) * 3,
    ));
  }
  for (final MapEntry(key: id, value: (item, done)) in scene.crafts.entries) {
    if (!done) continue;
    final shop = LotLayout.workshop(FarmWorld.lotRect(id));
    out.add((
      at: shop.topCenter + const Offset(0, -14),
      emoji: itemEmoji(item),
      count: null,
      highlight: true,
      bob: (t) => math.sin(t * 3) * 4,
    ));
  }
  for (final MapEntry(key: id, value: crop) in scene.ready.entries) {
    final r = FarmWorld.lotRect(id);
    out.add((
      at: Offset(r.right - 40, r.top + 34),
      emoji: cropEmoji(crop),
      count: null,
      highlight: true,
      bob: (t) => math.sin(t * 3) * 4,
    ));
  }
  return out;
}

/// 우리 안 동물의 자리와 움직이는 방향. 비·눈·밤·폭염에는 우리 건물 문 앞으로 모인다.
typedef AnimalPlacement = ({Species species, bool young, Offset at, Offset heading, int index});

double _hash(double x) => (math.sin(x) * 43758.5453).abs() % 1;

List<AnimalPlacement> animalPlacements(FarmScene scene, SkyView sky, double t) {
  final shelter = sky.shelter;
  final out = <AnimalPlacement>[];
  for (final (i, (species, young, home)) in scene.animals.indexed) {
    final building = scene.lot(home).building;
    if (building == null) continue;
    final r = FarmWorld.lotRect(home);
    final area = LotLayout.pasture(r, building);
    final seed = i * 7.31 + species.index * 2.17;
    final spot = Offset(
      area.left + area.width * (0.12 + 0.76 * _hash(seed * 12.9898)),
      area.top + area.height * (0.12 + 0.76 * _hash(seed * 78.233)),
    );
    final speed = species == Species.chicken ? 0.55 : 0.14;
    final reach = species == Species.chicken ? 12.0 : 20.0;
    final huddle = LotLayout.door(r, building) + Offset((_hash(seed * 3.1) - 0.5) * 60, (_hash(seed * 5.7) - 0.5) * 30);
    final rest = Offset.lerp(spot, huddle, shelter)!;
    final wander = reach * (1 - 0.7 * shelter);
    out.add((
      species: species,
      young: young,
      at: rest + Offset(math.sin(t * speed + seed) * wander, math.sin(t * speed * 1.3 + seed * 1.7) * wander * 0.6),
      heading: Offset(math.cos(t * speed + seed), math.cos(t * speed * 1.3 + seed * 1.7) * 0.78),
      index: i,
    ));
  }
  return out;
}

/// 말풍선. [center]는 그 캔버스의 좌표(지도 월드 또는 화면)다.
void paintBubble(Canvas c, Offset center, String emoji, String? count, {bool highlight = false}) {
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

/// 칸 이름표. [at]은 왼쪽 위([bottomCenter]면 아래 가운데), [k]는 글자 크기 배율(월드에 그릴 때는 화면 배율을
/// 상쇄한 값).
void paintZoneTag(
  Canvas canvas,
  Offset at,
  String label,
  IconData icon,
  double k,
  double opacity, {
  bool bottomCenter = false,
}) {
  final tp = _text(label, size: 22);
  final iconText = _icon(icon, 22, AppColors.primary);
  final w = (tp.width + 46) * k;
  final h = 40 * k;
  final box = bottomCenter ? Rect.fromLTWH(at.dx - w / 2, at.dy - h, w, h) : Rect.fromLTWH(at.dx, at.dy, w, h);
  final tag = RRect.fromRectAndRadius(box, Radius.circular(h / 2));
  canvas.drawRRect(tag.shift(Offset(0, 2 * k)), fill(Tint.shadow.withValues(alpha: 0.2 * opacity)));
  canvas.drawRRect(tag, fill(const Color(0xFFFFFBF0).withValues(alpha: 0.95 * opacity)));
  canvas.drawRRect(tag, pen(Tint.line.withValues(alpha: 0.4 * opacity), 2.4 * k));
  final opaque = opacity >= 1;
  if (!opaque) canvas.saveLayer(box, Paint()..color = Colors.black.withValues(alpha: opacity));
  canvas.save();
  canvas.translate(box.left + 14 * k, box.top + (h - tp.height * k) / 2);
  canvas.scale(k);
  iconText.paint(canvas, Offset(0, (tp.height - iconText.height) / 2));
  tp.paint(canvas, const Offset(26, 0));
  canvas.restore();
  if (!opaque) canvas.restore();
}

class FarmMapPainter extends CustomPainter {
  FarmMapPainter({
    required this.view,
    required this.time,
    required this.selected,
    required this.selectionT,
    required this.labelOpacity,
    required this.scene,
    required this.sky,
    this.upright = 0,
    this.onZoneTap,
    this.textDirection = TextDirection.ltr,
  }) : super(repaint: time);

  final Rect view;
  final ValueNotifier<double> time;
  final LotId? selected;
  final double selectionT;
  final double labelOpacity;
  final FarmScene scene;
  final SkyView sky;

  /// 지도판을 눕힌 정도(0~1). 그만큼 구조물·동물·말풍선·이름표를 세운 그림(upright.dart)에 넘기고 여기서는 흐린다.
  final double upright;
  final ValueChanged<LotId>? onZoneTap;
  final TextDirection textDirection;

  static double scaleFor(Rect view, Size size) => math.max(size.width / view.width, size.height / view.height);

  static void _blit(Canvas c, ui.Image img, Rect dst, {double opacity = 1}) => c.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    dst,
    Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(0, 0, 0, opacity),
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
    final flat = 1 - upright;
    for (final v in scene.lots) {
      final dst = FarmWorld.lotRect(v.id).inflate(14);
      if (upright > 0 && v.swapsInSky) {
        // 세운 작물(upright.dart)과 겹치지 않게, 눕힐수록 작물 없는 바닥으로 바꾼다.
        _blit(canvas, FarmWorld.lotImage(v.bare), dst);
        if (flat > 0) _blit(canvas, FarmWorld.lotImage(v), dst, opacity: flat);
      } else {
        _blit(canvas, FarmWorld.lotImage(v), dst);
      }
    }
    _drawVeils(canvas);
    if (flat > 0) _blit(canvas, FarmWorld.propsFlat(scene.props, scene.propsKey), FarmWorld.bakeArea, opacity: flat);

    _drawWater(canvas, t);
    _drawSprinklers(canvas, t);
    _drawSmoke(canvas, t);
    _drawCrates(canvas);
    _fading(canvas, flat, () => _drawAnimals(canvas, t));
    _drawTractor(canvas, t);
    final spots = skySpotsOf(scene);
    paintWeather(canvas, sky, view, t, spots);
    paintDaylight(canvas, sky, view, t, spots, buildingLights: flat);
    _fading(canvas, flat, () => _drawBubbles(canvas, t));

    if (selected != null && selectionT > 0) {
      final r = FarmWorld.lotRect(selected!).inflate(5);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(18));
      canvas.drawRRect(rr, pen(const Color(0xFFFFF8E6).withValues(alpha: 0.85 * selectionT), 10 / scale));
      canvas.drawRRect(rr, pen(AppColors.orange.withValues(alpha: selectionT), 3.5 / scale));
    }
    if (labelOpacity * flat > 0) {
      for (final MapEntry(key: id, value: label) in scene.labels.entries) {
        final r = FarmWorld.lotRect(id);
        paintZoneTag(
          canvas,
          Offset(r.left + 10, r.top + 10),
          label,
          scene.icons[id] ?? Icons.place_outlined,
          0.42 / scale,
          labelOpacity * flat,
        );
      }
    }
    canvas.restore();
  }

  /// 아직 넓힐 수 없는 땅은 종이색으로 덮어 흐리게 한다(붙은 칸은 옅게, 먼 칸은 짙게).
  void _drawVeils(Canvas c) {
    for (final v in scene.lots) {
      if (v.wild == null) continue;
      if (scene.expandable.contains(v.id)) continue;
      final r = FarmWorld.lotRect(v.id).deflate(2);
      c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(22)),
        fill(const Color(0xFFF1EADB).withValues(alpha: v.reachable ? 0.35 : 0.6)),
      );
    }
  }

  /// [opacity]가 1보다 작으면 반투명 레이어에 그린다(0이면 그리지 않는다).
  static void _fading(Canvas c, double opacity, VoidCallback draw) {
    if (opacity <= 0) return;
    if (opacity >= 1) return draw();
    c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    draw();
    c.restore();
  }

  void _drawWater(Canvas c, double t) {
    for (final (id, b) in scene.buildings) {
      if (b != BuildingId.farmhouse) continue;
      final center = LotLayout.tank(FarmWorld.lotRect(id));
      final r = LotLayout.tankRadius * 0.84;
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
  }

  /// 만드는 중인 공방 굴뚝 연기.
  void _drawSmoke(Canvas c, double t) {
    for (final MapEntry(key: id, value: (_, done)) in scene.crafts.entries) {
      if (done) continue;
      final p = LotLayout.chimney(FarmWorld.lotRect(id));
      for (var i = 0; i < 4; i++) {
        final u = (t * 0.5 + i / 4 + id.col * 0.13) % 1;
        c.drawCircle(
          p + Offset(math.sin(t + i) * 6 + u * 14, -u * 60),
          6 + u * 10,
          fill(const Color(0xFFF2EEE6).withValues(alpha: 0.55 * (1 - u))),
        );
      }
    }
  }

  /// Lv3 작물 건물(저절로 거두고 다시 심는 곳)의 회전 스프링클러.
  void _drawSprinklers(Canvas c, double t) {
    for (final v in scene.lots) {
      if (v.level < GameDefs.autoLevel || v.building == null || GameDefs.buildings[v.building]!.plot == null) continue;
      final r = FarmWorld.lotRect(v.id);
      final p = Offset(r.center.dx, r.bottom - 22);
      final spin = t * 1.6 + v.id.col * 1.3 + v.id.row;
      for (var i = 0; i < 3; i++) {
        final a = spin + i * 2.1;
        final path = Path()
          ..moveTo(p.dx, p.dy)
          ..quadraticBezierTo(
            p.dx + math.cos(a) * 46,
            p.dy + math.sin(a) * 26 - 30,
            p.dx + math.cos(a) * 80,
            p.dy + math.sin(a) * 50,
          );
        c.drawPath(path, pen(const Color(0xFFDDEFF6).withValues(alpha: 0.55), 2.2));
      }
      c.drawCircle(p, 6, fill(const Color(0xFF7D8A8E)));
      c.drawCircle(p, 6, pen(Tint.line.withValues(alpha: 0.5), 1.2));
    }
  }

  void _drawCrates(Canvas c) {
    for (final (id, b) in scene.buildings) {
      if (b != BuildingId.storehouse) continue;
      final r = FarmWorld.lotRect(id);
      final n = (scene.barnRatio * 6).ceil().clamp(0, 6);
      for (var i = 0; i < n; i++) {
        paintCrate(c, Rect.fromLTWH(r.left + 30 + (i % 3) * 24, r.bottom - 74 + (i ~/ 3) * 24, 20, 20));
      }
    }
  }

  void _drawAnimals(Canvas c, double t) {
    for (final a in animalPlacements(scene, sky, t)) {
      final angle = math.atan2(a.heading.dy, a.heading.dx);
      final scale = a.young ? 0.62 : 1.0;
      switch (a.species) {
        case Species.cow:
          drawCow(c, a.at, angle, scale);
        case Species.goat:
          drawGoat(c, a.at, angle, scale);
        case Species.sheep:
          drawSheep(c, a.at, angle, scale);
        case Species.chicken:
          drawChicken(c, a.at, t, a.index, scale);
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

  void _drawBubbles(Canvas c, double t) {
    for (final b in mapBubbles(scene)) {
      paintBubble(c, b.at + Offset(0, b.bob(t)), b.emoji, b.count, highlight: b.highlight);
    }
  }

  @override
  SemanticsBuilderCallback? get semanticsBuilder => scene.semantics.isEmpty ? null : _buildSemantics;

  /// 화면에 보이는 칸마다 탭할 수 있는 영역을 만든다(칸을 확대하면 보이는 칸만 남는다).
  List<CustomPainterSemantics> _buildSemantics(Size size) {
    final scale = scaleFor(view, size);
    final screen = Offset.zero & size;
    Offset toScreen(Offset world) => (world - view.center) * scale + size.center(Offset.zero);
    return [
      for (final MapEntry(key: id, value: label) in scene.semantics.entries)
        if (Rect.fromPoints(toScreen(FarmWorld.lotRect(id).topLeft), toScreen(FarmWorld.lotRect(id).bottomRight))
            case final rect when rect.overlaps(screen))
          CustomPainterSemantics(
            key: ValueKey(id),
            rect: rect.intersect(screen),
            properties: SemanticsProperties(
              label: label,
              textDirection: textDirection,
              button: true,
              selected: id == selected,
              onTap: onZoneTap == null ? null : () => onZoneTap!(id),
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
      old.scene != scene ||
      old.sky != sky;
}
