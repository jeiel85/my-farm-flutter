import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';
import '../crops/crop_actions.dart';

final _num = NumberFormat('#,##0.#');

class HarvestScreen extends StatelessWidget {
  const HarvestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final now = store.now;
    final harvests = [...store.state.harvests]..sort((a, b) => b.date.compareTo(a.date));
    final monthStart = DateTime(now.year, now.month);
    final thisMonth = store.harvestSince(monthStart);
    final total = harvests.fold(0.0, (s, h) => s + h.amountKg);

    // 월별로 묶는다.
    final groups = <String, List<HarvestRecord>>{};
    for (final h in harvests) {
      groups.putIfAbsent(DateFormat('yyyy년 M월', 'ko').format(h.date), () => []).add(h);
    }

    var index = 3;
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              rise(const Text('수확', style: AppText.title), 0),
              const SizedBox(height: 14),
              rise(
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(colors: [Color(0xFFE8963A), Color(0xFFD9772A)]),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('이번 달 수확', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: thisMonth),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, _) => Text(
                                '${_num.format(v)}kg',
                                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(
                              '누적 ${_num.format(total)}kg · ${harvests.length}건',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Text('🧺', style: TextStyle(fontSize: 46)),
                    ],
                  ),
                ),
                1,
              ),
              if (harvests.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: Text('아직 수확 기록이 없습니다.', style: AppText.caption)),
                ),
              for (final e in groups.entries) ...[
                SectionTitle(e.key, subtitle: '${_num.format(e.value.fold(0.0, (s, h) => s + h.amountKg))}kg'),
                for (final h in e.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: rise(_HarvestTile(record: h), (index++).clamp(0, 10)),
                  ),
              ],
            ],
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: PrimaryButton(
              label: '수확 기록하기',
              icon: Icons.add_rounded,
              onTap: () async {
                final saved = await showHarvestSheet(context);
                if (saved && context.mounted) showMessage(context, '수확을 기록했습니다.');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HarvestTile extends StatelessWidget {
  const _HarvestTile({required this.record});

  final HarvestRecord record;

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('수확 기록 삭제'),
        content: Text(
          '${DateFormat('M월 d일').format(record.date)} ${record.cropName} ${_num.format(record.amountKg)}kg 기록을 삭제할까요?\n삭제하면 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await FarmScope.read(context).deleteHarvest(record.id);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: () => _delete(context),
    child: AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconBubble(
            color: AppColors.surfaceSoft,
            child: Text(record.emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.cropName, style: AppText.h3),
                Text(
                  [
                    DateFormat('M월 d일 (E)', 'ko').format(record.date),
                    if (record.note.isNotEmpty) record.note,
                  ].join(' · '),
                  style: AppText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text('${_num.format(record.amountKg)}kg', style: AppText.h3.copyWith(fontSize: 16)),
          IconButton(
            tooltip: '삭제',
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}
