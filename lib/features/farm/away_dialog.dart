import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../game/defs.dart';
import '../../game/engine.dart';
import '../../l10n/l10n.dart';

/// 다시 열었을 때 자리 비운 동안 일어난 일을 알려 준다.
Future<void> showAwayDialog(BuildContext context, AdvanceReport r) {
  final l = context.l10n;
  final lines = <(String, String)>[
    if (r.cropsReady.isNotEmpty) ('🌱', l.awayCropsReady(r.cropsReady.length)),
    for (final e in r.produced.entries)
      (itemEmoji(GameDefs.animals[e.key]!.product), l.awayProduced(l.item(GameDefs.animals[e.key]!.product), e.value)),
    for (final e in r.born.entries) ('🐣', l.awayBorn(l.young(e.key), e.value)),
    if (r.feedRanOut) ('⚠️', l.awayFeedRanOut),
  ];
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.awayTitle(l.duration(Duration(minutes: r.minutes + r.skippedMinutes)))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (emoji, text) in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: AppText.body)),
                ],
              ),
            ),
          if (r.skippedMinutes > 0) ...[
            const SizedBox(height: 8),
            Text(l.awayCapped(l.duration(Duration(minutes: GameDefs.offlineCapMinutes))), style: AppText.caption),
          ],
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.ok))],
    ),
  );
}
