import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/features/farm/farm_map_view.dart';
import 'package:my_farm/features/farm/farm_world.dart';
import 'package:my_farm/features/farm/sky_band.dart';
import 'package:my_farm/features/farm/sky_layer.dart';
import 'package:my_farm/game/engine.dart';
import 'package:my_farm/game/defs.dart';
import 'package:my_farm/game/lots.dart';
import 'package:my_farm/l10n/app_localizations.dart';
import 'package:my_farm/l10n/app_localizations_ko.dart';

void main() {
  const size = Size(400, 460);

  test('지도판은 지평선이 화면 위쪽 20~40%에 오도록 눕고, 다 펴면 변환이 없다', () {
    final horizon = FarmTilt.horizonY(size, 1);
    expect(horizon / size.height, inInclusiveRange(0.2, 0.4));
    expect(FarmTilt.matrix(size, 0), Matrix4.identity());
    expect(FarmTilt.horizonY(size, 0), 0);
    // 앞쪽 아래 가운데는 움직이지 않는다(눕히는 축).
    final bottom = MatrixUtils.transformPoint(FarmTilt.matrix(size, 1), Offset(size.width / 2, size.height));
    expect(bottom.dx, closeTo(size.width / 2, 0.01));
    expect(bottom.dy, closeTo(size.height, 0.01));
  });

  Future<(List<LotId>, List<String>)> pumpMap(WidgetTester tester, {required bool skyMode}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 10, 6, 12);
    final scene = FarmScene.of(GameEngine.newGame(now, farmName: 'x'), AppLocalizationsKo());
    final tapped = <LotId>[];
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: size,
            child: FarmMapView(
              selected: null,
              onZoneTap: tapped.add,
              onSkyTap: () => events.add('sky'),
              skyMode: skyMode,
              scene: scene,
              sky: SkyView.at(now),
              aspect: size.width / size.height,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return (tapped, events);
  }

  Offset flatCenter(LotId lot) {
    final view = FarmWorld.overviewRect(size.width / size.height);
    final scale = FarmMapPainter.scaleFor(view, size);
    return (FarmWorld.lotRect(lot).center - view.center) * scale + size.center(Offset.zero);
  }

  testWidgets('평소에는 평면 지도라 구역 자리를 누르면 그 구역이 열린다', (tester) async {
    final (tapped, events) = await pumpMap(tester, skyMode: false);
    for (final lot in [GameDefs.farmhouseLot, GameDefs.startCoopLot, const LotId(3, 4)]) {
      await tester.tapAt(flatCenter(lot));
      await tester.pump();
    }
    expect(tapped, [GameDefs.farmhouseLot, GameDefs.startCoopLot, const LotId(3, 4)]);
    expect(events, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('하늘 보기에서는 눕힌 지도판 위 구역을 누르면 그 구역을, 하늘을 누르면 돌아가기를 부른다', (tester) async {
    final (tapped, events) = await pumpMap(tester, skyMode: true);
    // 원근을 거친 화면 위치로 가축 우리를 누르고, 맨 위 하늘을 누른다.
    await tester.tapAt(MatrixUtils.transformPoint(FarmTilt.matrix(size, 1), flatCenter(GameDefs.startCoopLot)));
    await tester.pump();
    await tester.tapAt(const Offset(200, 20));
    await tester.pump();
    expect(tapped, [GameDefs.startCoopLot]);
    expect(events, ['sky']);
    await tester.pumpWidget(const SizedBox());
  });

  // 하늘 보기에서 작물을 세워 그리면, 바닥 그림의 평면 작물은 작물 없는 같은 칸으로 바꿔 두 번 그려지지 않게 한다.
  test('심어 둔 밭·온실·과수원만 작물을 세워 그리고, 바꿀 바닥 그림에는 작물이 없다', () {
    const field = LotVisual.built(LotId(1, 1), BuildingId.field, level: 2, crop: CropId.corn, stage: 2);
    expect(field.hasUprightCrop, isTrue);
    expect(field.bare.crop, isNull);
    expect(field.bare.stage, isNull);
    expect(field.bare.level, 2);
    expect(field.bare.key, isNot(field.key));
    expect(const LotVisual.built(LotId(1, 1), BuildingId.field).hasUprightCrop, isFalse);
    expect(
      const LotVisual.built(LotId(0, 1), BuildingId.greenhouse, crop: CropId.strawberry, stage: 3).hasUprightCrop,
      isTrue,
    );
    expect(const LotVisual.built(LotId(3, 1), BuildingId.orchard, crop: CropId.apple, stage: 0).hasUprightCrop, isTrue);
    expect(const LotVisual.built(LotId(2, 1), BuildingId.coop).hasUprightCrop, isFalse);
  });
}
