import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/animal_painter.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';
import 'animal_sheets.dart';
import 'care_widgets.dart';
import '../../l10n/l10n.dart';

String _date(BuildContext context, DateTime d) => DateFormat.yMMMd(context.localeName).format(d);

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
      setState(() => _weightError = context.l10n.weightError);
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
      showMessage(context, context.l10n.animalSaved(a.name));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _original;
    if (a == null) return Scaffold(body: Center(child: Text(context.l10n.animalNotFound)));
    final now = FarmScope.of(context).now;
    final healthColor = _health >= 90 ? AppColors.primary : (_health >= 80 ? AppColors.orange : AppColors.red);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(title: a.name, subtitle: '${context.l10n.kindOne(a.kind)} · ${a.tag}'),
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
                          Text(a.breed.isEmpty ? context.l10n.unknownBreed : a.breed, style: AppText.caption),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: StatBox(label: context.l10n.ageLabel, value: context.l10n.age(a, now)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StatBox(
                                  label: context.l10n.bornOn,
                                  value: DateFormat('yy.M.d').format(a.birthDate),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StatBox(
                                  label: context.l10n.lastCheckup,
                                  value: a.lastCheckup == null
                                      ? context.l10n.noRecords
                                      : context.l10n.relative(a.lastCheckup!, now),
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
                      emptyText: context.l10n.noCareForAnimal,
                    ),
                    1,
                  ),
                  SectionTitle(context.l10n.healthScore, subtitle: context.l10n.healthScoreHint),
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
                                _health >= 90
                                    ? context.l10n.healthGreat
                                    : (_health >= 80 ? context.l10n.healthWatch : context.l10n.healthTreat),
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
                            title: Text(context.l10n.checkedToday, style: AppText.body),
                            subtitle: a.lastCheckup == null
                                ? null
                                : Text(
                                    context.l10n.previousCheckup(_date(context, a.lastCheckup!)),
                                    style: AppText.caption,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    1,
                  ),
                  SectionTitle(context.l10n.records),
                  rise(
                    AppCard(
                      child: Column(
                        children: [
                          TextField(
                            controller: _weight,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: context.l10n.weight,
                              suffixText: 'kg',
                              errorText: _weightError,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _note,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: context.l10n.memo,
                              hintText: context.l10n.animalNoteHint,
                            ),
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
                      label: context.l10n.removeAnimalAction,
                      icon: Icons.logout_rounded,
                      filled: false,
                      onTap: () async {
                        final removed = await showRemoveAnimalSheet(context, a);
                        if (removed == null || !context.mounted) return;
                        showMessage(
                          context,
                          removed.sale ? context.l10n.animalSoldWithSale(a.name) : context.l10n.animalRemoved(a.name),
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(label: context.l10n.save, icon: Icons.check_rounded, onTap: _save),
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
