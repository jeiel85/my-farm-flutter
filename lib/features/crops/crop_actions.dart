import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';

Future<void> waterFieldWithFeedback(BuildContext context, CropField field) async {
  final store = FarmScope.read(context);
  try {
    await store.waterField(field.id);
    HapticFeedback.lightImpact();
    if (context.mounted) {
      showMessage(context, '${field.cropName}에 물을 ${field.litersPerWatering.round()}L 줬습니다.');
    }
  } on StateError catch (e) {
    if (context.mounted) showMessage(context, e.message);
  }
}

Future<void> smartWateringWithFeedback(BuildContext context) async {
  final (watered, skipped) = await FarmScope.read(context).smartWatering();
  if (!context.mounted) return;
  if (watered == 0 && skipped == 0) {
    showMessage(context, '2시간 안에 물을 줄 밭이 없습니다.');
  } else if (skipped == 0) {
    showMessage(context, '밭 $watered곳에 물을 줬습니다.');
  } else {
    showMessage(context, '밭 $watered곳에 물을 줬고, 물탱크가 부족해 $skipped곳은 건너뛰었습니다.');
  }
}

/// 수확량을 입력받아 기록한다. 기록하면 true.
Future<bool> showHarvestSheet(BuildContext context, {CropField? field}) async {
  final store = FarmScope.read(context);
  final fields = store.state.fields;
  if (fields.isEmpty) return false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => _HarvestSheet(initial: field ?? fields.first, fields: fields),
  );
  return result ?? false;
}

class _HarvestSheet extends StatefulWidget {
  const _HarvestSheet({required this.initial, required this.fields});

  final CropField initial;
  final List<CropField> fields;

  @override
  State<_HarvestSheet> createState() => _HarvestSheetState();
}

class _HarvestSheetState extends State<_HarvestSheet> {
  late CropField _field = widget.initial;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _replant = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final kg = double.tryParse(_amount.text.replaceAll(',', '.').trim());
    if (kg == null || kg <= 0) {
      setState(() => _error = '수확량을 0보다 큰 숫자로 입력하세요.');
      return;
    }
    await FarmScope.read(context).harvest(fieldId: _field.id, amountKg: kg, replant: _replant, note: _note.text.trim());
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('수확 기록', style: AppText.h2),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in widget.fields)
              ChoiceChip(
                label: Text('${f.emoji} ${f.cropName}'),
                selected: f.id == _field.id,
                onSelected: (_) => setState(() => _field = f),
                selectedColor: AppColors.primarySoft,
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: '수확량', suffixText: 'kg', errorText: _error),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: '메모 (선택)'),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _replant,
          onChanged: (v) => setState(() => _replant = v),
          title: const Text('수확을 마치고 오늘 다시 심기', style: AppText.body),
          subtitle: const Text('생육률이 0%부터 다시 계산됩니다.', style: AppText.caption),
        ),
        const SizedBox(height: 8),
        PrimaryButton(label: '기록하기', icon: Icons.check_rounded, onTap: _save),
      ],
    ),
  );
}
