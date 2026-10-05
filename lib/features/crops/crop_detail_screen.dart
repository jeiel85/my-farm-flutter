import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';
import 'crop_actions.dart';
import '../../l10n/l10n.dart';

String _date(BuildContext context, DateTime d) => DateFormat.MMMd(context.localeName).format(d);

class CropDetailScreen extends StatelessWidget {
  const CropDetailScreen({super.key, required this.fieldId});

  final String fieldId;

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final field = store.fieldById(fieldId);
    if (field == null) {
      return Scaffold(body: Center(child: Text(context.l10n.fieldNotFound)));
    }
    final now = store.now;
    final growth = field.growthAt(now);
    final harvestAt = field.plantedAt.add(Duration(days: field.growDays));
    final waterLogs = store.state.waterLogs
        // v1.3.0 이전 기록은 밭 id가 없어 메모의 작물 이름으로 찾는다.
        .where((w) => w.fieldId == field.id || (w.fieldId == null && w.note.startsWith(field.cropName)))
        .toList()
        .reversed
        .take(5)
        .toList();
    final harvests = store.state.harvests.where((h) => h.cropName == field.cropName).take(5).toList();
    final totalKg = store.state.harvests.where((h) => h.cropName == field.cropName).fold(0.0, (s, h) => s + h.amountKg);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(title: field.cropName, subtitle: context.l10n.zone(field.zone)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  rise(
                    AppCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Hero(
                                tag: 'crop-${field.id}',
                                child: IconBubble(
                                  size: 64,
                                  color: AppColors.surfaceSoft,
                                  child: Text(field.emoji, style: const TextStyle(fontSize: 34)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${(growth * 100).round()}%', style: AppText.title),
                                    Text(
                                      field.daysToHarvest(now) == 0
                                          ? context.l10n.readyToHarvest
                                          : context.l10n.daysToHarvest(field.daysToHarvest(now)),
                                      style: AppText.caption,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SegmentBar(value: growth, segments: 14),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: StatBox(label: context.l10n.plantedOn, value: _date(context, field.plantedAt)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StatBox(label: context.l10n.harvestDue, value: _date(context, harvestAt)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StatBox(
                                  label: context.l10n.totalHarvest,
                                  value: '${totalKg.toStringAsFixed(1)}kg',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    0,
                  ),
                  SectionTitle(context.l10n.cropCondition, subtitle: context.l10n.cropConditionHint),
                  rise(
                    Row(
                      children: [
                        for (final s in CropStatus.values) ...[
                          if (s != CropStatus.values.first) const SizedBox(width: 8),
                          Expanded(
                            child: Pressable(
                              onTap: () => FarmScope.read(context).setFieldStatus(field.id, s),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: field.status == s ? s.color : AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  context.l10n.status(s),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: field.status == s ? Colors.white : AppColors.text,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    1,
                  ),
                  SectionTitle(context.l10n.watering),
                  rise(
                    AppCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: StatBox(
                                  label: context.l10n.lastLabel,
                                  value: context.l10n.relative(field.lastWateredAt, now),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StatBox(
                                  label: context.l10n.nextLabel,
                                  value: field.needsWater(now)
                                      ? context.l10n.neededNow
                                      : context.l10n.relative(field.nextWateringAt, now),
                                  valueColor: field.needsWater(now) ? AppColors.blue : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StatBox(
                                  label: context.l10n.perTimeAndInterval,
                                  value: '${field.litersPerWatering.round()}L·${field.waterIntervalHours}h',
                                ),
                              ),
                            ],
                          ),
                          if (waterLogs.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            for (final w in waterLogs)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.water_drop_rounded, size: 14, color: AppColors.blue),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        w.fieldId == null
                                            ? w.note
                                            : (w.smart
                                                  ? context.l10n.smartWateringLog(field.cropName)
                                                  : context.l10n.wateringLog(field.cropName)),
                                        style: AppText.caption,
                                      ),
                                    ),
                                    Text(
                                      '${w.liters.round()}L · ${context.l10n.relative(w.at, now)}',
                                      style: AppText.tiny,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    2,
                  ),
                  SectionTitle(context.l10n.recentHarvests),
                  rise(
                    AppCard(
                      child: harvests.isEmpty
                          ? Text(context.l10n.noHarvestYet, style: AppText.caption)
                          : Column(
                              children: [
                                for (final h in harvests)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                    child: Row(
                                      children: [
                                        Text(h.emoji),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(_date(context, h.date), style: AppText.body)),
                                        Text('${h.amountKg.toStringAsFixed(1)}kg', style: AppText.h3),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    3,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: context.l10n.waterAction,
                      icon: Icons.water_drop_outlined,
                      filled: false,
                      onTap: () => waterFieldWithFeedback(context, field),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      label: context.l10n.recordHarvest,
                      icon: Icons.add_rounded,
                      onTap: () async {
                        final saved = await showHarvestSheet(context, field: field);
                        if (saved && context.mounted) showMessage(context, context.l10n.harvestSaved);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
