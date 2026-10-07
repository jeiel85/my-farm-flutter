import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game/zone.dart';
import '../../l10n/l10n.dart';
import 'farm_world.dart';
import 'sky_band.dart';
import 'upright.dart';
import 'sky_layer.dart';

/// 선택한 구역으로 카메라가 부드럽게 이동하는 농장 지도.
/// [selected]가 null이면 전체 지도를 보여 준다. [skyMode]이면 지도판을 눕혀 하늘을 연다(디오라마).
class FarmMapView extends StatefulWidget {
  const FarmMapView({
    super.key,
    required this.selected,
    required this.onZoneTap,
    required this.scene,
    required this.sky,
    this.skyMode = false,
    this.onSkyTap,
    this.focusBias = 0,
    this.aspect = 0.8,
  });

  final ZoneId? selected;
  final ValueChanged<ZoneId> onZoneTap;
  final FarmScene scene;
  final SkyView sky;

  /// 하늘 보기. 이 동안 지도를 누르면 구역을 고르지 않고 [onSkyTap]을 부른다(평면으로 돌아가기).
  final bool skyMode;
  final VoidCallback? onSkyTap;

  /// 고른 구역을 화면에서 위로 올리는 정도(구역 높이 비율). 휴대폰은 아래 시트에 가리지 않게 올린다.
  final double focusBias;
  final double aspect;

  @override
  State<FarmMapView> createState() => _FarmMapViewState();
}

class _FarmMapViewState extends State<FarmMapView> with TickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  late final AnimationController _camera;
  late final AnimationController _tilt;
  late Rect _from;
  late Rect _to;

  Rect _targetFor(ZoneId? zone) {
    if (zone == null) return FarmWorld.overviewRect(widget.aspect);
    final r = FarmWorld.focusRect(zone, widget.aspect);
    return r.shift(Offset(0, r.height * widget.focusBias));
  }

  Rect get _view => Rect.lerp(_from, _to, Curves.easeInOutCubic.transform(_camera.value))!;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => _time.value = elapsed.inMicroseconds / 1e6)..start();
    _camera = AnimationController(vsync: this, duration: const Duration(milliseconds: 780), value: 1);
    _tilt = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
      value: widget.skyMode ? 1 : 0,
    );
    _from = _to = _targetFor(widget.selected);
  }

  @override
  void didUpdateWidget(FarmMapView old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected || old.aspect != widget.aspect || old.focusBias != widget.focusBias) {
      _from = _view;
      _to = _targetFor(widget.selected);
      _camera.forward(from: 0);
    }
    if (old.skyMode != widget.skyMode) {
      widget.skyMode ? _tilt.forward() : _tilt.reverse();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _camera.dispose();
    _tilt.dispose();
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
        animation: Listenable.merge([_camera, _tilt]),
        builder: (context, _) {
          final focusT = widget.selected == null ? 1 - _camera.value : _camera.value;
          final labelOpacity = widget.selected == null ? Curves.easeIn.transform(1 - focusT.clamp(0.0, 1.0)) : 0.0;
          // 하늘 보기에서만 지도판을 눕힌다. 평소에는 평면이라 먼 줄도 크게 보이고 누르기 쉽다.
          final k = Curves.easeInOutCubic.transform(_tilt.value);
          final horizon = FarmTilt.horizonY(size, k);
          final map = GestureDetector(
            key: const ValueKey('map'),
            onTapUp: widget.skyMode ? null : (d) => _handleTap(d, size),
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
                    labelOpacity: labelOpacity,
                    scene: widget.scene,
                    sky: widget.sky,
                    upright: k,
                    onZoneTap: widget.skyMode ? (_) => widget.onSkyTap?.call() : widget.onZoneTap,
                    textDirection: Directionality.of(context),
                  ),
                ),
              ),
            ),
          );
          return GestureDetector(
            // 하늘 보기 중에는 어디를 눌러도 평면으로 돌아간다(하늘·능선 부분 포함).
            onTap: widget.skyMode ? widget.onSkyTap : null,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (k > 0)
                  RepaintBoundary(
                    key: const ValueKey('sky'),
                    child: CustomPaint(
                      painter: SkyBackPainter(sky: widget.sky, time: _time, horizon: horizon, k: k),
                    ),
                  ),
                Transform(key: const ValueKey('board'), transform: FarmTilt.matrix(size, k), child: map),
                if (k > 0) ...[
                  IgnorePointer(
                    key: const ValueKey('ridge'),
                    child: CustomPaint(
                      painter: HorizonFrontPainter(sky: widget.sky, horizon: horizon, k: k),
                    ),
                  ),
                  IgnorePointer(
                    key: const ValueKey('upright'),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: FarmUprightPainter(
                          view: _view,
                          time: _time,
                          k: k,
                          scene: widget.scene,
                          sky: widget.sky,
                          labelOpacity: labelOpacity,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}
