import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';
import '../../data/weather.dart';
import 'backup_actions.dart';

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
    if (n == null) return '숫자를 입력하세요';
    if (n < min || n > max) return '$min ~ $max 사이로 입력하세요';
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
    showMessage(context, '농장 정보를 저장했습니다.');
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('예시 농장으로 초기화'),
        content: const Text('지금까지 기록한 작물·가축·수확·재고·할 일이 모두 지워지고 예시 데이터로 바뀝니다. 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('초기화', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final store = FarmScope.read(context);
    await store.resetToDemo();
    _load(store.state.profile);
    setState(() => _dirty = false);
    if (mounted) showMessage(context, '예시 농장으로 초기화했습니다.');
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
      validator: validator ?? (v) => (v ?? '').trim().isEmpty ? '비워 둘 수 없습니다' : null,
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
            rise(const Text('프로필', style: AppText.title), 0),
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
            const SectionTitle('농장 정보'),
            rise(
              AppCard(
                child: Column(
                  children: [
                    _field('name', '농장 이름'),
                    _field('area', '면적', suffix: 'ha', number: true, validator: (v) => _range(v, 0.01, 100000)),
                    _field('location', '지역 이름'),
                    Row(
                      children: [
                        Expanded(child: _field('lat', '위도', number: true, validator: (v) => _range(v, -90, 90))),
                        const SizedBox(width: 10),
                        Expanded(child: _field('lon', '경도', number: true, validator: (v) => _range(v, -180, 180))),
                      ],
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('위도·경도는 날씨 조회에만 쓰이며 기기 밖으로는 날씨 서버에만 전송됩니다.', style: AppText.tiny),
                    ),
                  ],
                ),
              ),
              2,
            ),
            const SectionTitle('생산 목표'),
            rise(
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _field('eggs', '하루 달걀', suffix: '개', number: true, validator: (v) => _range(v, 1, 100000)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field('milk', '하루 우유', suffix: 'L', number: true, validator: (v) => _range(v, 1, 100000)),
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
              child: PrimaryButton(label: '저장', icon: Icons.check_rounded, onTap: _dirty ? _save : null),
            ),
            const SectionTitle('데이터'),
            rise(
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '모든 기록은 이 기기에만 저장되어 앱을 삭제하면 함께 지워집니다. 백업 파일을 내보내 두면 다른 기기나 PC·웹 버전에서도 복원할 수 있어요.',
                      style: AppText.caption,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: '백업 내보내기',
                            icon: Icons.upload_file_rounded,
                            onTap: () => exportBackupFile(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrimaryButton(
                            label: '복원',
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
                    PrimaryButton(label: '예시 농장으로 초기화', icon: Icons.restart_alt_rounded, filled: false, onTap: _reset),
                  ],
                ),
              ),
              4,
            ),
            const SizedBox(height: 18),
            const Center(child: Text('날씨 데이터: Open-Meteo.com (CC BY 4.0)', style: AppText.tiny)),
          ],
        ),
      ),
    );
  }
}
