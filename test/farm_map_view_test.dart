import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/features/farm/farm_map_view.dart';
import 'package:my_farm/features/farm/farm_world.dart';
import 'package:my_farm/features/farm/sky_band.dart';
import 'package:my_farm/features/farm/sky_layer.dart';
import 'package:my_farm/game/engine.dart';
import 'package:my_farm/game/zone.dart';
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

  testWidgets('눕힌 지도에서 구역이 보이는 자리를 누르면 그 구역이 열린다', (tester) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 10, 6, 12);
    final scene = FarmScene.of(GameEngine.newGame(now, farmName: 'x'), AppLocalizationsKo());
    final tapped = <ZoneId>[];
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
              scene: scene,
              sky: SkyView.at(now),
              aspect: size.width / size.height,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final view = FarmWorld.overviewRect(size.width / size.height);
    final scale = FarmMapPainter.scaleFor(view, size);
    final matrix = FarmTilt.matrix(size, 1);
    Offset onScreen(ZoneId zone) {
      final local = (FarmWorld.zones[zone]!.center - view.center) * scale + size.center(Offset.zero);
      return MatrixUtils.transformPoint(matrix, local);
    }

    // 먼 줄(집)·가운데(가축 우리)·앞줄(과수원)을 원근을 거친 화면 위치로 누른다.
    for (final zone in [ZoneId.house, ZoneId.animals, ZoneId.orchard]) {
      await tester.tapAt(onScreen(zone));
      await tester.pump();
    }
    expect(tapped, [ZoneId.house, ZoneId.animals, ZoneId.orchard]);
    // 가장 먼 줄(집)도 하늘이 아니라 지평선 아래 지도판 위에 있다.
    expect(onScreen(ZoneId.house).dy, greaterThan(FarmTilt.horizonY(size, 1)));
    await tester.pumpWidget(const SizedBox());
  });
}
