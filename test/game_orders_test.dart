import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/game/defs.dart';
import 'package:my_farm/game/engine.dart';
import 'package:my_farm/game/orders.dart';
import 'package:my_farm/game/state.dart';

/// L4 마을 주문 게시판. docs/farm-lots-design.md §10.
void main() {
  final t0 = DateTime(2026, 10, 6, 9, 0);
  GameState fresh() => GameEngine.newGame(t0, farmName: 'x');
  Matcher fails(GameError e) => throwsA(isA<GameException>().having((x) => x.error, 'error', e));
  GameState run(GameState s, int minutes) =>
      GameEngine.advance(s, s.simTime.add(Duration(minutes: minutes)), capMinutes: 100000).$1;

  test('새 게임은 주문 3건으로 시작하고, 1레벨 주문은 상추·달걀로만 이루어진다', () {
    final s = fresh();
    expect(s.orders, hasLength(3));
    expect(s.orderSeq, 3);
    for (final slot in s.orders) {
      expect(slot.order!.items.keys, everyElement(isIn(const [ItemId.lettuce, ItemId.egg])));
    }
  });

  test('주문은 순번·레벨로 정해지고(같으면 같다), 수량 1~12, 보상은 판매가 합의 1.5배를 5단위로 올린 값이다', () {
    for (var seq = 0; seq < 200; seq++) {
      for (final level in const [1, 3, 6, 9]) {
        final o = OrderBook.make(seq, level);
        expect(jsonEncode(o.toJson()), jsonEncode(OrderBook.make(seq, level).toJson()));
        expect(o.items.keys, everyElement(isIn(OrderBook.poolFor(level))));
        expect(o.items.length, inInclusiveRange(1, 3));
        expect(o.items.values, everyElement(inInclusiveRange(1, 12)));
        final value = [for (final e in o.items.entries) GameDefs.itemPrice[e.key]! * e.value].fold(0, (a, b) => a + b);
        expect(o.coins % 5, 0);
        expect(o.coins, inInclusiveRange(value * 3 ~/ 2, value * 3 ~/ 2 + 5));
      }
    }
    expect(OrderBook.poolFor(9), contains(ItemId.bread));
    expect(OrderBook.poolFor(1), isNot(contains(ItemId.bread)));
  });

  test('보내면 물건을 꺼내고 코인·경험치를 받으며, 5분 뒤 새 주문이 온다', () {
    var s = fresh();
    final order = s.orders.first.order!;
    expect(() => GameEngine.deliverOrder(s, 0), fails(GameError.notEnoughItems));
    s = s.copyWith(barn: {for (final e in order.items.entries) e.key: e.value + 1});
    final sent = GameEngine.deliverOrder(s, 0);
    expect(sent.coins, s.coins + order.coins);
    expect(sent.xp, s.xp + order.xp);
    expect(sent.barn.values, everyElement(1));
    expect(sent.log.last.kind, LogKind.order);
    expect(sent.orders.first.order, isNull);
    expect(() => GameEngine.deliverOrder(sent, 0), fails(GameError.noOrder));
    expect(run(sent, 4).orders.first.order, isNull);
    final refilled = run(sent, 5);
    expect(refilled.orders.first.order!.id, 3);
    expect(refilled.orderSeq, 4);
  });

  test('넘기면 15분 뒤 새 주문이 온다', () {
    final skipped = GameEngine.skipOrder(fresh(), 1);
    expect(skipped.orders[1].order, isNull);
    expect(run(skipped, 14).orders[1].order, isNull);
    expect(run(skipped, 15).orders[1].order, isNotNull);
    expect(() => GameEngine.skipOrder(skipped, 1), fails(GameError.noOrder));
  });

  test('5레벨이 되면 게시판이 4칸이 된다', () {
    final s = fresh().copyWith(xp: GameDefs.xpForLevel(5));
    final after = run(s, 1);
    expect(after.orders, hasLength(4));
    expect(after.orders.last.order, isNotNull);
  });

  test('주문 칸이 없던 v6 저장본(L1~L3 개발판)은 비어 있다가 시간이 흐르면 찬다', () {
    final json = fresh().toJson()
      ..remove('orders')
      ..remove('orderSeq');
    final old = GameState.fromJson((jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>());
    expect(old.orders, isEmpty);
    expect(run(old, 1).orders, hasLength(3));
  });

  test('주문이 오가도 나눠 진행한 결과와 한 번에 진행한 결과가 같다', () {
    var s = fresh().copyWith(xp: GameDefs.xpForLevel(4));
    s = GameEngine.skipOrder(GameEngine.skipOrder(s, 0), 2);
    final end = s.simTime.add(const Duration(minutes: 40));
    final whole = GameEngine.advance(s, end).$1;
    var split = s;
    for (final m in const [1, 6, 9, 13, 11]) {
      split = GameEngine.advance(split, split.simTime.add(Duration(minutes: m))).$1;
    }
    expect(jsonEncode(split.toJson()), jsonEncode(whole.toJson()));
  });
}
