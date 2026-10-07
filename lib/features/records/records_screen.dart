import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../game/defs.dart';
import '../../game/game_store.dart';
import '../../game/state.dart';
import '../../l10n/l10n.dart';

/// 기간 안 (수입, 지출) 합계. 지출은 양수로 돌려준다.
(int, int) totalsBetween(List<GameLogEntry> log, DateTime from, DateTime to) {
  var income = 0;
  var expense = 0;
  for (final e in log) {
    if (e.at.isBefore(from) || !e.at.isBefore(to)) continue;
    if (e.amount >= 0) {
      income += e.amount;
    } else {
      expense -= e.amount;
    }
  }
  return (income, expense);
}

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final store = GameScope.of(context);
    final s = store.state;
    final now = store.now;
    final today = DateTime(now.year, now.month, now.day);
    final (income, expense) = totalsBetween(s.log, today, today.add(const Duration(days: 1)));
    final days = [
      for (var i = 6; i >= 0; i--)
        () {
          final d = today.subtract(Duration(days: i));
          return (d, totalsBetween(s.log, d, d.add(const Duration(days: 1))));
        }(),
    ];
    final maxY = days.fold(10, (m, d) => [m, d.$2.$1, d.$2.$2].reduce((a, b) => a > b ? a : b)).toDouble();
    final recent = s.log.reversed.take(30).toList();
    return SafeArea(
      bottom: false,
      child: SplitList(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        primary: [
          Text(l.recordsTitle, style: AppText.title),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatBox(label: l.todayIncome, value: '🪙 $income', valueColor: AppColors.sage),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatBox(label: l.todayExpense, value: '🪙 $expense', valueColor: AppColors.orange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatBox(label: l.todayNet, value: '🪙 ${income - expense}'),
              ),
            ],
          ),
          SectionTitle(l.last7Days),
          AppCard(
            child: SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxY * 1.15,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(DateFormat.E(context.localeName).format(days[v.toInt()].$1), style: AppText.tiny),
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (final (i, (_, (inc, exp))) in days.indexed)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 3,
                        barRods: [
                          BarChartRodData(toY: inc.toDouble(), color: AppColors.sage, width: 9),
                          BarChartRodData(toY: exp.toDouble(), color: AppColors.orange, width: 9),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Legend(color: AppColors.sage, text: l.income),
              const SizedBox(width: 12),
              _Legend(color: AppColors.orange, text: l.expense),
            ],
          ),
        ],
        secondary: [
          SectionTitle(l.recentRecords),
          if (recent.isEmpty) AppCard(child: Text(l.noRecords, style: AppText.caption)),
          for (final e in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    Expanded(child: Text(_describe(l, e), style: AppText.body)),
                    Text(
                      '${e.amount >= 0 ? '+' : ''}${e.amount}',
                      style: AppText.h3.copyWith(color: e.amount >= 0 ? AppColors.sage : AppColors.orange),
                    ),
                    const SizedBox(width: 10),
                    Text(l.relative(e.at, now), style: AppText.tiny),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _describe(AppLocalizations l, GameLogEntry e) {
    String? item() => ItemId.values.asNameMap()[e.subject]?.let(l.item);
    String? crop() => CropId.values.asNameMap()[e.subject]?.let(l.crop);
    String? species() => Species.values.asNameMap()[e.subject]?.let(l.species);
    String? building() => BuildingId.values.asNameMap()[e.subject]?.let(l.building);
    return switch (e.kind) {
      LogKind.sale => l.logSale(item() ?? e.subject),
      LogKind.slaughter => l.logSlaughter(species() ?? e.subject),
      LogKind.seed => l.logSeed(crop() ?? e.subject),
      LogKind.animal => l.logAnimal(species() ?? e.subject),
      LogKind.feed => l.logFeed,
      LogKind.unlock => l.logUnlock,
      LogKind.build => l.logBuild(building() ?? e.subject),
      LogKind.expand => l.logExpand,
      LogKind.demolish => l.logDemolish(building() ?? e.subject),
    };
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 5),
      Text(text, style: AppText.tiny),
    ],
  );
}
