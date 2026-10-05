import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/animal_painter.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';

/// 새 가축을 들이는(입식) 시트. 기록하면 추가된 개체를 돌려준다.
Future<Animal?> showAddAnimalSheet(BuildContext context, {required AnimalKind kind}) => showModalBottomSheet<Animal>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.bg,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
  builder: (_) => _AddAnimalSheet(initialKind: kind),
);

/// 출하·폐사 처리 시트. 처리하면 true.
Future<bool> showRemoveAnimalSheet(BuildContext context, Animal animal) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _RemoveAnimalSheet(animal: animal),
  );
  return result ?? false;
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
    ),
  );
}

double? _parsePositive(String text) {
  final v = double.tryParse(text.replaceAll(',', '.').trim());
  return v == null || v <= 0 ? null : v;
}

class _AddAnimalSheet extends StatefulWidget {
  const _AddAnimalSheet({required this.initialKind});

  final AnimalKind initialKind;

  @override
  State<_AddAnimalSheet> createState() => _AddAnimalSheetState();
}

class _AddAnimalSheetState extends State<_AddAnimalSheet> {
  late AnimalKind _kind = widget.initialKind;
  final _name = TextEditingController();
  final _tag = TextEditingController();
  final _breed = TextEditingController();
  final _ageMonths = TextEditingController();
  final _weight = TextEditingController();
  final _note = TextEditingController();

  /// 사용자가 태그를 직접 고쳤으면 종류를 바꿔도 제안값으로 덮어쓰지 않는다.
  bool _tagEdited = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // didChangeDependencies에 두면 키보드가 열릴 때(MediaQuery 변경)마다 다시 불려, 사용자가 비운 태그를 되살린다.
    _tag.text = FarmScope.read(context).suggestTag(_kind);
  }

  @override
  void dispose() {
    for (final c in [_name, _tag, _breed, _ageMonths, _weight, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectKind(AnimalKind kind) {
    setState(() {
      _kind = kind;
      if (!_tagEdited) _tag.text = FarmScope.read(context).suggestTag(kind);
    });
  }

  Future<void> _save() async {
    final months = int.tryParse(_ageMonths.text.trim());
    final weight = _parsePositive(_weight.text);
    if (_name.text.trim().isEmpty || _tag.text.trim().isEmpty) {
      setState(() => _error = '이름과 태그를 입력하세요.');
      return;
    }
    if (months == null || months < 0) {
      setState(() => _error = '나이를 0 이상의 개월 수로 입력하세요.');
      return;
    }
    if (weight == null) {
      setState(() => _error = '체중을 0보다 큰 숫자로 입력하세요.');
      return;
    }
    final store = FarmScope.read(context);
    final today = DateTime(store.now.year, store.now.month, store.now.day);
    try {
      final animal = await store.addAnimal(
        kind: _kind,
        tag: _tag.text,
        name: _name.text,
        breed: _breed.text,
        // 생년월일을 정확히 모르는 경우가 많아 개월 수로 받고, 달력상 그만큼 앞선 날로 둔다.
        birthDate: DateTime(today.year, today.month - months, today.day),
        weightKg: weight,
        note: _note.text,
      );
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop(animal);
    } on StateError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Grabber(),
          const SizedBox(height: 16),
          const Text('가축 들이기', style: AppText.h2),
          const SizedBox(height: 2),
          const Text('입식 기록이 함께 남아요. 건강 점수는 100에서 시작하고, 검진 후 상세 화면에서 고칠 수 있어요.', style: AppText.caption),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final k in AnimalKind.values) ...[
                if (k != AnimalKind.values.first) const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    showCheckmark: false,
                    avatar: AnimalAvatar(kind: k, size: 22),
                    label: Text(k.label),
                    selected: k == _kind,
                    onSelected: (_) => _selectKind(k),
                    selectedColor: AppColors.primarySoft,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '이름'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _tag,
                  onChanged: (_) => _tagEdited = true,
                  decoration: const InputDecoration(labelText: '태그'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _breed,
            decoration: const InputDecoration(labelText: '품종 (선택)'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageMonths,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '나이', suffixText: '개월'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '체중', suffixText: 'kg'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: '메모 (선택)', hintText: '예: 이웃 농장에서 구입', errorText: _error),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: '들이기', icon: Icons.check_rounded, onTap: _save),
        ],
      ),
    ),
  );
}

class _RemoveAnimalSheet extends StatefulWidget {
  const _RemoveAnimalSheet({required this.animal});

  final Animal animal;

  @override
  State<_RemoveAnimalSheet> createState() => _RemoveAnimalSheetState();
}

class _RemoveAnimalSheetState extends State<_RemoveAnimalSheet> {
  AnimalEventType _type = AnimalEventType.sold;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await FarmScope.read(context).removeAnimal(widget.animal.id, _type, note: _note.text);
      if (mounted) Navigator.of(context).pop(true);
    } on StateError catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.animal;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Grabber(),
          const SizedBox(height: 16),
          Text('${a.name} 내보내기', style: AppText.h2),
          const SizedBox(height: 2),
          Text('${a.kind.label} · ${a.tag} · 목록에서 빠지고 기록으로만 남아요. 되돌릴 수 없어요.', style: AppText.caption),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final t in [AnimalEventType.sold, AnimalEventType.died]) ...[
                if (t != AnimalEventType.sold) const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(t.icon, size: 18, color: t.color),
                    label: Text(t.label),
                    selected: t == _type,
                    onSelected: (_) => setState(() => _type = t),
                    selectedColor: AppColors.primarySoft,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            decoration: InputDecoration(
              labelText: '메모 (선택)',
              hintText: _type == AnimalEventType.sold ? '예: 지역 축협 출하, 620kg' : '예: 고열로 폐사, 수의사 확인',
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: '${_type.label} 처리', icon: _type.icon, onTap: _save),
        ],
      ),
    );
  }
}
