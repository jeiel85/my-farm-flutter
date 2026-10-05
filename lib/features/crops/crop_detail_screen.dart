import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';
import 'crop_actions.dart';

final _date = DateFormat('M월 d일', 'ko');

class CropDetailScreen extends StatelessWidget {
  const CropDetailScreen({super.key, required this.fieldId});

  final String fieldId;

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final field = store.fieldById(fieldId);
    if (field == null) {
      return const Scaffold(body: Center(child: Text('밭을 찾을 수 없습니다.')));
    }
    final now = store.now;
    final growth = field.growthAt(now);
    final harvestAt = field.plantedAt.add(Duration(days: field.growDays));
    final waterLogs = store.state.waterLogs
        .where((w) => w.note.startsWith(field.cropName))
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
            PageHeader(title: field.cropName, subtitle: field.zone.label),
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
                                      field.daysToHarvest(now) == 0 ? '수확할 수 있어요' : '수확까지 ${field.daysToHarvest(now)}일',
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
                                child: StatBox(label: '파종일', value: _date.format(field.plantedAt)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StatBox(label: '수확 예정', value: _date.format(harvestAt)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StatBox(label: '누적 수확', value: '${totalKg.toStringAsFixed(1)}kg'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    0,
                  ),
                  const SectionTitle('작물 상태', subtitle: '현장에서 본 상태를 골라 두세요'),
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
                                  s.label,
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
                  const SectionTitle('물주기'),
                  rise(
                    AppCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: StatBox(label: '마지막', value: relativeTime(field.lastWateredAt, now)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StatBox(
                                  label: '다음',
                                  value: field.needsWater(now) ? '지금 필요' : relativeTime(field.nextWateringAt, now),
                                  valueColor: field.needsWater(now) ? AppColors.blue : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StatBox(
                                  label: '1회·주기',
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
                                    Expanded(child: Text(w.note, style: AppText.caption)),
                                    Text('${w.liters.round()}L · ${relativeTime(w.at, now)}', style: AppText.tiny),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    2,
                  ),
                  const SectionTitle('최근 수확'),
                  rise(
                    AppCard(
                      child: harvests.isEmpty
                          ? const Text('아직 수확 기록이 없습니다.', style: AppText.caption)
                          : Column(
                              children: [
                                for (final h in harvests)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                    child: Row(
                                      children: [
                                        Text(h.emoji),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(_date.format(h.date), style: AppText.body)),
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
                      label: '물 주기',
                      icon: Icons.water_drop_outlined,
                      filled: false,
                      onTap: () => waterFieldWithFeedback(context, field),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      label: '수확 기록',
                      icon: Icons.add_rounded,
                      onTap: () async {
                        final saved = await showHarvestSheet(context, field: field);
                        if (saved && context.mounted) showMessage(context, '수확을 기록했습니다.');
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
