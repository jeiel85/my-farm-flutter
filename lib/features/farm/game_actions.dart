import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets.dart';
import '../../game/defs.dart';
import '../../game/engine.dart';
import '../../game/game_store.dart';
import '../../game/lots.dart';
import '../../game/state.dart';
import '../../l10n/l10n.dart';

/// 게임 행동을 실행하고 결과를 짧게 알린다. 할 수 없으면 이유를 알리고 false.
Future<bool> runGame(BuildContext context, GameState Function(GameState s) action, {String? done}) async {
  try {
    await GameScope.read(context).act(action);
    HapticFeedback.lightImpact();
    if (done != null && context.mounted) showMessage(context, done);
    return true;
  } on GameException catch (e) {
    if (context.mounted) showMessage(context, context.l10n.gameError(e.error));
    return false;
  }
}

/// 우리 [pen]의 쌓인 생산물을 거둔다.
Future<void> collectFrom(BuildContext context, LotId pen, Species species) async {
  final l = context.l10n;
  try {
    final took = await GameScope.read(context).actWith((s) => GameEngine.collect(s, pen));
    HapticFeedback.lightImpact();
    if (context.mounted) {
      showMessage(context, l.collected(l.item(GameDefs.animals[species]!.product), took));
    }
  } on GameException catch (e) {
    if (context.mounted) showMessage(context, l.gameError(e.error));
  }
}

/// 마지막 계산 뒤 흐른 시간까지 반영한 남은 시간.
Duration remainingFor(int minutesLeft, GameStore store) {
  final elapsed = store.now.difference(store.state.simTime);
  return Duration(minutes: minutesLeft) - elapsed;
}
