import 'package:flutter/material.dart';

import '../../core/animal_painter.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../game/defs.dart';
import '../../game/engine.dart';
import '../../game/game_store.dart';
import '../../game/lots.dart';
import '../../game/state.dart';
import '../../l10n/l10n.dart';
import 'building_look.dart';
import 'farm_world.dart';
import 'game_actions.dart';
import 'orders_card.dart';

/// 칸 상세를 띄운 곳(휴대폰 시트, 넓은 화면 오른쪽 패널). 수확·심기를 마치면 [close]로 닫는다.
class ZoneHost extends InheritedWidget {
  const ZoneHost({super.key, required this.close, required super.child});

  final VoidCallback close;

  static void closeOf(BuildContext context) => context.getInheritedWidgetOfExactType<ZoneHost>()?.close();

  @override
  bool updateShouldNotify(ZoneHost oldWidget) => false;
}

/// 휴대폰에서 칸을 눌렀을 때 아래에서 올라오는 시트. 상태가 바뀌면 바로 다시 그린다.
///
/// 지도는 고른 칸으로 다가가 시트 위쪽에 보이므로, 배경을 어둡게 하지 않고 처음 높이를 낮게 둔다.
Future<void> showLotSheet(BuildContext context, LotId lot) {
  final pen = GameScope.read(context).state.lots[lot]?.def.species != null;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    barrierColor: Colors.transparent,
    elevation: 8,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheetContext) => ZoneHost(
      close: () => Navigator.of(sheetContext).maybePop(),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: pen ? 0.5 : 0.42,
        minChildSize: 0.25,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
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
            LotDetail(lot: lot),
          ],
        ),
      ),
    ),
  );
}

/// 넓은 화면에서 지도 옆(오른쪽 열)에 띄우는 칸 상세. 지도를 가리지 않는다.
class LotPanel extends StatelessWidget {
  const LotPanel({super.key, required this.lot, required this.onClose});

  final LotId lot;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => ZoneHost(
    close: onClose,
    child: Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
      decoration: BoxDecoration(color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(24)),
      child: LotDetail(lot: lot, onClose: onClose),
    ),
  );
}

/// 칸 이름과 칸 상태별 내용: 넓히기 전 땅 · 빈 땅(짓기) · 건물(밭·우리·농가·창고와 철거).
class LotDetail extends StatelessWidget {
  const LotDetail({super.key, required this.lot, this.onClose});

  final LotId lot;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    final built = s.lots[lot];
    final (IconData icon, String title, Widget body) = switch (built) {
      final b? => (
        BuildingLook.icon(b.building),
        l.building(b.building),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            switch (b.building) {
              BuildingId.farmhouse => const _HouseBody(),
              BuildingId.storehouse => const _StorageBody(),
              BuildingId.field || BuildingId.greenhouse || BuildingId.orchard => _FieldBody(lot: lot),
              BuildingId.coop || BuildingId.goatPen || BuildingId.sheepPen || BuildingId.cowBarn => _PenBody(lot: lot),
              BuildingId.mill ||
              BuildingId.jamKitchen ||
              BuildingId.dairy ||
              BuildingId.bakery => _WorkshopBody(lot: lot),
              BuildingId.pond || BuildingId.scarecrow || BuildingId.flowerBed => AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.buildingDesc(b.building), style: AppText.body),
                    const SizedBox(height: 6),
                    Text(l.decorHint, style: AppText.caption),
                  ],
                ),
              ),
            },
            if (b.def.upgradeCosts.isNotEmpty) _UpgradeSection(lot: lot),
            if (!b.def.core) _DemolishSection(lot: lot),
          ],
        ),
      ),
      null when s.owned.contains(lot) => (Icons.add_rounded, l.emptyLot, _BuildPicker(lot: lot)),
      null => (Icons.landscape_outlined, l.wild(wildKindOf(lot)), _WildBody(lot: lot)),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: AppText.h2)),
            if (onClose != null)
              IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded), tooltip: l.close),
          ],
        ),
        const SizedBox(height: 12),
        body,
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 18,
          color: ok ? AppColors.sage : AppColors.muted,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppText.body)),
      ],
    ),
  );
}

// ---------------------------------------------------------------- 넓히기 전 땅

class _WildBody extends StatelessWidget {
  const _WildBody({required this.lot});

  final LotId lot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    final cost = s.nextExpansionCost;
    final touches = s.touchesOwned(lot);
    final levelOk = s.expansionsLeft > 0;
    final coinsOk = cost != null && s.coins >= cost;
    final nextLevel = s.expansions ~/ 2 + 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.expandHint, style: AppText.body),
              const SizedBox(height: 12),
              _Requirement(ok: touches, text: l.expandNeedsNeighbor),
              _Requirement(
                ok: levelOk,
                text: levelOk
                    ? l.expandProgress(s.expansions, GameDefs.expansionsAllowed(s.level))
                    : l.expandLimit(nextLevel),
              ),
              if (cost != null) _Requirement(ok: coinsOk, text: l.needCoins(cost)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (cost != null)
          PrimaryButton(
            label: l.expandFor(cost),
            icon: Icons.landscape_rounded,
            onTap: touches && levelOk && coinsOk
                ? () => runGame(context, (st) => GameEngine.clearLand(st, lot), done: l.expanded)
                : null,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 빈 땅: 짓기

class _BuildPicker extends StatelessWidget {
  const _BuildPicker({required this.lot});

  final LotId lot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    final options = GameDefs.buildings.values.where((b) => !b.core).toList()
      ..sort(
        (a, b) => a.unlockLevel != b.unlockLevel ? a.unlockLevel.compareTo(b.unlockLevel) : a.cost.compareTo(b.cost),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.buildTitle, style: AppText.caption),
        const SizedBox(height: 10),
        for (final def in options) ...[
          Opacity(
            opacity: s.level < def.unlockLevel ? 0.5 : 1,
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Text(BuildingLook.emoji(def.id), style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.building(def.id), style: AppText.h3),
                        Text(l.buildingDesc(def.id), style: AppText.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  s.level < def.unlockLevel
                      ? Tag(l.levelShort(def.unlockLevel), color: AppColors.muted, icon: Icons.lock_outline_rounded)
                      : FilledButton(
                          onPressed: s.coins >= def.cost
                              ? () => runGame(
                                  context,
                                  (st) => GameEngine.build(st, lot, def.id),
                                  done: l.built(l.building(def.id)),
                                )
                              : null,
                          child: Text('🪙 ${def.cost}'),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- 업그레이드

/// 레벨 [level]의 [building]이 가진 효과(문구). docs/farm-lots-design.md §4.
List<String> buildingEffects(AppLocalizations l, BuildingId building, int level) {
  final def = GameDefs.buildings[building]!;
  final auto = level >= GameDefs.autoLevel;
  if (def.species case final species?) {
    return [l.effectCapacity(def.capacity[level - 1]), if (auto) '${l.effectAutoCollect} (${l.collectVerb(species)})'];
  }
  if (def.recipe != null) {
    return [if (level >= 2) l.effectFaster, if (auto) l.effectAutoCraft];
  }
  return switch (building) {
    BuildingId.farmhouse => [
      l.effectFarmhouse(
        GameDefs.offlineCapByLevel[level - 1] ~/ 60,
        GameDefs.waterCapacityByLevel[level - 1],
        GameDefs.waterRefillByLevel[level - 1],
      ),
    ],
    BuildingId.storehouse => [
      l.effectStorehouse(GameDefs.barnCapacityByLevel[level - 1], GameDefs.feedCapacityByLevel[level - 1]),
      if (auto) l.effectAutoShip,
    ],
    BuildingId.orchard => [if (level >= 2) l.effectYield(GameDefs.yieldBonusLv2), if (auto) l.effectAutoHarvest],
    _ => [if (level >= 2) l.effectYield(GameDefs.yieldBonusLv2), if (auto) l.effectAutoReplant],
  };
}

class _UpgradeSection extends StatelessWidget {
  const _UpgradeSection({required this.lot});

  final LotId lot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    final b = s.lots[lot]!;
    final def = b.def;
    final now = buildingEffects(l, b.building, b.level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l.upgradeTitle, subtitle: l.upgradeNow(b.level)),
        for (final e in now) Text('· $e', style: AppText.caption),
        if (b.level >= def.maxLevel)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l.maxLevelReached, style: AppText.caption),
          )
        else ...[
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lv${b.level + 1}', style: AppText.h3),
                for (final e in buildingEffects(l, b.building, b.level + 1))
                  if (!now.contains(e)) Text('+ $e', style: AppText.body),
              ],
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: l.upgradeTo(def.upgradeCosts[b.level - 1], b.level + 1),
            icon: Icons.upgrade_rounded,
            onTap: s.coins >= def.upgradeCosts[b.level - 1]
                ? () => runGame(
                    context,
                    (st) => GameEngine.upgrade(st, lot),
                    done: l.upgraded(l.building(b.building), b.level + 1),
                  )
                : null,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- 철거

class _DemolishSection extends StatelessWidget {
  const _DemolishSection({required this.lot});

  final LotId lot;

  Future<void> _confirm(BuildContext context, BuildingId building) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.demolishTitle(l.building(building))),
        content: Text(l.demolishBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.demolish(GameDefs.demolishRefund(building))),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await runGame(context, (st) => GameEngine.demolish(st, lot), done: l.demolished);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    final b = s.lots[lot]!;
    final busy = (b.field != null && !b.field!.empty) || s.animals.any((a) => a.home == lot);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: busy ? null : () => _confirm(context, b.building),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(l.demolish(GameDefs.demolishRefund(b.building))),
          ),
          if (busy) Text(l.demolishHint, style: AppText.tiny),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 밭·온실·과수원

class _FieldBody extends StatelessWidget {
  const _FieldBody({required this.lot});

  final LotId lot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final store = GameScope.of(context);
    final s = store.state;
    final f = s.lots[lot]?.field ?? FieldState.emptyField;
    final crop = f.crop;
    if (crop == null) return _CropPicker(lot: lot);
    final def = GameDefs.crops[crop]!;
    final bonus = s.yieldBonus(lot);
    final count = GameEngine.yieldFor(def, bonus, store.now);
    final base = GameEngine.baseYield(def, bonus);
    final total = Duration(minutes: f.totalMinutes);
    final left = remainingFor(f.minutesLeft, store);
    final progress = f.ready || total.inSeconds == 0 ? 1.0 : (1 - left.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Row(
            children: [
              Text(cropEmoji(crop), style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.crop(crop), style: AppText.h2),
                    const SizedBox(height: 4),
                    Text(
                      f.ready
                          ? l.cropReady
                          : f.waitingWater
                          ? l.cropWaitingWater(def.waterL)
                          : l.cropRemaining(l.duration(left)),
                      style: AppText.caption,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        color: f.ready ? AppColors.sage : AppColors.yellow,
                        backgroundColor: AppColors.line,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(l.cropYield(count, l.crop(crop), GameDefs.itemPrice[def.item]! * count), style: AppText.caption),
        if (count > base) Text(l.rainbowYieldHint(count - base), style: AppText.caption),
        if (s.touches(lot, BuildingId.scarecrow))
          Text(l.scarecrowYieldHint(GameDefs.scarecrowBonus), style: AppText.caption),
        if (def.perennial)
          Text(l.perennialHint(l.duration(Duration(minutes: def.regrowMinutes!))), style: AppText.caption),
        const SizedBox(height: 14),
        PrimaryButton(
          label: l.harvest,
          icon: Icons.agriculture_rounded,
          onTap: f.ready
              ? () async {
                  final ok = await runGame(
                    context,
                    (st) => GameEngine.harvest(st, lot),
                    done: l.harvested(l.crop(crop)),
                  );
                  if (ok && !def.perennial && context.mounted) ZoneHost.closeOf(context);
                }
              : null,
        ),
      ],
    );
  }
}

class _CropPicker extends StatelessWidget {
  const _CropPicker({required this.lot});

  final LotId lot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.pickCrop, style: AppText.caption),
        const SizedBox(height: 10),
        for (final def in GameEngine.cropsFor(s, lot)) ...[
          _CropOption(def: def, level: s.level, coins: s.coins, water: s.water, lot: lot),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CropOption extends StatelessWidget {
  const _CropOption({
    required this.def,
    required this.level,
    required this.coins,
    required this.water,
    required this.lot,
  });

  final CropDef def;
  final int level;
  final int coins;
  final int water;
  final LotId lot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locked = level < def.unlockLevel;
    final price = GameDefs.itemPrice[def.item]!;
    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Text(cropEmoji(def.id), style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.crop(def.id), style: AppText.h3),
                  Text(
                    l.cropSummary(l.duration(Duration(minutes: def.growMinutes)), def.waterL, def.yieldCount * price),
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            locked
                ? Tag(l.levelShort(def.unlockLevel), color: AppColors.muted, icon: Icons.lock_outline_rounded)
                : FilledButton(
                    onPressed: coins >= def.seedCost && water >= def.waterL
                        ? () async {
                            final ok = await runGame(
                              context,
                              (st) => GameEngine.plant(st, lot, def.id),
                              done: l.planted(l.crop(def.id)),
                            );
                            if (ok && context.mounted) ZoneHost.closeOf(context);
                          }
                        : null,
                    child: Text('🪙 ${def.seedCost}'),
                  ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 공방

class _WorkshopBody extends StatelessWidget {
  const _WorkshopBody({required this.lot});

  final LotId lot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final store = GameScope.of(context);
    final s = store.state;
    final b = s.lots[lot]!;
    final recipe = b.def.recipe!;
    final job = b.job;
    final haveAll = recipe.inputs.entries.every((e) => s.countOf(e.key) >= e.value);
    final minutes = GameDefs.craftMinutes(recipe, b.level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Row(
            children: [
              Text(itemEmoji(recipe.output), style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.item(recipe.output), style: AppText.h2),
                    Text(
                      '${l.craftRecipe}: ${l.recipeInputs(recipe)} · 🪙${GameDefs.itemPrice[recipe.output]}',
                      style: AppText.caption,
                    ),
                    if (job != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        job.done ? l.craftReady : l.craftWorking(l.duration(remainingFor(job.minutesLeft, store))),
                        style: AppText.caption,
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: job.done ? 1 : 1 - job.minutesLeft / job.totalMinutes,
                          minHeight: 10,
                          color: job.done ? AppColors.sage : AppColors.yellow,
                          backgroundColor: AppColors.line,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final e in recipe.inputs.entries)
          _Requirement(
            ok: s.countOf(e.key) >= e.value,
            text: l.craftInput('${itemEmoji(e.key)} ${l.item(e.key)}', s.countOf(e.key), e.value),
          ),
        const SizedBox(height: 12),
        if (job?.done ?? false)
          PrimaryButton(
            label: l.craftCollect,
            icon: Icons.outbox_rounded,
            onTap: () =>
                runGame(context, (st) => GameEngine.collectCraft(st, lot), done: l.crafted(l.item(recipe.output))),
          )
        else
          PrimaryButton(
            label: l.craftStart(l.duration(Duration(minutes: minutes))),
            icon: Icons.play_arrow_rounded,
            onTap: job == null && haveAll
                ? () => runGame(
                    context,
                    (st) => GameEngine.startCraft(st, lot),
                    done: l.craftStarted(l.item(recipe.output)),
                  )
                : null,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 가축 우리

class _PenBody extends StatelessWidget {
  const _PenBody({required this.lot});

  final LotId lot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatBox(label: l.penSpace, value: '${s.animalsIn(lot).length}/${s.penCapacity(lot)}'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatBox(label: l.feed, value: '${s.feed.floor()}/${s.feedCapacity}'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () => runGame(context, GameEngine.buyFeed, done: l.feedBought(GameDefs.feedPackAmount)),
              child: Text(l.buyFeedShort(GameDefs.feedPackCost)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(l.feedHint, style: AppText.tiny),
        if (l.feedLastsText(s) case final lasts?) Text(lasts, style: AppText.tiny),
        _SpeciesSection(lot: lot),
      ],
    );
  }
}

class _SpeciesSection extends StatelessWidget {
  const _SpeciesSection({required this.lot});

  final LotId lot;

  Future<void> _sell(BuildContext context, GameAnimal a) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.sellAnimalTitle(l.species(a.species))),
        content: Text(l.sellAnimalBody(a.def.sellPrice)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.sellAnimal)),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await runGame(context, (st) => GameEngine.slaughter(st, a.id), done: l.animalSold(a.def.sellPrice));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final store = GameScope.of(context);
    final s = store.state;
    final species = s.lots[lot]!.def.species!;
    final def = GameDefs.animals[species]!;
    final mine = s.animalsIn(lot);
    final locked = s.level < def.unlockLevel;
    final stored = mine.fold(0, (n, a) => n + a.stored);
    final adults = mine.where((a) => a.adult).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          l.species(species),
          subtitle: locked
              ? l.unlocksAt(def.unlockLevel)
              : l.speciesSummary(
                  mine.length,
                  l.item(def.product),
                  l.duration(Duration(minutes: s.produceEvery(lot, def))),
                ),
          trailing: locked
              ? null
              : FilledButton.tonal(
                  onPressed: s.coins >= def.buyCost && mine.length < s.penCapacity(lot)
                      ? () => runGame(
                          context,
                          (st) => GameEngine.buyAnimal(st, lot),
                          done: l.animalBought(l.young(species)),
                        )
                      : null,
                  child: Text(l.buyYoung(l.young(species), def.buyCost)),
                ),
        ),
        if (!locked && mine.isEmpty) Text(l.noAnimalsYet, style: AppText.caption),
        if (stored > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PrimaryButton(
              label: '${l.collectVerb(species)} · ${itemEmoji(def.product)} $stored',
              icon: null,
              onTap: () => collectFrom(context, lot, species),
            ),
          ),
        if (s.touches(lot, BuildingId.flowerBed)) Text(l.flowerBedHint, style: AppText.tiny),
        if (adults >= 2)
          Text(l.breedingHint(l.duration(Duration(minutes: def.breedEveryMinutes))), style: AppText.tiny),
        for (final a in mine)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                children: [
                  AnimalAvatar(kind: species, size: a.adult ? 44 : 32, variant: int.tryParse(a.id.substring(1)) ?? 0),
                  const SizedBox(width: 10),
                  Expanded(
                    child: a.adult
                        ? Text(l.adultStatus(itemEmoji(def.product), a.stored, def.storeCap), style: AppText.body)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.youngStatus(
                                  l.young(species),
                                  l.duration(remainingFor(def.growMinutes - a.ageMinutes, store)),
                                ),
                                style: AppText.body,
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: a.ageMinutes / def.growMinutes,
                                minHeight: 6,
                                color: AppColors.sage,
                                backgroundColor: AppColors.line,
                              ),
                            ],
                          ),
                  ),
                  if (a.adult)
                    TextButton(onPressed: () => _sell(context, a), child: Text(l.sellAnimalShort(def.sellPrice))),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 농가(집·우물)·창고

class _HouseBody extends StatelessWidget {
  const _HouseBody();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    final missing = s.waterCapacity - s.water;
    final next = <(int, String)>[
      for (final c in GameDefs.crops.values)
        if (c.unlockLevel > s.level) (c.unlockLevel, '${cropEmoji(c.id)} ${l.crop(c.id)}'),
      for (final a in GameDefs.animals.values)
        if (a.unlockLevel > s.level) (a.unlockLevel, l.species(a.species)),
      for (final b in GameDefs.buildings.values)
        if (b.unlockLevel > s.level) (b.unlockLevel, '${BuildingLook.emoji(b.id)} ${l.building(b.id)}'),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: StatBox(label: l.levelWord, value: '${s.level}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatBox(label: l.xpWord, value: '${s.xp} / ${GameDefs.xpForLevel(s.level + 1)}'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💧 ${s.water} / ${s.waterCapacity}L', style: AppText.h3),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: s.water / s.waterCapacity,
                  minHeight: 8,
                  color: AppColors.blue,
                  backgroundColor: AppColors.line,
                ),
              ),
              const SizedBox(height: 8),
              Text(l.tankHint(s.waterRefillPerMinute), style: AppText.caption),
              if (missing > 0)
                Text(
                  l.tankFullIn(l.duration(Duration(minutes: (missing / s.waterRefillPerMinute).ceil()))),
                  style: AppText.caption,
                ),
            ],
          ),
        ),
        const OrdersCard(),
        SectionTitle(l.nextUnlocks),
        if (next.isEmpty) Text(l.allUnlocked, style: AppText.caption),
        for (final (level, name) in next.take(8))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Tag(l.levelShort(level), color: AppColors.primary),
                const SizedBox(width: 10),
                Text(name, style: AppText.body),
              ],
            ),
          ),
      ],
    );
  }
}

class _StorageBody extends StatelessWidget {
  const _StorageBody();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('📦 ${s.barnUsed} / ${s.barnCapacity}', style: AppText.h2),
        const SizedBox(height: 8),
        // 시트는 탭 화면 밖(루트 내비게이터)에 떠 있어 여기서 탭을 바꿀 수 없다. 농장 화면은 창고를 누르면 바로 창고 탭으로 간다.
        Text(l.barnTabHint, style: AppText.caption),
      ],
    );
  }
}
