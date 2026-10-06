import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';
import '../crops/crop_actions.dart';
import '../../l10n/l10n.dart';

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
      groups.putIfAbsent(DateFormat.yMMMM(context.localeName).format(h.date), () => []).add(h);
    }

    var index = 3;
    final wide = isWide(context);
    final recordButton = PrimaryButton(
      label: context.l10n.recordHarvestAction,
      icon: Icons.add_rounded,
      onTap: () async {
        final saved = await showHarvestSheet(context);
        if (saved != null && context.mounted) {
          showMessage(context, saved.sale ? context.l10n.harvestSavedWithSale : context.l10n.harvestSaved);
        }
      },
    );
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          // 넓은 화면: 왼쪽에 요약과 기록 버튼, 오른쪽에 달별 기록. 휴대폰은 버튼이 아래에 떠 있다.
          SplitList(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            primaryFlex: 2,
            secondaryFlex: 3,
            primary: [
              rise(Text(context.l10n.harvestTitle, style: AppText.title), 0),
              const SizedBox(height: 14),
              rise(
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(colors: [AppColors.orangeLight, AppColors.orange]),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.thisMonthHarvest,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
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
                              context.l10n.harvestTotals(_num.format(total), harvests.length),
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
              if (wide) ...[const SizedBox(height: 14), recordButton],
            ],
            secondary: [
              if (harvests.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: Text(context.l10n.noHarvestYet, style: AppText.caption)),
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
          if (!wide) Positioned(left: 20, right: 20, bottom: 16, child: recordButton),
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
        title: Text(context.l10n.deleteHarvestTitle),
        content: Text(
          context.l10n.deleteHarvestBody(
            DateFormat.MMMd(context.localeName).format(record.date),
            record.cropName,
            _num.format(record.amountKg),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete, style: const TextStyle(color: AppColors.red)),
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
                    DateFormat.MMMEd(context.localeName).format(record.date),
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
            tooltip: context.l10n.delete,
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}
