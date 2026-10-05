import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../l10n/l10n.dart';
import '../ledger/ledger_screen.dart';

final _num = NumberFormat('#,##0.#');

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final now = store.now;
    final production = store.productionSeries(_days);
    final water = store.waterSeries(_days);
    final recorded = production.where((p) => p.$2 != null).map((p) => p.$2!).toList();
    final avgEggs = recorded.isEmpty ? null : recorded.fold(0, (s, p) => s + p.eggs) / recorded.length;
    final avgMilk = recorded.isEmpty ? null : recorded.fold(0.0, (s, p) => s + p.milkL) / recorded.length;
    final from = DateTime(now.year, now.month, now.day).subtract(Duration(days: _days - 1));
    final harvestKg = store.harvestSince(from);
    final waterTotal = water.fold(0.0, (s, w) => s + w.$2);
    final totals = store.harvestTotals();
    final profile = store.state.profile;
    final money = moneyFormat(context, profile.currency);
    final (income, expense) = store.ledgerTotals(from, DateTime(now.year, now.month, now.day + 1));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          rise(Text(context.l10n.analyticsTitle, style: AppText.title), 0),
          SizedBox(height: 14),
          rise(
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 7, label: Text(context.l10n.periodDays(7))),
                ButtonSegment(value: 14, label: Text(context.l10n.periodDays(14))),
                ButtonSegment(value: 30, label: Text(context.l10n.periodDays(30))),
              ],
              selected: {_days},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _days = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primary,
                selectedForegroundColor: Colors.white,
                backgroundColor: AppColors.surface,
                side: BorderSide.none,
              ),
            ),
            1,
          ),
          const SizedBox(height: 14),
          rise(
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                _Summary(
                  icon: Icons.inventory_2_rounded,
                  color: AppColors.primary,
                  label: context.l10n.harvestAmount,
                  value: '${_num.format(harvestKg)}kg',
                ),
                _Summary(
                  icon: Icons.water_drop_rounded,
                  color: AppColors.blue,
                  label: context.l10n.waterUse,
                  value: '${_num.format(waterTotal)}L',
                ),
                _Summary(
                  icon: Icons.egg_rounded,
                  color: AppColors.orange,
                  label: context.l10n.avgDailyEggs,
                  value: avgEggs == null ? context.l10n.noRecords : context.l10n.eggsValue(avgEggs.toStringAsFixed(1)),
                ),
                _Summary(
                  icon: Icons.local_drink_rounded,
                  color: const Color(0xFF8A7BD8),
                  label: context.l10n.avgDailyMilk,
                  value: avgMilk == null ? context.l10n.noRecords : '${avgMilk.toStringAsFixed(1)}L',
                ),
              ],
            ),
            2,
          ),
          SectionTitle(
            context.l10n.ledgerSection,
            subtitle: context.l10n.periodDays(_days),
            trailing: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LedgerScreen())),
              child: Text(context.l10n.openLedger),
            ),
          ),
          rise(
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MoneyStat(label: context.l10n.income, value: money.format(income)),
                      ),
                      Expanded(
                        child: _MoneyStat(label: context.l10n.expense, value: money.format(expense)),
                      ),
                      Expanded(
                        child: _MoneyStat(
                          label: context.l10n.netProfit,
                          value: money.format(income - expense),
                          color: income - expense < 0 ? AppColors.red : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (income == 0 && expense == 0) ...[
                    const SizedBox(height: 8),
                    Text(context.l10n.noLedgerInPeriod, style: AppText.caption),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: Text(context.l10n.lastSixMonths, style: AppText.caption)),
                      _Legend(color: ledgerColor(true), label: context.l10n.income),
                      const SizedBox(width: 10),
                      _Legend(color: ledgerColor(false), label: context.l10n.expense),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(height: 170, child: _monthlyBars(store.ledgerMonthly(6), money)),
                ],
              ),
            ),
            3,
          ),
          SectionTitle(context.l10n.eggProduction, subtitle: context.l10n.eggTargetLine(profile.dailyEggTarget)),
          rise(
            _ChartCard(
              child: _line(
                [
                  for (final (i, p) in production.indexed)
                    p.$2 == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), p.$2!.eggs.toDouble()),
                ],
                AppColors.orange,
                target: profile.dailyEggTarget.toDouble(),
                labels: [for (final p in production) p.$1],
              ),
            ),
            3,
          ),
          SectionTitle(
            context.l10n.milkProduction,
            subtitle: context.l10n.milkTargetLine(profile.dailyMilkTargetL.round()),
          ),
          rise(
            _ChartCard(
              child: _line(
                [
                  for (final (i, p) in production.indexed)
                    p.$2 == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), p.$2!.milkL),
                ],
                const Color(0xFF8A7BD8),
                target: profile.dailyMilkTargetL,
                labels: [for (final p in production) p.$1],
              ),
            ),
            4,
          ),
          SectionTitle(context.l10n.dailyWaterUse),
          rise(_ChartCard(child: _bars(water)), 5),
          SectionTitle(context.l10n.harvestByCrop),
          rise(
            AppCard(
              child: totals.isEmpty
                  ? Text(context.l10n.noHarvestRecords, style: AppText.caption)
                  : Column(
                      children: [
                        for (final (name, emoji, kg) in totals)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(width: 26, child: Text(emoji, style: const TextStyle(fontSize: 18))),
                                SizedBox(
                                  width: 72,
                                  child: Text(name, style: AppText.body, overflow: TextOverflow.ellipsis),
                                ),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: kg / totals.first.$3),
                                      duration: const Duration(milliseconds: 900),
                                      curve: Curves.easeOutCubic,
                                      builder: (_, v, _) => LinearProgressIndicator(
                                        value: v,
                                        minHeight: 12,
                                        color: AppColors.primary,
                                        backgroundColor: AppColors.primarySoft,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 64,
                                  child: Text(
                                    '${_num.format(kg)}kg',
                                    style: AppText.h3.copyWith(fontSize: 13),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            6,
          ),
        ],
      ),
    );
  }

  FlTitlesData _titles(List<DateTime> labels) {
    final step = (labels.length / 6).ceil();
    return FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 36,
          // 맨 위 눈금이 간격과 어긋나면(예: 223) 숫자를 숨긴다.
          getTitlesWidget: (v, meta) => v == meta.max && v % meta.appliedInterval != 0
              ? const SizedBox()
              : Text(meta.formattedValue, style: AppText.tiny),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          reservedSize: 24,
          getTitlesWidget: (v, meta) {
            final i = v.toInt();
            if (i < 0 || i >= labels.length || i % step != 0) return const SizedBox();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(DateFormat('M/d').format(labels[i]), style: AppText.tiny),
            );
          },
        ),
      ),
    );
  }

  Widget _line(List<FlSpot> spots, Color color, {required double target, required List<DateTime> labels}) {
    final values = [
      for (final s in spots)
        if (s != FlSpot.nullSpot) s.y,
    ];
    final maxY = ([...values, target].reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();
    return LineChart(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      LineChartData(
        minY: 0,
        maxY: maxY,
        minX: 0,
        maxX: (labels.length - 1).toDouble(),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.line, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _titles(labels),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(y: target, color: color.withValues(alpha: 0.6), strokeWidth: 1.4, dashArray: [6, 4]),
          ],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.text,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(_num.format(s.y), const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 3,
            dotData: FlDotData(show: labels.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthlyBars(List<(DateTime, double, double)> months, NumberFormat money) {
    final top = months.fold(0.0, (m, e) => [m, e.$2, e.$3].reduce((a, b) => a > b ? a : b));
    final compact = NumberFormat.compact(locale: context.localeName);
    return BarChart(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      BarChartData(
        // 기록이 하나도 없으면 축이 0~0이 되지 않도록 최소 높이를 둔다.
        maxY: top <= 0 ? 1 : top * 1.2,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.line, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: top > 0,
              reservedSize: 44,
              getTitlesWidget: (v, meta) => v == meta.max && v % meta.appliedInterval != 0
                  ? const SizedBox()
                  : Text(compact.format(v), style: AppText.tiny),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= months.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat.MMM(context.localeName).format(months[i].$1), style: AppText.tiny),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.text,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              money.format(rod.toY),
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        barGroups: [
          for (final (i, m) in months.indexed)
            BarChartGroupData(
              x: i,
              barsSpace: 3,
              barRods: [
                BarChartRodData(toY: m.$2, width: 9, color: ledgerColor(true), borderRadius: BorderRadius.circular(3)),
                BarChartRodData(toY: m.$3, width: 9, color: ledgerColor(false), borderRadius: BorderRadius.circular(3)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _bars(List<(DateTime, double)> water) {
    final maxY = water.map((w) => w.$2).fold(100.0, (a, b) => a > b ? a : b) * 1.2;
    return BarChart(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.line, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _titles([for (final w in water) w.$1]),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.text,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${_num.format(rod.toY)}L',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        barGroups: [
          for (final (i, w) in water.indexed)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: w.$2,
                  width: water.length > 14 ? 5 : 12,
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.fromLTRB(8, 18, 16, 8),
    child: SizedBox(height: 180, child: child),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.icon, required this.color, required this.label, required this.value});

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label, style: AppText.caption, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, style: AppText.number.copyWith(fontSize: 19), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _MoneyStat extends StatelessWidget {
  const _MoneyStat({required this.label, required this.value, this.color = AppColors.text});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.caption),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(value, style: AppText.h3.copyWith(color: color)),
      ),
    ],
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 4),
      Text(label, style: AppText.tiny),
    ],
  );
}
