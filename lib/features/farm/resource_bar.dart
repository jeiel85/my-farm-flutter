import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../game/defs.dart';
import '../../game/game_store.dart';
import '../../l10n/l10n.dart';

/// 농장 위쪽 자원 바: 레벨·경험치, 코인, 창고, 사료, 물.
class ResourceBar extends StatelessWidget {
  const ResourceBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = GameScope.of(context).state;
    final level = s.level;
    final from = GameDefs.xpForLevel(level);
    final to = GameDefs.xpForLevel(level + 1);
    final progress = ((s.xp - from) / (to - from)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0F3A2E12), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                label: l.levelLabel(level),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Text(
                    '$level',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.levelProgress(s.xp - from, to - from), style: AppText.tiny),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: progress),
                        duration: const Duration(milliseconds: 500),
                        builder: (_, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 8,
                          color: AppColors.yellow,
                          backgroundColor: AppColors.line,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Chip(emoji: '🪙', value: '${s.coins}', label: l.coins),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Chip(
                  emoji: '📦',
                  value: '${s.barnUsed}/${s.barnCapacity}',
                  label: l.barn,
                  warn: s.barnFree == 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Chip(
                  emoji: '🌾',
                  value: '${s.feed.floor()}/${s.feedCapacity}',
                  label: l.feed,
                  warn: s.animals.isNotEmpty && s.feed < 10,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Chip(emoji: '💧', value: '${s.water}L', label: l.water),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.emoji, required this.value, required this.label, this.warn = false});

  final String emoji;
  final String value;
  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $value',
    excludeSemantics: true,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: warn ? AppTints.terracotta : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.h3.copyWith(fontSize: 14, color: warn ? AppColors.orange : AppColors.text),
            ),
          ),
        ],
      ),
    ),
  );
}
