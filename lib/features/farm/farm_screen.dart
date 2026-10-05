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
import '../../l10n/l10n.dart';

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
                        Text(context.l10n.myFarm, style: AppText.title),
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
                    label: context.l10n.allZones,
                    icon: Icons.grid_view_rounded,
                    active: _zone == null,
                    onTap: () => _select(null),
                  ),
                  for (final z in ZoneId.values)
                    _ZoneChip(
                      key: _chipKeys[z],
                      label: context.l10n.zone(z),
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
                SectionTitle(context.l10n.explore),
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
                          _zone == null
                              ? context.l10n.tapZoneToZoom
                              : context.l10n.tapAgainForAll(context.l10n.zone(_zone!)),
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
                  Text(context.l10n.tapZoneToExplore, style: AppText.h3),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.farmSummary(ZoneId.values.length, crops, store.totalAnimals),
                    style: AppText.caption,
                  ),
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
          (context.l10n.animalsLabel, context.l10n.animalCount(store.totalAnimals), null),
          (context.l10n.healthLabel, '${(store.herdHealth * 100).round()}%', null),
          (context.l10n.nextFeeding, store.nextFeeding?.timeLabel ?? context.l10n.doneToday, null),
        ],
        action: PrimaryButton(
          label: context.l10n.openLivestock,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LivestockScreen())),
        ),
      ),
      ZoneId.water => _InfoZoneCard(
        zone: z,
        stats: [
          (context.l10n.level, '${(store.tankRatio * 100).round()}%', store.tankRatio < 0.25 ? AppColors.red : null),
          (context.l10n.stored, '${_liters.format(store.state.tankStoredL)}L', null),
          (context.l10n.usedToday, '${_liters.format(store.waterUsedToday)}L', null),
        ],
        action: Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: context.l10n.refill,
                icon: Icons.water_drop_outlined,
                filled: false,
                onTap: store.tankRatio >= 1
                    ? null
                    : () async {
                        await FarmScope.read(context).refillTank();
                        if (context.mounted) showMessage(context, context.l10n.tankRefilled);
                      },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PrimaryButton(label: context.l10n.smartWatering, onTap: () => smartWateringWithFeedback(context)),
            ),
          ],
        ),
      ),
      ZoneId.storage => _InfoZoneCard(
        zone: z,
        stats: [
          (context.l10n.items, context.l10n.countItems(store.state.inventory.length), null),
          (
            context.l10n.shortLabel,
            context.l10n.countItems(store.lowInventory.length),
            store.lowInventory.isEmpty ? null : AppColors.orange,
          ),
          (
            context.l10n.feedLabel,
            store.feedDaysLeft == null ? '-' : context.l10n.daysOfStock(store.feedDaysLeft!.floor()),
            null,
          ),
        ],
        action: PrimaryButton(
          label: context.l10n.manageInventory,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventoryScreen())),
        ),
      ),
      _ => _InfoZoneCard(
        zone: z,
        stats: [
          (context.l10n.area, '${store.state.profile.areaHa}ha', null),
          (context.l10n.location, store.state.profile.locationLabel, null),
          (context.l10n.tasksLeft, context.l10n.countItems(store.tasksToday.where((t) => !t.done).length), null),
        ],
        action: PrimaryButton(label: context.l10n.viewTodayTasks, onTap: () => AppShell.goTo(context, AppTab.home)),
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
            Text(context.l10n.zone(zone), style: AppText.h3.copyWith(fontSize: 16)),
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
                    Text(context.l10n.zone(field.zone), style: AppText.h3.copyWith(fontSize: 16)),
                    Text(context.l10n.cropName(field.cropName), style: AppText.caption),
                  ],
                ),
              ),
              Tag(context.l10n.status(field.status), color: field.status.color, icon: Icons.favorite_border_rounded),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(context.l10n.growth, style: AppText.caption),
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
                child: StatBox(
                  label: context.l10n.statusLabel,
                  value: context.l10n.status(field.status),
                  valueColor: field.status.color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatBox(
                  label: context.l10n.nextWatering,
                  value: field.needsWater(now)
                      ? context.l10n.neededNow
                      : context.l10n.relative(field.nextWateringAt, now),
                  valueColor: field.needsWater(now) ? AppColors.blue : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatBox(
                  label: context.l10n.untilHarvest,
                  value: days == 0 ? context.l10n.harvestReady : context.l10n.daysValue(days),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: context.l10n.waterAction,
                  icon: Icons.water_drop_outlined,
                  filled: false,
                  onTap: () => waterFieldWithFeedback(context, field),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: context.l10n.viewCrop,
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
    final (wCondition, wIcon) = report == null ? (null, Icons.wb_sunny_outlined) : describeWeather(report.code);
    final wLabel = wCondition == null ? context.l10n.loading : context.l10n.weatherText(wCondition);
    final items = [
      (
        Icons.eco_outlined,
        context.l10n.myCrops,
        context.l10n.cropsGrowing(store.state.fields.length),
        AppColors.primarySoft,
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CropsScreen())),
      ),
      (
        Icons.pets_outlined,
        context.l10n.livestock,
        context.l10n.animalCount(store.totalAnimals),
        const Color(0xFFF7E6D9),
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LivestockScreen())),
      ),
      (
        Icons.water_drop_outlined,
        context.l10n.watering,
        next == null ? '-' : (next.isAfter(store.now) ? context.l10n.nextAt(hm(next)) : context.l10n.neededNow),
        const Color(0xFFDDEEFA),
        () => onSelectZone(ZoneId.water),
      ),
      (
        wIcon,
        context.l10n.weather,
        report == null
            ? (weather.error != null ? context.l10n.loadFailed : wLabel)
            : '$wLabel · ${report.temperatureC.round()}°C',
        const Color(0xFFFCF1D2),
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WeatherScreen())),
      ),
      (
        Icons.warehouse_outlined,
        context.l10n.inventory,
        store.lowInventory.isEmpty ? context.l10n.allStocked : context.l10n.lowCount(store.lowInventory.length),
        const Color(0xFFE9E6F5),
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventoryScreen())),
      ),
      (
        Icons.inventory_2_outlined,
        context.l10n.harvestRecords,
        context.l10n.recordsCount(store.state.harvests.length),
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
