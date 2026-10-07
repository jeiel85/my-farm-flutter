import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_shell.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/app_update.dart';
import '../../game/defs.dart';
import '../../game/engine.dart';
import '../../game/game_store.dart';
import '../../game/sky.dart';
import '../../game/todo.dart';
import '../../game/zone.dart';
import '../../l10n/l10n.dart';
import '../update/update_widgets.dart';
import 'farm_map_view.dart';
import 'farm_world.dart';
import 'game_actions.dart';
import 'resource_bar.dart';
import 'sky_layer.dart';
import 'sky_sheet.dart';
import 'zone_sheets.dart';

class FarmScreen extends StatefulWidget {
  const FarmScreen({super.key});

  @override
  State<FarmScreen> createState() => _FarmScreenState();
}

class _FarmScreenState extends State<FarmScreen> {
  ZoneId? _zone;

  /// 하늘 보기(지도판을 눕혀 하늘을 연 상태). 날씨 표시를 누르면 켜지고, 지도나 카드의 닫기를 누르면 꺼진다.
  bool _sky = false;
  SkyPreview? _preview;
  Timer? _previewTimer;

  /// 날씨 그림을 잠깐 미리 보여 주고 지금 날씨로 돌아온다.
  void _showPreview(SkyPreview p) {
    _previewTimer?.cancel();
    setState(() => _preview = p);
    _previewTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _preview = null);
    });
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  /// 구역을 연다. 넓은 화면은 지도 옆(오른쪽 열)에, 휴대폰은 아래 시트로 띄운다(지도를 가리지 않게).
  Future<void> _open(ZoneId zone) async {
    if (zone == ZoneId.storage) {
      AppShell.goTo(context, AppTab.barn);
      return;
    }
    // 하늘 보기 중이면 지도판을 눕힌 채로 다가간다.
    setState(() => _zone = zone);
    if (isWide(context)) return;
    await showZoneSheet(context, zone);
    if (mounted) setState(() => _zone = null);
  }

  void _closeZone() => setState(() => _zone = null);

  @override
  Widget build(BuildContext context) {
    final store = GameScope.of(context);
    final s = store.state;
    final todos = todosFor(s);
    final wide = isWide(context);
    final now = store.now;
    final map = ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: AspectRatio(
        aspectRatio: wide ? 0.9 : 0.86,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FarmMapView(
              scene: FarmScene.of(s, context.l10n),
              sky: _preview == null ? SkyView.at(now) : SkyView.preview(_preview!, now),
              selected: _zone,
              onZoneTap: _open,
              skyMode: _sky,
              // 한 단계 돌아가기: 다가간 구역에서 전체 하늘 보기로, 전체에서 평면으로.
              onSkyTap: () => setState(() => _zone == null ? _sky = false : _zone = null),
              // 휴대폰 시트는 화면 아래 40% 남짓을 덮으므로, 고른 구역을 지도 위쪽으로 올린다.
              focusBias: wide ? 0 : 0.18,
              aspect: wide ? 0.9 : 0.86,
            ),
            if (!_sky)
              Positioned(
                top: 10,
                right: 10,
                child: SkyChip(
                  now: now,
                  preview: _preview,
                  onTap: () => setState(() {
                    _zone = null;
                    _sky = true;
                  }),
                ),
              ),
          ],
        ),
      ),
    );
    // 날씨 카드는 눕힌 지도(서 있는 구조물·동물)를 가리지 않게 지도 밖에 둔다: 휴대폰은 지도 바로 아래, 넓은 화면은
    // 오른쪽 열 맨 위.
    final skyCard = SkyCard(
      now: now,
      preview: _preview,
      onPreview: _showPreview,
      onClose: () => setState(() => _sky = false),
    );
    final update = UpdateScope.of(context);
    final todoList = [
      if (update?.offer case final offer?) ...[
        const SizedBox(height: 12),
        Pressable(
          onTap: () => showUpdateSheet(context, update!, offer),
          child: AppCard(
            color: AppColors.primarySoft,
            child: Row(
              children: [
                const Icon(Icons.system_update_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.updateAvailableTitle(offer.versionName), style: AppText.h3),
                      Text(context.l10n.updateAvailableSubtitle, style: AppText.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      SectionTitle(context.l10n.todoTitle, subtitle: todos.isEmpty ? null : context.l10n.todoCount(todos.length)),
      if (todos.isEmpty)
        AppCard(
          color: AppColors.primarySoft,
          child: Row(
            children: [
              const Icon(Icons.local_cafe_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(context.l10n.todoNothing, style: AppText.body)),
            ],
          ),
        )
      else
        for (final (i, t) in todos.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: rise(_TodoTile(todo: t, onOpenZone: _open), i.clamp(0, 8)),
          ),
    ];
    return SafeArea(
      bottom: false,
      child: SplitList(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        primary: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(s.farmName, style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const ResourceBar(),
          const SizedBox(height: 12),
          map,
          if (_sky && !wide) Padding(padding: const EdgeInsets.only(top: 10), child: skyCard),
          if (!wide) ...todoList,
        ],
        secondary: [
          if (wide) ...[
            if (_sky) Padding(padding: const EdgeInsets.only(top: 8), child: skyCard),
            if (_zone case final zone?) ZonePanel(key: ValueKey(zone), zone: zone, onClose: _closeZone),
            ...todoList,
          ],
        ],
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({required this.todo, required this.onOpenZone});

  final GameTodo todo;
  final ValueChanged<ZoneId> onOpenZone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    final (
      IconData icon,
      Color color,
      String title,
      String? subtitle,
      String action,
      Future<void> Function() run,
    ) = switch (todo.kind) {
      TodoKind.harvest => () {
        final crop = s.fields[todo.zone]!.crop!;
        return (
          Icons.agriculture_rounded,
          AppColors.sage,
          l.todoHarvest(l.crop(crop), l.zone(todo.zone!)),
          l.todoHarvestHint(GameSky.yieldAt(GameDefs.crops[crop]!, GameScope.of(context).now)),
          l.harvest,
          () => runGame(context, (st) => GameEngine.harvest(st, todo.zone!), done: l.harvested(l.crop(crop))),
        );
      }(),
      TodoKind.collect => (
        Icons.egg_alt_outlined,
        AppColors.yellow,
        l.todoCollect(l.species(todo.species!), todo.count),
        null,
        l.collectVerb(todo.species!),
        () => collectFrom(context, todo.species!),
      ),
      TodoKind.barnFull => (
        Icons.inventory_2_outlined,
        AppColors.orange,
        l.todoBarnFull,
        l.todoBarnFullHint,
        l.openBarn,
        () async => AppShell.goTo(context, AppTab.barn),
      ),
      TodoKind.feedEmpty => (
        Icons.warning_amber_rounded,
        AppColors.red,
        l.todoFeedEmpty,
        l.todoFeedHint,
        l.buyFeed,
        () => runGame(context, GameEngine.buyFeed, done: l.feedBought(GameDefs.feedPackAmount)),
      ),
      TodoKind.feedLow => (
        Icons.grass_rounded,
        AppColors.orange,
        l.todoFeedLow(s.feed.floor()),
        l.todoFeedHint,
        l.buyFeed,
        () => runGame(context, GameEngine.buyFeed, done: l.feedBought(GameDefs.feedPackAmount)),
      ),
      TodoKind.plant => (
        Icons.spa_outlined,
        AppColors.primary,
        l.todoPlant(l.zone(todo.zone!)),
        null,
        l.plant,
        () async => onOpenZone(todo.zone!),
      ),
      TodoKind.unlock => (
        Icons.lock_open_rounded,
        AppColors.primary,
        l.todoUnlock(l.zone(todo.zone!)),
        l.unlockCost(GameDefs.zones[todo.zone]!.unlockCost),
        l.unlock,
        () async => onOpenZone(todo.zone!),
      ),
    };
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          IconBubble(
            color: color.withValues(alpha: 0.14),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.h3),
                if (subtitle != null) Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(onPressed: run, child: Text(action)),
        ],
      ),
    );
  }
}
