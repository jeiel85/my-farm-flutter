import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/animal_painter.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';
import 'animal_detail_screen.dart';
import 'animal_sheets.dart';

class LivestockScreen extends StatefulWidget {
  const LivestockScreen({super.key});

  @override
  State<LivestockScreen> createState() => _LivestockScreenState();
}

class _LivestockScreenState extends State<LivestockScreen> {
  AnimalKind _kind = AnimalKind.cow;

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final animals = store.animalsOf(_kind)..sort((a, b) => b.health.compareTo(a.health));
    final care = store.animalsNeedingCare;
    final feedDays = store.feedDaysLeft;
    final production = store.productionRatio;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: '가축 관리',
              subtitle: store.state.profile.name,
              trailing: Pressable(
                onTap: () async {
                  final added = await showAddAnimalSheet(context, _kind);
                  if (added == null || !context.mounted) return;
                  setState(() => _kind = added.kind);
                  showMessage(context, '${added.name}(${added.tag})을(를) 입식했습니다.');
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    sliver: SliverList.list(
                      children: [
                        rise(
                          AppCard(
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('전체 가축', style: AppText.caption),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.baseline,
                                            textBaseline: TextBaseline.alphabetic,
                                            children: [
                                              TweenAnimationBuilder<double>(
                                                tween: Tween(begin: 0, end: store.totalAnimals.toDouble()),
                                                duration: const Duration(milliseconds: 900),
                                                curve: Curves.easeOutCubic,
                                                builder: (_, v, _) =>
                                                    Text('${v.round()}', style: AppText.title.copyWith(fontSize: 34)),
                                              ),
                                              const SizedBox(width: 4),
                                              const Text('마리', style: AppText.caption),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    care == 0
                                        ? const Tag('모두 건강', icon: Icons.verified_user_outlined)
                                        : Tag('$care마리 관리 필요', color: AppColors.orange, icon: Icons.healing_outlined),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    RingStat(
                                      value: store.herdHealth,
                                      color: AppColors.primary,
                                      label: '건강',
                                      caption: store.herdHealth >= 0.9 ? '아주 좋음' : '살펴보기',
                                    ),
                                    RingStat(
                                      value: feedDays == null ? 0 : feedDays / FarmStore.feedTargetDays,
                                      color: AppColors.orange,
                                      label: '사료',
                                      caption: feedDays == null ? '기록 없음' : '${feedDays.floor()}일분 재고',
                                    ),
                                    Pressable(
                                      onTap: () => _showProductionSheet(context),
                                      child: RingStat(
                                        value: production ?? 0,
                                        color: AppColors.blue,
                                        label: '생산',
                                        caption: store.todayProduction == null ? '오늘 기록하기 ›' : '목표 대비',
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
                        rise(_FeedingCard(), 1),
                        const SectionTitle('종류', subtitle: '눌러서 그 무리를 봅니다'),
                        rise(
                          Row(
                            children: [
                              for (final k in AnimalKind.values) ...[
                                if (k != AnimalKind.values.first) const SizedBox(width: 8),
                                Expanded(
                                  child: _KindCard(
                                    kind: k,
                                    count: store.countOf(k),
                                    active: k == _kind,
                                    onTap: () => setState(() => _kind = k),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          2,
                        ),
                        SectionTitle('우리 ${_kind.label}', subtitle: '${animals.length}${_kind.unit} · 눌러서 자세히 보기'),
                      ],
                    ),
                  ),
                  if (animals.isEmpty)
                    const SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverToBoxAdapter(
                        child: AppCard(child: Text('이 종류의 가축이 없습니다. 오른쪽 위 + 로 입식하세요.', style: AppText.caption)),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.separated(
                      itemCount: animals.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => rise(_AnimalTile(animal: animals[i]), i.clamp(0, 8)),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverList.list(
                      children: [
                        const SectionTitle('입식·출하 이력', subtitle: '최근 10건'),
                        AnimalHistoryCard(events: store.state.animalEvents),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProductionSheet(BuildContext context) async {
    final store = FarmScope.read(context);
    final current = store.todayProduction;
    final eggs = TextEditingController(text: current?.eggs.toString() ?? '');
    final milk = TextEditingController(text: current?.milkL.toString() ?? '');
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('오늘 생산량', style: AppText.h2),
              const SizedBox(height: 4),
              Text(
                '목표: 달걀 ${store.state.profile.dailyEggTarget}개 · 우유 ${store.state.profile.dailyMilkTargetL.round()}L',
                style: AppText.caption,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: eggs,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '달걀', suffixText: '개'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: milk,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: '우유', suffixText: 'L', errorText: error),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: '저장',
                icon: Icons.check_rounded,
                onTap: () async {
                  final e = int.tryParse(eggs.text.trim());
                  final m = double.tryParse(milk.text.replaceAll(',', '.').trim());
                  if (e == null || e < 0 || m == null || m < 0) {
                    setSheet(() => error = '0 이상의 숫자로 입력하세요.');
                    return;
                  }
                  await store.recordProduction(eggs: e, milkL: m);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
    eggs.dispose();
    milk.dispose();
  }
}

class _FeedingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final slots = store.state.feedingSlots;
    final done = store.feedingDoneToday;
    final now = store.now;
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              const IconBubble(
                size: 30,
                color: Color(0xFFFCF1D2),
                child: Icon(Icons.schedule_rounded, size: 16, color: AppColors.orange),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('오늘의 급이', style: AppText.h3)),
              Tag(
                '${done.length}/${slots.length} 완료',
                color: done.length == slots.length ? AppColors.primary : AppColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < slots.length; i++) ...[
                Expanded(
                  child: Pressable(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final shortages = await FarmScope.read(context).toggleFeeding(i);
                      if (shortages.isNotEmpty && context.mounted) {
                        showMessage(context, '재고가 모자라 남은 만큼만 차감했습니다: ${shortages.join(', ')}');
                      }
                    },
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _Line(active: i > 0 && done.contains(i - 1) && done.contains(i), visible: i > 0),
                            ),
                            _Node(done: done.contains(i)),
                            Expanded(
                              child: _Line(
                                active: i < slots.length - 1 && done.contains(i) && done.contains(i + 1),
                                visible: i < slots.length - 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(slots[i].timeLabel, style: AppText.h3.copyWith(fontSize: 14)),
                        Text(slots[i].label, style: AppText.tiny),
                        const SizedBox(height: 2),
                        Text(
                          done.contains(i)
                              ? '완료'
                              : (now.hour * 60 + now.minute > slots[i].hour * 60 + slots[i].minute ? '지남' : '예정'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: done.contains(i)
                                ? AppColors.primary
                                : (now.hour * 60 + now.minute > slots[i].hour * 60 + slots[i].minute
                                      ? AppColors.red
                                      : AppColors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutBack,
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      color: done ? AppColors.primary : AppColors.surface,
      shape: BoxShape.circle,
      border: Border.all(color: done ? AppColors.primary : AppColors.line, width: 2),
    ),
    child: AnimatedScale(
      scale: done ? 1 : 0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.active, required this.visible});

  final bool active;
  final bool visible;

  @override
  Widget build(BuildContext context) => !visible
      ? const SizedBox()
      : AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.line,
            borderRadius: BorderRadius.circular(2),
          ),
        );
}

class _KindCard extends StatelessWidget {
  const _KindCard({required this.kind, required this.count, required this.active, required this.onTap});

  final AnimalKind kind;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? AppColors.primary : Colors.transparent, width: 2),
        boxShadow: active
            ? const [BoxShadow(color: Color(0x221F4D2C), blurRadius: 14, offset: Offset(0, 6))]
            : const [],
      ),
      child: Column(
        children: [
          AnimatedScale(
            scale: active ? 1.08 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: AnimalAvatar(kind: kind, size: 42),
          ),
          const SizedBox(height: 4),
          Text('$count', style: AppText.h3.copyWith(fontSize: 17)),
          Text(kind.label, style: AppText.tiny),
        ],
      ),
    ),
  );
}

class _AnimalTile extends StatelessWidget {
  const _AnimalTile({required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final now = FarmScope.of(context).now;
    final healthColor = animal.health >= 90
        ? AppColors.primary
        : (animal.health >= 80 ? AppColors.orange : AppColors.red);
    return Pressable(
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnimalDetailScreen(animalId: animal.id))),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Hero(
              tag: 'animal-${animal.id}',
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(16)),
                child: AnimalAvatar(kind: animal.kind, variant: animal.variant),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(animal.name, style: AppText.h3),
                  Text(animal.breed, style: AppText.caption),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Tag(animal.tag, color: AppColors.muted, icon: Icons.sell_outlined),
                      const SizedBox(width: 6),
                      Tag(animal.ageLabel(now), color: AppColors.orange),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Tag('${animal.health}%', color: healthColor, icon: Icons.favorite_rounded),
                const SizedBox(height: 10),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
