import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';

final _qty = NumberFormat('#,##0.#');

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    var index = 0;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(title: '재고', subtitle: '눌러서 입고·사용 기록'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                children: [
                  for (final cat in InventoryCategory.values) ...[
                    if (store.state.inventory.any((i) => i.category == cat)) ...[
                      SectionTitle(cat.label),
                      for (final item in store.state.inventory.where((i) => i.category == cat))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: rise(_ItemTile(item: item), index++),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final days = item.daysLeft;
    final ratio = item.lowThreshold <= 0 ? 1.0 : (item.quantity / (item.lowThreshold * 3)).clamp(0.0, 1.0);
    final color = item.isLow ? AppColors.orange : AppColors.primary;
    return Pressable(
      onTap: () => _adjust(context, item),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(item.name, style: AppText.h3)),
                if (item.isLow) const Tag('부족', color: AppColors.orange, icon: Icons.warning_amber_rounded),
                const SizedBox(width: 8),
                Text('${_qty.format(item.quantity)} ${item.unit}', style: AppText.h3),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.12),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  days == null ? '소비 예측 없음' : '하루 ${_qty.format(item.dailyUse)}${item.unit} 사용 · 약 ${days.floor()}일분',
                  style: AppText.tiny,
                ),
                const Spacer(),
                Text('기준 ${_qty.format(item.lowThreshold)}${item.unit}', style: AppText.tiny),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adjust(BuildContext context, InventoryItem item) async {
    final controller = TextEditingController();
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          Future<void> apply(double sign) async {
            final v = double.tryParse(controller.text.replaceAll(',', '.').trim());
            if (v == null || v <= 0) {
              setSheet(() => error = '0보다 큰 숫자로 입력하세요.');
              return;
            }
            if (sign < 0 && v > item.quantity) {
              setSheet(() => error = '현재 재고(${_qty.format(item.quantity)}${item.unit})보다 많이 쓸 수 없습니다.');
              return;
            }
            await FarmScope.read(context).adjustInventory(item.id, sign * v);
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppText.h2),
                Text('현재 ${_qty.format(item.quantity)} ${item.unit}', style: AppText.caption),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: '수량', suffixText: item.unit, errorText: error),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: '사용',
                        icon: Icons.remove_rounded,
                        filled: false,
                        onTap: () => apply(-1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(label: '입고', icon: Icons.add_rounded, onTap: () => apply(1)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    controller.dispose();
  }
}
