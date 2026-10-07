import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
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
  SkyPreview.spring => Icons.local_florist_rounded,
  SkyPreview.summer => Icons.park_rounded,
  SkyPreview.autumn => Icons.eco_rounded,
  SkyPreview.winter => Icons.ac_unit_rounded,
  _ => skyIcon(SkyKind.values.byName(p.name)),
};

/// 지도 위 지금 날씨 표시. 누르면 지도판이 눕고 하늘이 열린다([SkyCard]).
class SkyChip extends StatelessWidget {
  const SkyChip({super.key, required this.now, required this.preview, required this.onTap});

  final DateTime now;
  final SkyPreview? preview;
  final VoidCallback onTap;

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
    // 아이콘·글자를 한 덩어리로 읽히게 하위 시맨틱스를 빼므로, 스크린리더 두 번 탭은 여기서 받는다.
    return Semantics(
      button: true,
      label: l.skyChipLabel(text),
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
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

/// 하늘이 열린 동안 지도 옆(휴대폰은 지도 바로 아래)에 뜨는 날씨 카드: 지금 날씨·효과, 앞으로 12시간, 그림 미리 보기.
/// 눕힌 지도를 가리지 않도록 시트 대신 지도 밖에 둔다.
class SkyCard extends StatelessWidget {
  const SkyCard({super.key, required this.now, required this.preview, required this.onPreview, required this.onClose});

  final DateTime now;
  final SkyPreview? preview;
  final ValueChanged<SkyPreview> onPreview;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final kind = GameSky.kindAt(now);
    final next = GameSky.blockStart(now).add(const Duration(hours: GameSky.blockHours));
    final rainbowLeft = GameSky.rainbowMinutesLeft(now);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(skyIcon(kind), color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${l.skyTitle} · ${l.skyKind(kind.name)}', style: AppText.h3),
                    Text(
                      rainbowLeft > 0 ? l.skyRainbowEffect(rainbowLeft) : l.skyEffect(kind.name),
                      style: AppText.caption.copyWith(color: rainbowLeft > 0 ? AppColors.orange : null),
                    ),
                    Text(l.skyNextChange(l.skyHour(next.hour)), style: AppText.tiny),
                  ],
                ),
              ),
              Tooltip(
                message: l.skyRules,
                triggerMode: TooltipTriggerMode.tap,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.info_outline_rounded, size: 20, color: AppColors.muted),
                ),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded), tooltip: l.close),
            ],
          ),
          const SizedBox(height: 6),
          Text(l.skyForecastTitle, style: AppText.tiny),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final (start, k) in GameSky.forecast(now, 6))
                Expanded(
                  child: Column(
                    children: [
                      Text(l.skyHour(start.hour), style: AppText.tiny),
                      Icon(skyIcon(k), color: k == SkyKind.rain ? AppColors.blue : AppColors.primary, size: 18),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Center(child: Text(l.skyPreviewTitle, style: AppText.tiny)),
                ),
                for (final p in SkyPreview.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(_previewIcon(p), size: 16, color: AppColors.primary),
                      label: Text(l.skyPreview(p.name)),
                      selected: preview == p,
                      onSelected: (_) => onPreview(p),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
