import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';

final _md = DateFormat('M월 d일', 'ko');
final _ymd = DateFormat('yyyy년 M월 d일', 'ko');

/// 올해 날짜는 월·일만, 다른 해는 연도까지 적는다.
String careDate(DateTime d) => d.year == DateTime.now().year ? _md.format(d) : _ymd.format(d);

/// "오늘", "D-3", "2일 지남" 같은 남은 날 표시와 색.
(String, Color) dueLabel(CareItem item, DateTime now) {
  final d = item.daysUntil(now);
  if (d < 0) return ('${-d}일 지남', AppColors.red);
  if (d == 0) return ('오늘', AppColors.orange);
  if (d == 1) return ('내일', AppColors.orange);
  return ('D-$d', d <= 7 ? AppColors.primary : AppColors.muted);
}

/// 백신·진료 일정 목록 카드.
class CareCard extends StatelessWidget {
  const CareCard({super.key, required this.items, required this.onAdd, this.emptyText = '예정된 일정이 없습니다.'});

  final List<CareItem> items;
  final VoidCallback onAdd;
  final String emptyText;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
    child: Column(
      children: [
        Row(
          children: [
            const IconBubble(
              size: 30,
              color: Color(0xFFFBE3E1),
              child: Icon(Icons.vaccines_outlined, size: 16, color: AppColors.red),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('백신·진료 일정', style: AppText.h3)),
            TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('추가')),
          ],
        ),
        const SizedBox(height: 4),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(emptyText, style: AppText.caption),
          ),
        for (final item in items) CareTile(key: ValueKey(item.id), item: item),
      ],
    ),
  );
}

class CareTile extends StatelessWidget {
  const CareTile({super.key, required this.item});

  final CareItem item;

  Future<void> _complete(BuildContext context) async {
    HapticFeedback.lightImpact();
    final next = await FarmScope.read(context).completeCare(item.id);
    if (!context.mounted) return;
    showMessage(
      context,
      next == null ? '${item.title} 완료를 기록했습니다.' : '${item.title} 완료. 다음 일정은 ${careDate(next.dueDate)}입니다.',
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('${item.title}(${careDate(item.dueDate)}) 일정을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await FarmScope.read(context).deleteCareItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final (due, dueColor) = dueLabel(item, store.now);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onLongPress: () => _delete(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(item.type.icon, size: 20, color: AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    [
                      store.careTargetLabel(item),
                      careDate(item.dueDate),
                      if (item.repeatMonths > 0) '${item.repeatMonths}개월마다',
                    ].join(' · '),
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            Tag(due, color: dueColor),
            IconButton(
              tooltip: '완료',
              onPressed: () => _complete(context),
              icon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// 일정 추가 시트. [animal]을 주면 그 개체가 대상으로 정해진다.
Future<void> showAddCareSheet(BuildContext context, {required AnimalKind kind, Animal? animal}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _AddCareSheet(kind: kind, animal: animal),
    );

class _AddCareSheet extends StatefulWidget {
  const _AddCareSheet({required this.kind, required this.animal});

  final AnimalKind kind;
  final Animal? animal;

  @override
  State<_AddCareSheet> createState() => _AddCareSheetState();
}

class _AddCareSheetState extends State<_AddCareSheet> {
  late AnimalKind _kind = widget.kind;
  late bool _wholeKind = widget.animal == null;
  CareType _type = CareType.vaccine;
  final _title = TextEditingController();
  final _note = TextEditingController();
  late DateTime _due = DateTime.now().add(const Duration(days: 7));
  int _repeat = 0;
  String? _titleError;

  static const _repeats = [0, 1, 3, 6, 12];

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _titleError = '일정 이름을 입력하세요.');
      return;
    }
    await FarmScope.read(context).addCareItem(
      kind: _kind,
      animalId: _wholeKind ? null : widget.animal?.id,
      type: _type,
      title: _title.text,
      dueDate: _due,
      repeatMonths: _repeat,
      note: _note.text,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final animal = widget.animal;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('백신·진료 일정 추가', style: AppText.h2),
            const SizedBox(height: 14),
            const Text('대상', style: AppText.caption),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (animal != null) ...[
                  ChoiceChip(
                    label: Text(animal.name),
                    selected: !_wholeKind,
                    onSelected: (_) => setState(() => _wholeKind = false),
                    selectedColor: AppColors.primarySoft,
                  ),
                  ChoiceChip(
                    label: Text('${animal.kind.label} 전체'),
                    selected: _wholeKind,
                    onSelected: (_) => setState(() => _wholeKind = true),
                    selectedColor: AppColors.primarySoft,
                  ),
                ] else
                  for (final k in AnimalKind.values)
                    ChoiceChip(
                      label: Text('${k.label} 전체'),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                      selectedColor: AppColors.primarySoft,
                    ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('종류', style: AppText.caption),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final t in CareType.values)
                  ChoiceChip(
                    avatar: Icon(t.icon, size: 16),
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                    selectedColor: AppColors.primarySoft,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: '일정 이름', hintText: '예: 구제역 백신', errorText: _titleError),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: '날짜'),
                      child: Text(_md.format(_due), style: AppText.body),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _repeat,
                    decoration: const InputDecoration(labelText: '반복'),
                    items: [
                      for (final m in _repeats) DropdownMenuItem(value: m, child: Text(m == 0 ? '한 번만' : '$m개월마다')),
                    ],
                    onChanged: (v) => setState(() => _repeat = v ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: '메모 (선택)'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: '일정 추가', icon: Icons.add_rounded, onTap: _save),
          ],
        ),
      ),
    );
  }
}
