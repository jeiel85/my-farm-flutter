import 'package:flutter/material.dart';

import '../../core/animal_painter.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../game/defs.dart';
import '../../game/engine.dart';
import '../../game/game_store.dart';
import '../../game/sky.dart';
import '../../game/state.dart';
import '../../game/zone.dart';
import '../../l10n/l10n.dart';
import 'game_actions.dart';

/// 구역 상세를 띄운 곳(휴대폰 시트, 넓은 화면 오른쪽 패널). 수확·심기를 마치면 [close]로 닫는다.
class ZoneHost extends InheritedWidget {
  const ZoneHost({super.key, required this.close, required super.child});

  final VoidCallback close;

  static void closeOf(BuildContext context) => context.getInheritedWidgetOfExactType<ZoneHost>()?.close();

  @override
  bool updateShouldNotify(ZoneHost oldWidget) => false;
}

/// 휴대폰에서 구역을 눌렀을 때 아래에서 올라오는 시트. 상태가 바뀌면 바로 다시 그린다.
///
/// 지도는 고른 구역으로 다가가 시트 위쪽에 보이므로, 배경을 어둡게 하지 않고 처음 높이를 낮게 둔다.
Future<void> showZoneSheet(BuildContext context, ZoneId zone) => showModalBottomSheet<void>(
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
      initialChildSize: zone == ZoneId.animals ? 0.5 : 0.42,
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
          ZoneDetail(zone: zone),
        ],
      ),
    ),
  ),
);

/// 넓은 화면에서 지도 옆(오른쪽 열)에 띄우는 구역 상세. 지도를 가리지 않는다.
class ZonePanel extends StatelessWidget {
  const ZonePanel({super.key, required this.zone, required this.onClose});

  final ZoneId zone;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => ZoneHost(
    close: onClose,
    child: Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
      decoration: BoxDecoration(color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(24)),
      child: ZoneDetail(zone: zone, onClose: onClose),
    ),
  );
}

/// 구역 이름과 구역별 내용(잠김·밭·가축 우리·물탱크·집·창고).
class ZoneDetail extends StatelessWidget {
  const ZoneDetail({super.key, required this.zone, this.onClose});

  final ZoneId zone;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context).state;
    final locked = GameDefs.zones.containsKey(zone) && !s.unlocked.contains(zone);
    final Widget body = switch (zone) {
      _ when locked => _LockedBody(zone: zone),
      ZoneId.animals => const _PenBody(),
      ZoneId.water => const _TankBody(),
      ZoneId.house => const _HouseBody(),
      ZoneId.storage => const _StorageBody(),
      _ => _FieldBody(zone: zone),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(zone.icon, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(context.l10n.zone(zone), style: AppText.h2)),
            if (onClose != null)
              IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded), tooltip: context.l10n.close),
          ],
        ),
        const SizedBox(height: 12),
        body,
      ],
    );
  }
}

// ---------------------------------------------------------------- 잠긴 구역

class _LockedBody extends StatelessWidget {
  const _LockedBody({required this.zone});

  final ZoneId zone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    final def = GameDefs.zones[zone]!;
    final levelOk = s.level >= def.unlockLevel;
    final coinsOk = s.coins >= def.unlockCost;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.lockedZoneHint, style: AppText.body),
              const SizedBox(height: 12),
              _Requirement(ok: levelOk, text: l.needLevel(def.unlockLevel)),
              _Requirement(ok: coinsOk, text: l.needCoins(def.unlockCost)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: l.unlockFor(def.unlockCost),
          icon: Icons.lock_open_rounded,
          onTap: levelOk && coinsOk
              ? () => runGame(context, (st) => GameEngine.unlockZone(st, zone), done: l.unlocked(l.zone(zone)))
              : null,
        ),
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
        Text(text, style: AppText.body),
      ],
    ),
  );
}

// ---------------------------------------------------------------- 밭

class _FieldBody extends StatelessWidget {
  const _FieldBody({required this.zone});

  final ZoneId zone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final store = GameScope.of(context);
    final s = store.state;
    final f = s.fields[zone] ?? FieldState.emptyField;
    final crop = f.crop;
    if (crop == null) return _CropPicker(zone: zone);
    final def = GameDefs.crops[crop]!;
    final count = GameSky.yieldAt(def, store.now);
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
        if (count > def.yieldCount) Text(l.rainbowYieldHint(count - def.yieldCount), style: AppText.caption),
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
                    (st) => GameEngine.harvest(st, zone),
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
  const _CropPicker({required this.zone});

  final ZoneId zone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.pickCrop, style: AppText.caption),
        const SizedBox(height: 10),
        for (final def in GameEngine.cropsFor(zone)) ...[
          _CropOption(def: def, level: s.level, coins: s.coins, water: s.water, zone: zone),
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
    required this.zone,
  });

  final CropDef def;
  final int level;
  final int coins;
  final int water;
  final ZoneId zone;

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
                              (st) => GameEngine.plant(st, zone, def.id),
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

// ---------------------------------------------------------------- 가축 우리

class _PenBody extends StatelessWidget {
  const _PenBody();

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
              child: StatBox(label: l.penSpace, value: '${s.animals.length}/${GameDefs.penCapacity}'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatBox(label: l.feed, value: '${s.feed.floor()}/${GameDefs.feedCapacity}'),
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
        for (final species in Species.values) _SpeciesSection(species: species),
      ],
    );
  }
}

class _SpeciesSection extends StatelessWidget {
  const _SpeciesSection({required this.species});

  final Species species;

  Future<void> _sell(BuildContext context, GameAnimal a) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.sellAnimalTitle(l.species(species))),
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
    final def = GameDefs.animals[species]!;
    final mine = s.animals.where((a) => a.species == species).toList();
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
                  l.duration(Duration(minutes: def.produceEveryMinutes)),
                ),
          trailing: locked
              ? null
              : FilledButton.tonal(
                  onPressed: s.coins >= def.buyCost && s.animals.length < GameDefs.penCapacity
                      ? () => runGame(
                          context,
                          (st) => GameEngine.buyAnimal(st, species),
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
              onTap: () => collectFrom(context, species),
            ),
          ),
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

// ---------------------------------------------------------------- 물탱크·농가

class _TankBody extends StatelessWidget {
  const _TankBody();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    final missing = GameDefs.waterCapacity - s.water;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💧 ${s.water} / ${GameDefs.waterCapacity}L', style: AppText.h2),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: s.water / GameDefs.waterCapacity,
              minHeight: 10,
              color: AppColors.blue,
              backgroundColor: AppColors.line,
            ),
          ),
          const SizedBox(height: 10),
          Text(l.tankHint(GameDefs.waterRefillPerMinute), style: AppText.caption),
          if (missing > 0)
            Text(
              l.tankFullIn(l.duration(Duration(minutes: (missing / GameDefs.waterRefillPerMinute).ceil()))),
              style: AppText.caption,
            ),
        ],
      ),
    );
  }
}

class _HouseBody extends StatelessWidget {
  const _HouseBody();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    final next = <(int, String)>[
      for (final c in GameDefs.crops.values)
        if (c.unlockLevel > s.level) (c.unlockLevel, '${cropEmoji(c.id)} ${l.crop(c.id)}'),
      for (final a in GameDefs.animals.values)
        if (a.unlockLevel > s.level) (a.unlockLevel, l.species(a.species)),
      for (final z in GameDefs.zones.values)
        if (z.unlockLevel > s.level) (z.unlockLevel, l.zone(z.zone)),
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
        Text('📦 ${s.barnUsed} / ${GameDefs.barnCapacity}', style: AppText.h2),
        const SizedBox(height: 8),
        // 시트는 탭 화면 밖(루트 내비게이터)에 떠 있어 여기서 탭을 바꿀 수 없다. 농장 화면은 창고를 누르면 바로 창고 탭으로 간다.
        Text(l.barnTabHint, style: AppText.caption),
      ],
    );
  }
}
