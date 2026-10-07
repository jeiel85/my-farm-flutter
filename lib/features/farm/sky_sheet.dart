import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../game/game_store.dart';
import '../../game/sky.dart';
import '../../l10n/l10n.dart';
import 'sky_layer.dart';

IconData skyIcon(SkyKind k) => switch (k) {
  SkyKind.clear => Icons.wb_sunny_rounded,
  SkyKind.cloudy => Icons.cloud_rounded,
  SkyKind.windy => Icons.air_rounded,
  SkyKind.rain => Icons.water_drop_rounded,
  SkyKind.snow => Icons.ac_unit_rounded,
  SkyKind.fog => Icons.foggy,
  SkyKind.heat => Icons.local_fire_department_rounded,
};

IconData _previewIcon(SkyPreview p) => switch (p) {
  SkyPreview.rainbow => Icons.looks_rounded,
  SkyPreview.dusk => Icons.wb_twilight_rounded,
  SkyPreview.night => Icons.nightlight_round,
  _ => skyIcon(SkyKind.values.byName(p.name)),
};

/// 지도 위 지금 날씨 표시. 누르면 [showSkySheet].
class SkyChip extends StatelessWidget {
  const SkyChip({super.key, required this.now, required this.preview, required this.onPreview});

  final DateTime now;
  final SkyPreview? preview;
  final ValueChanged<SkyPreview> onPreview;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final kind = GameSky.kindAt(now);
    final rainbow = GameSky.rainbowAt(now);
    final (IconData icon, String text) = switch (preview) {
      final p? => (_previewIcon(p), '${l.skyPreviewing} · ${l.skyPreview(p.name)}'),
      null when rainbow => (Icons.looks_rounded, '${l.skyRainbow} · ${l.skyChipRainbow}'),
      null => (
        skyIcon(kind),
        switch (kind) {
          SkyKind.rain => '${l.skyKind(kind.name)} · ${l.skyChipRain}',
          SkyKind.heat => '${l.skyKind(kind.name)} · ${l.skyChipHeat}',
          _ => l.skyKind(kind.name),
        },
      ),
    };
    void open() => showSkySheet(context, onPreview: onPreview);
    // 아이콘·글자를 한 덩어리로 읽히게 하위 시맨틱스를 빼므로, 스크린리더 두 번 탭은 여기서 받는다.
    return Semantics(
      button: true,
      label: l.skyChipLabel(text),
      onTap: open,
      excludeSemantics: true,
      child: Pressable(
        onTap: open,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                text,
                style: AppText.caption.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 지금 날씨·효과·앞으로 12시간 날씨와 그림 미리 보기.
Future<void> showSkySheet(BuildContext context, {required ValueChanged<SkyPreview> onPreview}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        builder: (context, controller) => _SkyBody(controller: controller, onPreview: onPreview),
      ),
    );

class _SkyBody extends StatelessWidget {
  const _SkyBody({required this.controller, required this.onPreview});

  final ScrollController controller;
  final ValueChanged<SkyPreview> onPreview;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = GameScope.of(context).now;
    final kind = GameSky.kindAt(now);
    final next = GameSky.blockStart(now).add(const Duration(hours: GameSky.blockHours));
    final rainbowLeft = GameSky.rainbowMinutesLeft(now);
    final forecast = GameSky.forecast(now, 6);
    return ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + MediaQuery.viewPaddingOf(context).bottom),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 14),
        Text(l.skyTitle, style: AppText.title),
        const SizedBox(height: 12),
        AppCard(
          child: Row(
            children: [
              IconBubble(
                color: AppTints.slate,
                child: Icon(skyIcon(kind), color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.skyKind(kind.name), style: AppText.h2),
                    Text(l.skyEffect(kind.name), style: AppText.caption),
                    if (rainbowLeft > 0)
                      Text(l.skyRainbowEffect(rainbowLeft), style: AppText.caption.copyWith(color: AppColors.orange)),
                    Text(l.skyNextChange(l.skyHour(next.hour)), style: AppText.tiny),
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionTitle(l.skyForecastTitle),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Row(
            children: [
              for (final (start, k) in forecast)
                Expanded(
                  child: Column(
                    children: [
                      Text(l.skyHour(start.hour), style: AppText.tiny),
                      const SizedBox(height: 6),
                      Icon(skyIcon(k), color: k == SkyKind.rain ? AppColors.blue : AppColors.primary, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        l.skyKind(k.name),
                        style: AppText.tiny.copyWith(color: AppColors.text),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(l.skyRules, style: AppText.caption),
        SectionTitle(l.skyPreviewTitle, subtitle: l.skyPreviewHint),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in SkyPreview.values)
              ActionChip(
                avatar: Icon(_previewIcon(p), size: 18, color: AppColors.primary),
                label: Text(l.skyPreview(p.name)),
                onPressed: () {
                  Navigator.of(context).pop();
                  onPreview(p);
                },
              ),
          ],
        ),
      ],
    );
  }
}
