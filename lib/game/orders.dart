/// 마을 주문 게시판(L4). docs/farm-lots-design.md §10.
///
/// 주문 내용은 순번([GameState.orderSeq])과 그때 레벨로 정해지는 의사 난수라, 나눠 진행해도 같은 주문이 같은 분에 온다.
library;

import 'defs.dart';

/// 주문 한 건: 물건들을 보내면 코인과 경험치를 받는다.
class Order {
  const Order({required this.id, required this.items, required this.coins, required this.xp});

  final int id;
  final Map<ItemId, int> items;
  final int coins;
  final int xp;

  Map<String, Object?> toJson() => {
    'id': id,
    'items': {for (final e in items.entries) e.key.name: e.value},
    'coins': coins,
    'xp': xp,
  };

  factory Order.fromJson(Map<String, Object?> j) => Order(
    id: j['id'] as int,
    items: {
      for (final e in (j['items'] as Map).cast<String, Object?>().entries)
        ItemId.values.asNameMap()[e.key] ?? (throw FormatException('Unknown item', e.key)): e.value as int,
    },
    coins: j['coins'] as int,
    xp: j['xp'] as int,
  );
}

/// 게시판 한 칸: 주문이 있거나, 새 주문을 [wait]분 기다린다.
class OrderSlot {
  const OrderSlot.order(Order this.order) : wait = 0;
  const OrderSlot.waiting(this.wait) : order = null;

  final Order? order;
  final int wait;

  Map<String, Object?> toJson() => order != null ? {'order': order!.toJson()} : {'wait': wait};

  factory OrderSlot.fromJson(Map<String, Object?> j) => j['order'] != null
      ? OrderSlot.order(Order.fromJson((j['order'] as Map).cast<String, Object?>()))
      : OrderSlot.waiting(j['wait'] as int);
}

abstract final class OrderBook {
  /// 보내고 나서, 넘기고 나서 새 주문이 오기까지(분).
  static const refillAfterDelivery = 5;
  static const refillAfterSkip = 15;

  /// 레벨별 게시판 칸 수.
  static int slotsFor(int level) => level >= 5 ? 4 : 3;

  /// 지금 레벨에서 주문에 나올 수 있는 물건(해금된 작물·생산물·가공품).
  static List<ItemId> poolFor(int level) => [
    for (final c in GameDefs.crops.values)
      if (c.unlockLevel <= level) c.item,
    for (final a in GameDefs.animals.values)
      if (a.unlockLevel <= level) a.product,
    for (final b in GameDefs.buildings.values)
      if (b.recipe != null && b.unlockLevel <= level) b.recipe!.output,
  ];

  /// [seq]번째 주문(레벨 [level] 기준). 1~3가지 물건, 값은 판매가 합의 1.5배(5단위 올림).
  static Order make(int seq, int level) {
    var x = (seq * 7919 + 104729) % 2147483647;
    int next(int n) {
      x = x * 48271 % 2147483647;
      return x % n;
    }

    final pool = poolFor(level);
    final kinds = 1 + next(pool.length < 3 ? pool.length : 3);
    final picked = <ItemId>[];
    while (picked.length < kinds) {
      final item = pool[next(pool.length)];
      if (!picked.contains(item)) picked.add(item);
    }
    final items = <ItemId, int>{};
    var value = 0;
    for (final item in picked) {
      final price = GameDefs.itemPrice[item]!;
      final target = 18 + level * 10 + next(16);
      final qty = (target ~/ price).clamp(1, 12);
      items[item] = qty;
      value += price * qty;
    }
    final coins = ((value * 3 ~/ 2) + 4) ~/ 5 * 5;
    return Order(id: seq, items: items, coins: coins, xp: 1 + value ~/ 25);
  }
}
