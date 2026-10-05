import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/animal_painter.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';
import 'animal_sheets.dart';
import 'care_widgets.dart';

final _date = DateFormat('yyyy년 M월 d일', 'ko');

class AnimalDetailScreen extends StatefulWidget {
  const AnimalDetailScreen({super.key, required this.animalId});

  final String animalId;

  @override
  State<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends State<AnimalDetailScreen> {
  Animal? _original;
  late double _health;
  late final TextEditingController _weight;
  late final TextEditingController _note;
  bool _checkupToday = false;
  String? _weightError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_original != null) return;
    final a = FarmScope.read(context).animalById(widget.animalId);
    _original = a;
    _health = (a?.health ?? 0).toDouble();
    _weight = TextEditingController(text: a?.weightKg.toString() ?? '');
    _note = TextEditingController(text: a?.note ?? '');
  }

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final a = _original!;
    final weight = double.tryParse(_weight.text.replaceAll(',', '.').trim());
    if (weight == null || weight <= 0) {
      setState(() => _weightError = '체중을 0보다 큰 숫자로 입력하세요.');
      return;
    }
    final store = FarmScope.read(context);
    await store.updateAnimal(
      a.copyWith(
        health: _health.round(),
        weightKg: weight,
        note: _note.text.trim(),
        lastCheckup: _checkupToday ? store.now : null,
      ),
    );
    if (mounted) {
      showMessage(context, '${a.name} 정보를 저장했습니다.');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _original;
    if (a == null) return const Scaffold(body: Center(child: Text('가축을 찾을 수 없습니다.')));
    final now = FarmScope.of(context).now;
    final healthColor = _health >= 90 ? AppColors.primary : (_health >= 80 ? AppColors.orange : AppColors.red);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(title: a.name, subtitle: '${a.kind.label} · ${a.tag}'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  rise(
                    AppCard(
                      child: Column(
                        children: [
                          Hero(
                            tag: 'animal-${a.id}',
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: AnimalAvatar(kind: a.kind, size: 150, variant: a.variant),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(a.name, style: AppText.title),
                          Text(a.breed, style: AppText.caption),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: StatBox(label: '나이', value: a.ageLabel(now)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StatBox(label: '태어난 날', value: DateFormat('yy.M.d').format(a.birthDate)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StatBox(
                                  label: '마지막 검진',
                                  value: a.lastCheckup == null ? '기록 없음' : relativeTime(a.lastCheckup!, now),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    0,
                  ),
                  const SizedBox(height: 12),
                  rise(
                    CareCard(
                      items: FarmScope.of(context).careFor(a),
                      onAdd: () => showAddCareSheet(context, kind: a.kind, animal: a),
                      emptyText: '이 개체에 해당하는 일정이 없습니다.',
                    ),
                    1,
                  ),
                  const SectionTitle('건강 점수', subtitle: '검진 결과를 0~100으로 기록합니다'),
                  rise(
                    AppCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.favorite_rounded, color: healthColor),
                              const SizedBox(width: 8),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: AppText.title.copyWith(color: healthColor),
                                child: Text('${_health.round()}'),
                              ),
                              const Spacer(),
                              Text(
                                _health >= 90 ? '아주 좋음' : (_health >= 80 ? '관찰 필요' : '치료 필요'),
                                style: AppText.caption,
                              ),
                            ],
                          ),
                          Slider(
                            value: _health,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            activeColor: healthColor,
                            onChanged: (v) => setState(() => _health = v),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _checkupToday,
                            onChanged: (v) => setState(() => _checkupToday = v ?? false),
                            title: const Text('오늘 검진함으로 기록', style: AppText.body),
                            subtitle: a.lastCheckup == null
                                ? null
                                : Text('이전 검진: ${_date.format(a.lastCheckup!)}', style: AppText.caption),
                          ),
                        ],
                      ),
                    ),
                    1,
                  ),
                  const SectionTitle('기록'),
                  rise(
                    AppCard(
                      child: Column(
                        children: [
                          TextField(
                            controller: _weight,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: '체중', suffixText: 'kg', errorText: _weightError),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _note,
                            maxLines: 3,
                            decoration: const InputDecoration(labelText: '메모', hintText: '예: 오른쪽 앞발 약간 절뚝임'),
                          ),
                        ],
                      ),
                    ),
                    2,
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
                      label: '출하·폐사',
                      icon: Icons.logout_rounded,
                      filled: false,
                      onTap: () async {
                        final removed = await showRemoveAnimalSheet(context, a);
                        if (!removed || !context.mounted) return;
                        showMessage(context, '${a.name}을(를) 목록에서 뺐습니다. 이력에 남아 있습니다.');
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(label: '저장', icon: Icons.check_rounded, onTap: _save),
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
