import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game/zone.dart';
import '../../l10n/l10n.dart';
import 'farm_world.dart';
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
      return GestureDetector(
        onTapUp: (d) => _handleTap(d, size),
        child: AnimatedBuilder(
          animation: _camera,
          builder: (context, _) {
            final focusT = widget.selected == null ? 1 - _camera.value : _camera.value;
            return RepaintBoundary(
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
                    onZoneTap: widget.onZoneTap,
                    textDirection: Directionality.of(context),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
