import 'package:flutter/material.dart';

import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../game/defs.dart';
import '../../game/engine.dart';
import '../../game/game_store.dart';
import '../../game/state.dart';
import '../../l10n/l10n.dart';
import '../farm/game_actions.dart';
import '../farm/orders_card.dart';

/// 창고·시장: 물건을 팔고 사료를 마련한다.
class BarnScreen extends StatelessWidget {
  const BarnScreen({super.key});

  Future<void> _sellAll(BuildContext context) async {
    final l = context.l10n;
    final s = GameScope.read(context).state;
    final total = [for (final e in s.barn.entries) GameDefs.itemPrice[e.key]! * e.value].fold(0, (a, b) => a + b);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.sellAllTitle),
        content: Text(l.sellAllBody(s.barnUsed, total)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.sellAll)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runGame(context, (st) {
      var next = st;
      for (final e in st.barn.entries.toList()) {
        next = GameEngine.sell(next, e.key, e.value);
      }
      return next;
    }, done: l.soldFor(total));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    final items = [
      for (final i in ItemId.values)
        if (s.countOf(i) > 0) i,
    ];
    final corn = s.countOf(ItemId.corn);
    return SafeArea(
      bottom: false,
      child: SplitList(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        primary: [
          Text(l.barnTitle, style: AppText.title),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l.barnCapacity(s.barnUsed, s.barnCapacity), style: AppText.h3)),
                    Text('🪙 ${s.coins}', style: AppText.h3),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: s.barnUsed / s.barnCapacity,
                    minHeight: 10,
                    color: s.barnFree == 0 ? AppColors.orange : AppColors.primary,
                    backgroundColor: AppColors.line,
                  ),
                ),
              ],
            ),
          ),
          SectionTitle(l.feedTitle),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('🌾 ${s.feed.floor()} / ${s.feedCapacity}', style: AppText.h2),
                const SizedBox(height: 4),
                Text(l.feedHint, style: AppText.caption),
                if (l.feedLastsText(s) case final lasts?) Text(lasts, style: AppText.caption),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: l.buyFeedFor(GameDefs.feedPackAmount, GameDefs.feedPackCost),
                  icon: Icons.add_shopping_cart_rounded,
                  onTap: () => runGame(context, GameEngine.buyFeed, done: l.feedBought(GameDefs.feedPackAmount)),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: l.cornToFeed(corn, corn * GameDefs.feedPerCorn),
                  icon: Icons.autorenew_rounded,
                  filled: false,
                  onTap: corn > 0
                      ? () => runGame(
                          context,
                          (st) => GameEngine.cornToFeed(st, _cornThatFits(st)),
                          done: l.cornConverted,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
        secondary: [
          const OrdersCard(),
          SectionTitle(
            l.marketTitle,
            trailing: items.isEmpty ? null : TextButton(onPressed: () => _sellAll(context), child: Text(l.sellAll)),
          ),
          if (items.isEmpty)
            AppCard(child: Text(l.barnEmpty, style: AppText.caption))
          else
            for (final (i, item) in items.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: rise(_ItemTile(item: item, count: s.countOf(item)), i.clamp(0, 8)),
              ),
        ],
      ),
    );
  }

  /// 사료통에 들어가는 만큼만 바꾼다(넘치면 거부되므로).
  static int _cornThatFits(GameState s) {
    final room = (s.feedCapacity * GameDefs.feedUnit - s.feedUnits) ~/ (GameDefs.feedPerCorn * GameDefs.feedUnit);
    final corn = s.countOf(ItemId.corn);
    if (room <= 0) throw const GameException(GameError.siloFull);
    return corn < room ? corn : room;
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.count});

  final ItemId item;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final price = GameDefs.itemPrice[item]!;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Text(itemEmoji(item), style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.itemCount(l.item(item), count), style: AppText.h3),
                Text(l.unitPrice(price), style: AppText.caption),
              ],
            ),
          ),
          TextButton(
            onPressed: () => runGame(context, (st) => GameEngine.sell(st, item, 1), done: l.soldFor(price)),
            child: Text(l.sellOne),
          ),
          FilledButton.tonal(
            onPressed: () => runGame(context, (st) => GameEngine.sell(st, item, count), done: l.soldFor(price * count)),
            child: Text('🪙 ${price * count}'),
          ),
        ],
      ),
    );
  }
}
