import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../game/engine.dart';
import '../../game/game_store.dart';
import '../../game/orders.dart';
import '../../l10n/l10n.dart';
import 'game_actions.dart';

/// 마을 주문 게시판(창고 탭·농가 상세). 주문마다 필요한 물건(가진 수/필요 수)과 보상, 보내기·넘기기.
class OrdersCard extends StatelessWidget {
  const OrdersCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final store = GameScope.of(context);
    final s = store.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l.ordersTitle, subtitle: l.ordersHint),
        for (final (i, slot) in s.orders.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: switch (slot) {
              OrderSlot(order: final order?) => _OrderTile(index: i, order: order),
              OrderSlot(:final wait) => AppCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                color: AppColors.surfaceSoft,
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_bottom_rounded, color: AppColors.muted, size: 20),
                    const SizedBox(width: 10),
                    Text(l.orderWaiting(l.duration(remainingFor(wait, store))), style: AppText.caption),
                  ],
                ),
              ),
            },
          ),
      ],
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.index, required this.order});

  final int index;
  final Order order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    final ready = order.items.entries.every((e) => s.countOf(e.key) >= e.value);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              for (final e in order.items.entries)
                Text(
                  '${itemEmoji(e.key)} ${l.item(e.key)} ${s.countOf(e.key)}/${e.value}',
                  style: AppText.body.copyWith(
                    color: s.countOf(e.key) >= e.value ? AppColors.sage : AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text(l.orderReward(order.coins, order.xp), style: AppText.caption)),
              TextButton(
                onPressed: () => runGame(context, (st) => GameEngine.skipOrder(st, index), done: l.orderSkipped),
                child: Text(l.orderSkip),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: ready
                    ? () => runGame(
                        context,
                        (st) => GameEngine.deliverOrder(st, index),
                        done: l.orderDelivered(order.coins),
                      )
                    : null,
                child: Text(l.orderDeliver),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
