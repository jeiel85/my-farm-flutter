import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import 'crop_detail_screen.dart';

class CropsScreen extends StatelessWidget {
  const CropsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final now = store.now;
    final fields = [...store.state.fields]..sort((a, b) => a.daysToHarvest(now).compareTo(b.daysToHarvest(now)));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(title: '내 작물', subtitle: '수확이 가까운 순'),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                itemCount: fields.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final f = fields[i];
                  final growth = f.growthAt(now);
                  final days = f.daysToHarvest(now);
                  return rise(
                    Pressable(
                      onTap: () =>
                          Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => CropDetailScreen(fieldId: f.id))),
                      child: AppCard(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Hero(
                                  tag: 'crop-${f.id}',
                                  child: IconBubble(
                                    color: AppColors.surfaceSoft,
                                    child: Text(f.emoji, style: const TextStyle(fontSize: 22)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(f.cropName, style: AppText.h3),
                                      Text(
                                        '${f.zone.label} · ${days == 0 ? '수확 가능' : '수확까지 $days일'}',
                                        style: AppText.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                if (f.needsWater(now))
                                  const Tag('물 필요', color: AppColors.blue, icon: Icons.water_drop_outlined),
                                const SizedBox(width: 6),
                                Tag(f.status.label, color: f.status.color),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: SegmentBar(value: growth, segments: 12)),
                                const SizedBox(width: 10),
                                Text('${(growth * 100).round()}%', style: AppText.h3.copyWith(fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    i,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
