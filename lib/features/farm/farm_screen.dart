import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_shell.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';
import '../../data/weather.dart';
import '../crops/crop_actions.dart';
import '../crops/crop_detail_screen.dart';
import '../crops/crops_screen.dart';
import '../inventory/inventory_screen.dart';
import '../livestock/livestock_screen.dart';
import '../weather/weather_screen.dart';
import 'farm_map_view.dart';

final _liters = NumberFormat('#,###');

class FarmScreen extends StatefulWidget {
  const FarmScreen({super.key});

  @override
  State<FarmScreen> createState() => _FarmScreenState();
}

class _FarmScreenState extends State<FarmScreen> {
  ZoneId? _zone;
  final _chipKeys = {for (final z in ZoneId.values) z: GlobalKey()};
  final _overviewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = FarmScope.read(context).state.profile;
      WeatherScope.read(context).ensureLoaded(p.latitude, p.longitude);
    });
  }

  void _select(ZoneId? zone) {
    setState(() => _zone = zone == _zone ? null : zone);
    final key = _zone == null ? _overviewKey : _chipKeys[_zone]!;
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final profile = store.state.profile;
    final needsWater = {for (final f in store.fieldsNeedingWater) f.zone};
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
        children: [
          rise(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('내 농장', style: AppText.title),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 13, color: AppColors.muted),
                            const SizedBox(width: 2),
                            Text('${profile.name} · ${profile.areaHa}ha', style: AppText.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Pressable(
                    onTap: () => Navigator.of(context).push(_fullMapRoute(_zone)),
                    child: const IconBubble(
                      color: AppColors.surface,
                      size: 42,
                      child: Icon(Icons.map_outlined, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            0,
          ),
          const SizedBox(height: 14),
          rise(
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _ZoneChip(
                    key: _overviewKey,
                    label: '전체',
                    icon: Icons.grid_view_rounded,
                    active: _zone == null,
                    onTap: () => _select(null),
                  ),
                  for (final z in ZoneId.values)
                    _ZoneChip(
                      key: _chipKeys[z],
                      label: z.label,
                      icon: z.icon,
                      active: _zone == z,
                      onTap: () => _select(z),
                    ),
                ],
              ),
            ),
            1,
          ),
          const SizedBox(height: 14),
          rise(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: AspectRatio(
                  aspectRatio: 0.86,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FarmMapView(
                          selected: _zone,
                          onZoneTap: _select,
                          tankRatio: store.tankRatio,
                          needsWater: needsWater,
                          aspect: 0.86,
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Pressable(
                          onTap: () => Navigator.of(context).push(_fullMapRoute(_zone)),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.open_in_full_rounded, size: 17),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            2,
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                layoutBuilder: (current, previous) =>
                    Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                child: KeyedSubtree(
                  key: ValueKey(_zone),
                  child: _ZoneCard(zone: _zone),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('둘러보기'),
                _ExploreGrid(onSelectZone: _select),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Route<void> _fullMapRoute(ZoneId? zone) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 420),
  reverseTransitionDuration: const Duration(milliseconds: 320),
  pageBuilder: (_, _, _) => _FullMapPage(initial: zone),
  transitionsBuilder: (_, anim, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
    child: ScaleTransition(
      scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  ),
);

class _FullMapPage extends StatefulWidget {
  const _FullMapPage({required this.initial});

  final ZoneId? initial;

  @override
  State<_FullMapPage> createState() => _FullMapPageState();
}

class _FullMapPageState extends State<_FullMapPage> {
  late ZoneId? _zone = widget.initial;

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFF94C46A),
      body: Stack(
        children: [
          Positioned.fill(
            child: FarmMapView(
              selected: _zone,
              onZoneTap: (z) => setState(() => _zone = z == _zone ? null : z),
              tankRatio: store.tankRatio,
              needsWater: {for (final f in store.fieldsNeedingWater) f.zone},
              aspect: size.width / size.height,
            ),
          ),
          // 상단 바를 Positioned로 둬야 Stack이 화면 전체 크기를 유지한다.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Pressable(
                      onTap: () => Navigator.of(context).pop(),
                      child: const IconBubble(color: Colors.white, size: 42, child: Icon(Icons.close_rounded)),
                    ),
                    const SizedBox(width: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        key: ValueKey(_zone),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          _zone == null ? '구역을 누르면 확대됩니다' : '${_zone!.label} · 다시 누르면 전체 보기',
                          style: AppText.h3.copyWith(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  const _ZoneChip({super.key, required this.label, required this.icon, required this.active, required this.onTap});

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: active ? Colors.white : AppColors.text),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 지도 아래 선택 구역 정보 카드.
class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zone});

  final ZoneId? zone;

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final z = zone;
    if (z == null) {
      final crops = store.state.fields.length;
      return AppCard(
        color: AppColors.primarySoft,
        child: Row(
          children: [
            const Icon(Icons.touch_app_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('구역을 눌러 둘러보세요', style: AppText.h3),
                  const SizedBox(height: 2),
                  Text('${ZoneId.values.length}개 구역 · 작물 $crops종 · 가축 ${store.totalAnimals}마리', style: AppText.caption),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final field = store.fieldFor(z);
    if (field != null) return _CropZoneCard(field: field);
    return switch (z) {
      ZoneId.animals => _InfoZoneCard(
        zone: z,
        stats: [
          ('동물', '${store.totalAnimals}마리', null),
          ('건강', '${(store.herdHealth * 100).round()}%', null),
          ('다음 급이', store.nextFeeding?.timeLabel ?? '오늘 완료', null),
        ],
        action: PrimaryButton(
          label: '가축 관리 열기',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LivestockScreen())),
        ),
      ),
      ZoneId.water => _InfoZoneCard(
        zone: z,
        stats: [
          ('수위', '${(store.tankRatio * 100).round()}%', store.tankRatio < 0.25 ? AppColors.red : null),
          ('저장량', '${_liters.format(store.state.tankStoredL)}L', null),
          ('오늘 사용', '${_liters.format(store.waterUsedToday)}L', null),
        ],
        action: Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: '물 보충',
                icon: Icons.water_drop_outlined,
                filled: false,
                onTap: store.tankRatio >= 1
                    ? null
                    : () async {
                        await FarmScope.read(context).refillTank();
                        if (context.mounted) showMessage(context, '물탱크를 가득 채웠습니다.');
                      },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PrimaryButton(label: '스마트 관수', onTap: () => smartWateringWithFeedback(context)),
            ),
          ],
        ),
      ),
      ZoneId.storage => _InfoZoneCard(
        zone: z,
        stats: [
          ('품목', '${store.state.inventory.length}개', null),
          ('부족', '${store.lowInventory.length}개', store.lowInventory.isEmpty ? null : AppColors.orange),
          ('사료', store.feedDaysLeft == null ? '-' : '${store.feedDaysLeft!.floor()}일분', null),
        ],
        action: PrimaryButton(
          label: '재고 관리',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventoryScreen())),
        ),
      ),
      _ => _InfoZoneCard(
        zone: z,
        stats: [
          ('면적', '${store.state.profile.areaHa}ha', null),
          ('위치', store.state.profile.locationLabel, null),
          ('남은 일', '${store.tasksToday.where((t) => !t.done).length}개', null),
        ],
        action: PrimaryButton(label: '오늘 할 일 보기', onTap: () => AppShell.goTo(context, AppTab.home)),
      ),
    };
  }
}

class _InfoZoneCard extends StatelessWidget {
  const _InfoZoneCard({required this.zone, required this.stats, required this.action});

  final ZoneId zone;
  final List<(String, String, Color?)> stats;
  final Widget action;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconBubble(
              color: AppColors.surfaceSoft,
              child: Icon(zone.icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Text(zone.label, style: AppText.h3.copyWith(fontSize: 16)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: StatBox(label: stats[i].$1, value: stats[i].$2, valueColor: stats[i].$3),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        action,
      ],
    ),
  );
}

class _CropZoneCard extends StatelessWidget {
  const _CropZoneCard({required this.field});

  final CropField field;

  @override
  Widget build(BuildContext context) {
    final now = FarmScope.of(context).now;
    final growth = field.growthAt(now);
    final days = field.daysToHarvest(now);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(
                color: AppColors.surfaceSoft,
                child: Text(field.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(field.zone.label, style: AppText.h3.copyWith(fontSize: 16)),
                    Text('작물: ${field.cropName}', style: AppText.caption),
                  ],
                ),
              ),
              Tag(field.status.label, color: field.status.color, icon: Icons.favorite_border_rounded),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('생육', style: AppText.caption),
              const Spacer(),
              Text('${(growth * 100).round()}%', style: AppText.h3),
            ],
          ),
          const SizedBox(height: 8),
          SegmentBar(value: growth),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatBox(label: '상태', value: field.status.label, valueColor: field.status.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatBox(
                  label: '다음 물주기',
                  value: field.needsWater(now) ? '지금 필요' : relativeTime(field.nextWateringAt, now),
                  valueColor: field.needsWater(now) ? AppColors.blue : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatBox(label: '수확까지', value: days == 0 ? '수확 가능' : '$days일'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: '물 주기',
                  icon: Icons.water_drop_outlined,
                  filled: false,
                  onTap: () => waterFieldWithFeedback(context, field),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: '작물 보기',
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => CropDetailScreen(fieldId: field.id))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExploreGrid extends StatelessWidget {
  const _ExploreGrid({required this.onSelectZone});

  final ValueChanged<ZoneId?> onSelectZone;

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final weather = WeatherScope.of(context);
    final next = store.nextWatering;
    final report = weather.report;
    final (wLabel, wIcon) = report == null ? ('불러오는 중', Icons.wb_sunny_outlined) : describeWeather(report.code);
    final items = [
      (
        Icons.eco_outlined,
        '내 작물',
        '${store.state.fields.length}종 재배 중',
        AppColors.primarySoft,
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CropsScreen())),
      ),
      (
        Icons.pets_outlined,
        '가축',
        '${store.totalAnimals}마리',
        const Color(0xFFF7E6D9),
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LivestockScreen())),
      ),
      (
        Icons.water_drop_outlined,
        '물주기',
        next == null ? '-' : (next.isAfter(store.now) ? '다음 ${hm(next)}' : '지금 필요'),
        const Color(0xFFDDEEFA),
        () => onSelectZone(ZoneId.water),
      ),
      (
        wIcon,
        '날씨',
        report == null ? (weather.error != null ? '불러오기 실패' : wLabel) : '$wLabel · ${report.temperatureC.round()}°C',
        const Color(0xFFFCF1D2),
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WeatherScreen())),
      ),
      (
        Icons.warehouse_outlined,
        '재고',
        store.lowInventory.isEmpty ? '모두 충분' : '부족 ${store.lowInventory.length}개',
        const Color(0xFFE9E6F5),
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventoryScreen())),
      ),
      (
        Icons.inventory_2_outlined,
        '수확 기록',
        '${store.state.harvests.length}건',
        const Color(0xFFFBE3E1),
        () => AppShell.goTo(context, AppTab.harvest),
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        for (var i = 0; i < items.length; i++)
          rise(
            Pressable(
              onTap: items[i].$5,
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    IconBubble(
                      color: items[i].$4,
                      size: 38,
                      child: Icon(items[i].$1, size: 19, color: AppColors.text),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[i].$2, style: AppText.h3.copyWith(fontSize: 13)),
                          Text(items[i].$3, style: AppText.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            i + 3,
          ),
      ],
    );
  }
}
