import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game/zone.dart';
import '../../l10n/l10n.dart';
import 'farm_world.dart';
import 'sky_band.dart';
import 'upright.dart';
import 'sky_layer.dart';

/// 선택한 구역으로 카메라가 부드럽게 이동하는 농장 지도.
/// [selected]가 null이면 전체 지도를 보여 준다.
class FarmMapView extends StatefulWidget {
  const FarmMapView({
    super.key,
    required this.selected,
    required this.onZoneTap,
    required this.scene,
    required this.sky,
    this.aspect = 0.8,
  });

  final ZoneId? selected;
  final ValueChanged<ZoneId> onZoneTap;
  final FarmScene scene;
  final SkyView sky;
  final double aspect;

  @override
  State<FarmMapView> createState() => _FarmMapViewState();
}

class _FarmMapViewState extends State<FarmMapView> with TickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  late final AnimationController _camera;
  late Rect _from;
  late Rect _to;

  Rect _targetFor(ZoneId? zone) =>
      zone == null ? FarmWorld.overviewRect(widget.aspect) : FarmWorld.focusRect(zone, widget.aspect);

  Rect get _view => Rect.lerp(_from, _to, Curves.easeInOutCubic.transform(_camera.value))!;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => _time.value = elapsed.inMicroseconds / 1e6)..start();
    _camera = AnimationController(vsync: this, duration: const Duration(milliseconds: 780), value: 1);
    _from = _to = _targetFor(widget.selected);
  }

  @override
  void didUpdateWidget(FarmMapView old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected || old.aspect != widget.aspect) {
      _from = _view;
      _to = _targetFor(widget.selected);
      _camera.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _camera.dispose();
    _time.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails d, Size size) {
    final view = _view;
    final scale = FarmMapPainter.scaleFor(view, size);
    final world = view.center + (d.localPosition - size.center(Offset.zero)) / scale;
    final zone = FarmWorld.hitTest(world);
    if (zone != null) widget.onZoneTap(zone);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      return AnimatedBuilder(
        animation: _camera,
        builder: (context, _) {
          final focusT = widget.selected == null ? 1 - _camera.value : _camera.value;
          // 전체 지도에서는 지도판을 눕혀 하늘을 보이고, 구역을 확대할수록 평평하게 편다.
          final k = Curves.easeInOutCubic.transform(widget.selected == null ? _camera.value : 1 - _camera.value);
          final horizon = FarmTilt.horizonY(size, k);
          final map = GestureDetector(
            onTapUp: (d) => _handleTap(d, size),
            child: RepaintBoundary(
              child: Semantics(
                label: context.l10n.farmMap,
                container: true,
                explicitChildNodes: true,
                child: CustomPaint(
                  size: size,
                  isComplex: true,
                  painter: FarmMapPainter(
                    view: _view,
                    time: _time,
                    selected: widget.selected,
                    selectionT: widget.selected == null ? 0 : Curves.easeOut.transform(focusT.clamp(0, 1)),
                    labelOpacity: widget.selected == null ? Curves.easeIn.transform(1 - focusT.clamp(0.0, 1.0)) : 0,
                    scene: widget.scene,
                    sky: widget.sky,
                    upright: k,
                    onZoneTap: widget.onZoneTap,
                    textDirection: Directionality.of(context),
                  ),
                ),
              ),
            ),
          );
          if (k <= 0) return map;
          return Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: SkyBackPainter(sky: widget.sky, time: _time, horizon: horizon, k: k),
                ),
              ),
              Transform(transform: FarmTilt.matrix(size, k), child: map),
              IgnorePointer(
                child: CustomPaint(
                  painter: HorizonFrontPainter(sky: widget.sky, horizon: horizon, k: k),
                ),
              ),
              IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: FarmUprightPainter(
                      view: _view,
                      time: _time,
                      k: k,
                      scene: widget.scene,
                      sky: widget.sky,
                      labelOpacity: widget.selected == null ? Curves.easeIn.transform(1 - focusT.clamp(0.0, 1.0)) : 0,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
