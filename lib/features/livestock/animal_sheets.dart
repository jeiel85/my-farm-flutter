import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/animal_painter.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';

final _date = DateFormat('yyyy년 M월 d일', 'ko');

const _sheetShape = RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28)));

/// 새 가축 입식 시트. 추가한 개체를 돌려준다(취소하면 null).
Future<Animal?> showAddAnimalSheet(BuildContext context, AnimalKind initialKind) => showModalBottomSheet<Animal>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.bg,
  shape: _sheetShape,
  builder: (_) => _AddAnimalSheet(initialKind: initialKind),
);

class _AddAnimalSheet extends StatefulWidget {
  const _AddAnimalSheet({required this.initialKind});

  final AnimalKind initialKind;

  @override
  State<_AddAnimalSheet> createState() => _AddAnimalSheetState();
}

class _AddAnimalSheetState extends State<_AddAnimalSheet> {
  late AnimalKind _kind = widget.initialKind;
  final _name = TextEditingController();
  final _breed = TextEditingController();
  final _weight = TextEditingController();
  late DateTime _birth = DateTime.now().subtract(const Duration(days: 365));
  String? _nameError;
  String? _weightError;

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      locale: const Locale('ko'),
    );
    if (picked != null) setState(() => _birth = picked);
  }

  Future<void> _save() async {
    final weight = double.tryParse(_weight.text.replaceAll(',', '.').trim());
    setState(() {
      _nameError = _name.text.trim().isEmpty ? '이름을 입력하세요.' : null;
      _weightError = weight == null || weight <= 0 ? '체중을 0보다 큰 숫자로 입력하세요.' : null;
    });
    if (_nameError != null || _weightError != null) return;
    final animal = await FarmScope.read(context)
        .addAnimal(kind: _kind, name: _name.text, breed: _breed.text, birthDate: _birth, weightKg: weight!);
    if (mounted) Navigator.of(context).pop(animal);
  }

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('가축 입식', style: AppText.h2),
            Text('번호표는 ${store.nextTag(_kind)}로 자동 부여됩니다.', style: AppText.caption),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final k in AnimalKind.values) ...[
                  if (k != AnimalKind.values.first) const SizedBox(width: 8),
                  Expanded(
                    child: Pressable(
                      onTap: () => setState(() => _kind = k),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: k == _kind ? AppColors.primary : AppColors.line, width: 2),
                        ),
                        child: Column(
                          children: [
                            AnimalAvatar(kind: k, size: 36),
                            Text(k.label, style: AppText.caption),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: '이름', errorText: _nameError),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _breed,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: '품종 (선택)', hintText: '예: 한우, 레그혼'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: '체중', suffixText: 'kg', errorText: _weightError),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickBirth,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: '태어난 날'),
                      child: Text(DateFormat('yy.M.d').format(_birth), style: AppText.body),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: '입식하기', icon: Icons.add_rounded, onTap: _save),
          ],
        ),
      ),
    );
  }
}

/// 출하·폐사 처리 시트. 처리했으면 true.
Future<bool> showRemoveAnimalSheet(BuildContext context, Animal animal) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: _sheetShape,
    builder: (_) => _RemoveAnimalSheet(animal: animal),
  );
  return result ?? false;
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

  Future<void> _confirm() async {
    await FarmScope.read(context).removeAnimal(widget.animal.id, type: _type, note: _note.text);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${widget.animal.name} 목록에서 빼기', style: AppText.h2),
        const Text('개체 정보는 입식·출하 이력에 남습니다.', style: AppText.caption),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: [
            for (final t in AnimalEventType.values.where((t) => t != AnimalEventType.added))
              ChoiceChip(
                label: Text(t.label),
                selected: _type == t,
                onSelected: (_) => setState(() => _type = t),
                selectedColor: AppColors.primarySoft,
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: '메모 (선택)', hintText: '예: 출하처, 원인'),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: '${_type.label} 처리', icon: Icons.check_rounded, onTap: _confirm),
      ],
    ),
  );
}

/// 최근 입식·출하·폐사 이력.
class AnimalHistoryCard extends StatelessWidget {
  const AnimalHistoryCard({super.key, required this.events});

  final List<AnimalEvent> events;

  @override
  Widget build(BuildContext context) => AppCard(
    child: events.isEmpty
        ? const Text('아직 입식·출하 기록이 없습니다.', style: AppText.caption)
        : Column(
            children: [
              for (final e in events.take(10))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Tag(
                        e.type.label,
                        color: switch (e.type) {
                          AnimalEventType.added => AppColors.primary,
                          AnimalEventType.sold => AppColors.blue,
                          AnimalEventType.died => AppColors.red,
                          AnimalEventType.other => AppColors.muted,
                        },
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${e.kind.label} ${e.name} · ${e.tag}', style: AppText.body),
                            if (e.note.isNotEmpty) Text(e.note, style: AppText.caption),
                          ],
                        ),
                      ),
                      Text(_date.format(e.date), style: AppText.tiny),
                    ],
                  ),
                ),
            ],
          ),
  );
}
