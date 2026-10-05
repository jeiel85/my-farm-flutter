import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';
import '../../data/weather.dart';
import 'backup_actions.dart';
import '../../l10n/l10n.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _c = {
      for (final k in ['name', 'area', 'location', 'lat', 'lon', 'eggs', 'milk']) k: TextEditingController(),
    };
    _load(FarmScope.read(context).state.profile);
    for (final c in _c.values) {
      c.addListener(() {
        if (!_dirty) setState(() => _dirty = true);
      });
    }
  }

  void _load(FarmProfile p) {
    _c['name']!.text = p.name;
    _c['area']!.text = p.areaHa.toString();
    _c['location']!.text = p.locationLabel;
    _c['lat']!.text = p.latitude.toString();
    _c['lon']!.text = p.longitude.toString();
    _c['eggs']!.text = p.dailyEggTarget.toString();
    _c['milk']!.text = p.dailyMilkTargetL.toString();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(String key) => double.tryParse(_c[key]!.text.replaceAll(',', '.').trim());

  String? _range(String? v, double min, double max) {
    final n = double.tryParse((v ?? '').replaceAll(',', '.').trim());
    if (n == null) return context.l10n.enterNumber;
    if (n < min || n > max) return context.l10n.numberRange('$min', '$max');
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final store = FarmScope.read(context);
    final next = store.state.profile.copyWith(
      name: _c['name']!.text.trim(),
      areaHa: _num('area'),
      locationLabel: _c['location']!.text.trim(),
      latitude: _num('lat'),
      longitude: _num('lon'),
      dailyEggTarget: _num('eggs')!.round(),
      dailyMilkTargetL: _num('milk'),
    );
    await store.updateProfile(next);
    if (!mounted) return;
    setState(() => _dirty = false);
    FocusScope.of(context).unfocus();
    WeatherScope.read(context).ensureLoaded(next.latitude, next.longitude, force: true);
    showMessage(context, context.l10n.farmSaved);
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.resetTitle),
        content: Text(context.l10n.resetBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.reset, style: const TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final store = FarmScope.read(context);
    await store.resetToDemo(english: Localizations.localeOf(context).languageCode != 'ko');
    _load(store.state.profile);
    setState(() => _dirty = false);
    if (mounted) showMessage(context, context.l10n.resetDone);
  }

  Widget _field(
    String key,
    String label, {
    String? suffix,
    bool number = false,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: _c[key],
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
      validator: validator ?? (v) => (v ?? '').trim().isEmpty ? context.l10n.cannotBeEmpty : null,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    return SafeArea(
      bottom: false,
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            rise(Text(context.l10n.profileTitle, style: AppText.title), 0),
            const SizedBox(height: 14),
            rise(
              AppCard(
                child: Row(
                  children: [
                    const IconBubble(
                      size: 56,
                      color: AppColors.primarySoft,
                      child: Text('🧑‍🌾', style: TextStyle(fontSize: 28)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store.state.profile.name, style: AppText.h2),
                          Text(
                            '${store.state.profile.locationLabel} · ${store.state.profile.areaHa}ha',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              1,
            ),
            SectionTitle(context.l10n.farmInfo),
            rise(
              AppCard(
                child: Column(
                  children: [
                    _field('name', context.l10n.farmName),
                    _field(
                      'area',
                      context.l10n.area,
                      suffix: 'ha',
                      number: true,
                      validator: (v) => _range(v, 0.01, 100000),
                    ),
                    _field('location', context.l10n.locationName),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'lat',
                            context.l10n.latitude,
                            number: true,
                            validator: (v) => _range(v, -90, 90),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            'lon',
                            context.l10n.longitude,
                            number: true,
                            validator: (v) => _range(v, -180, 180),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(context.l10n.locationPrivacy, style: AppText.tiny),
                    ),
                  ],
                ),
              ),
              2,
            ),
            SectionTitle(context.l10n.productionGoals),
            rise(
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _field(
                        'eggs',
                        context.l10n.dailyEggs,
                        suffix: context.l10n.unitEggs,
                        number: true,
                        validator: (v) => _range(v, 1, 100000),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(
                        'milk',
                        context.l10n.dailyMilk,
                        suffix: 'L',
                        number: true,
                        validator: (v) => _range(v, 1, 100000),
                      ),
                    ),
                  ],
                ),
              ),
              3,
            ),
            const SizedBox(height: 14),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _dirty ? 1 : 0.5,
              child: PrimaryButton(label: context.l10n.save, icon: Icons.check_rounded, onTap: _dirty ? _save : null),
            ),
            SectionTitle(context.l10n.language),
            rise(
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'system', label: Text(context.l10n.languageSystem)),
                  // 언어 이름은 그 언어로 적는다(바꾸려는 사람이 읽을 수 있게).
                  const ButtonSegment(value: 'ko', label: Text('한국어')),
                  const ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {store.localeOverride ?? 'system'},
                showSelectedIcon: false,
                onSelectionChanged: (s) => store.setLocaleOverride(s.first == 'system' ? null : s.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.primary,
                  selectedForegroundColor: Colors.white,
                  backgroundColor: AppColors.surface,
                  side: BorderSide.none,
                ),
              ),
              4,
            ),
            SectionTitle(context.l10n.dataSection),
            rise(
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.dataExplain, style: AppText.caption),
                    const SizedBox(height: 8),
                    Text(
                      store.lastBackupAt == null
                          ? context.l10n.lastBackupNever
                          : context.l10n.lastBackupAt(context.l10n.relative(store.lastBackupAt!, store.now)),
                      style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: context.l10n.exportBackup,
                            icon: Icons.upload_file_rounded,
                            onTap: () => exportBackupFile(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrimaryButton(
                            label: context.l10n.restore,
                            icon: Icons.restore_rounded,
                            filled: false,
                            onTap: () async {
                              await importBackupFile(context);
                              if (!context.mounted) return;
                              _load(FarmScope.read(context).state.profile);
                              setState(() => _dirty = false);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      label: context.l10n.resetTitle,
                      icon: Icons.restart_alt_rounded,
                      filled: false,
                      onTap: _reset,
                    ),
                  ],
                ),
              ),
              4,
            ),
            const SizedBox(height: 18),
            Center(child: Text(context.l10n.weatherCredit, style: AppText.tiny)),
          ],
        ),
      ),
    );
  }
}
