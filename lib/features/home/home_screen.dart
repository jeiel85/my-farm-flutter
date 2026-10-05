import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_shell.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';
import '../../data/weather.dart';
import '../crops/crop_detail_screen.dart';
import '../inventory/inventory_screen.dart';
import '../livestock/livestock_screen.dart';
import '../weather/weather_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = FarmScope.read(context).state.profile;
      WeatherScope.read(context).ensureLoaded(p.latitude, p.longitude);
    });
  }

  String _greeting(int hour) => switch (hour) {
    < 5 => '고요한 새벽이에요',
    < 11 => '좋은 아침이에요',
    < 17 => '오후도 힘내세요',
    < 21 => '오늘도 수고했어요',
    _ => '편안한 밤 보내세요',
  };

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final now = store.now;
    final alerts = _alerts(context, store);
    final avgGrowth = store.state.fields.isEmpty
        ? 0.0
        : store.state.fields.map((f) => f.growthAt(now)).reduce((a, b) => a + b) / store.state.fields.length;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          rise(
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('M월 d일 EEEE', 'ko').format(now), style: AppText.caption),
                      const SizedBox(height: 2),
                      Text(_greeting(now.hour), style: AppText.title),
                    ],
                  ),
                ),
                Pressable(
                  onTap: () => AppShell.goTo(context, AppTab.profile),
                  child: const IconBubble(
                    color: AppColors.primary,
                    size: 44,
                    child: Text('🧑‍🌾', style: TextStyle(fontSize: 22)),
                  ),
                ),
              ],
            ),
            0,
          ),
          const SizedBox(height: 16),
          rise(const _WeatherCard(), 1),
          const SizedBox(height: 12),
          rise(
            Row(
              children: [
                Expanded(
                  child: _MiniStat(icon: Icons.eco_rounded, color: AppColors.primary, label: '평균 생육', value: avgGrowth),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.favorite_rounded,
                    color: AppColors.red,
                    label: '가축 건강',
                    value: store.herdHealth,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.water_drop_rounded,
                    color: AppColors.blue,
                    label: '물탱크',
                    value: store.tankRatio,
                  ),
                ),
              ],
            ),
            2,
          ),
          SectionTitle('오늘 확인할 것', subtitle: alerts.isEmpty ? null : '${alerts.length}건'),
          if (alerts.isEmpty)
            rise(
              const AppCard(
                color: AppColors.primarySoft,
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text('모두 순조로워요', style: AppText.h3),
                  ],
                ),
              ),
              3,
            )
          else
            for (var i = 0; i < alerts.length; i++)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: rise(alerts[i], 3 + i)),
          const SectionTitle('오늘 할 일'),
          rise(const _TaskCard(), 4 + alerts.length),
        ],
      ),
    );
  }

  List<Widget> _alerts(BuildContext context, FarmStore store) {
    final now = store.now;
    final out = <Widget>[];
    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    for (final f in store.fieldsNeedingWater) {
      out.add(
        _Alert(
          icon: Icons.water_drop_rounded,
          color: AppColors.blue,
          title: '${f.cropName} 물주기',
          subtitle: '${relativeTime(f.nextWateringAt, now)}부터 필요 · ${f.litersPerWatering.round()}L',
          onTap: () => push(CropDetailScreen(fieldId: f.id)),
        ),
      );
    }
    for (final f in store.state.fields.where((f) => f.daysToHarvest(now) == 0)) {
      out.add(
        _Alert(
          icon: Icons.agriculture_rounded,
          color: AppColors.primary,
          title: '${f.cropName} 수확 가능',
          subtitle: '수확을 기록하고 다시 심을 수 있어요',
          onTap: () => push(CropDetailScreen(fieldId: f.id)),
        ),
      );
    }
    final next = store.nextFeeding;
    if (next != null && now.hour * 60 + now.minute >= next.hour * 60 + next.minute) {
      out.add(
        _Alert(
          icon: Icons.schedule_rounded,
          color: AppColors.orange,
          title: '${next.timeLabel} ${next.label} 급이',
          subtitle: '시간이 지났어요. 끝났다면 체크해 주세요',
          onTap: () => push(const LivestockScreen()),
        ),
      );
    }
    if (store.animalsNeedingCare > 0) {
      out.add(
        _Alert(
          icon: Icons.healing_rounded,
          color: AppColors.red,
          title: '가축 ${store.animalsNeedingCare}마리 관리 필요',
          subtitle: '건강 점수 80 미만',
          onTap: () => push(const LivestockScreen()),
        ),
      );
    }
    if (store.tankRatio < 0.25) {
      out.add(
        _Alert(
          icon: Icons.opacity_rounded,
          color: AppColors.blue,
          title: '물탱크 ${(store.tankRatio * 100).round()}%',
          subtitle: '물을 보충해 주세요',
          onTap: () => AppShell.goTo(context, AppTab.farm),
        ),
      );
    }
    final low = store.lowInventory;
    if (low.isNotEmpty) {
      out.add(
        _Alert(
          icon: Icons.inventory_rounded,
          color: AppColors.orange,
          title: '재고 부족 ${low.length}개',
          subtitle: low.map((i) => i.name).join(', '),
          onTap: () => push(const InventoryScreen()),
        ),
      );
    }
    return out;
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.color, required this.label, required this.value});

  final IconData icon;
  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => Text('${(v * 100).round()}%', style: AppText.number.copyWith(fontSize: 19)),
        ),
        Text(label, style: AppText.tiny),
      ],
    ),
  );
}

class _Alert extends StatelessWidget {
  const _Alert({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconBubble(
            size: 38,
            color: color.withValues(alpha: 0.13),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.h3.copyWith(fontSize: 14)),
                Text(subtitle, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    ),
  );
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard();

  @override
  Widget build(BuildContext context) {
    final weather = WeatherScope.of(context);
    final store = FarmScope.of(context);
    final report = weather.report;
    Widget body;
    if (report == null && weather.error != null) {
      body = Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Text(weather.error!, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          TextButton(
            onPressed: () =>
                weather.ensureLoaded(store.state.profile.latitude, store.state.profile.longitude, force: true),
            child: const Text('다시 시도', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    } else if (report == null) {
      body = const SizedBox(
        height: 56,
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
          ),
        ),
      );
    } else {
      final (label, icon) = describeWeather(report.code);
      body = Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD66B), size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report.temperatureC.round()}°  $label',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${store.state.profile.locationLabel} · 강수확률 ${report.todayRainChance}% · 바람 ${report.windKmh.round()}km/h',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white70),
        ],
      );
    }
    return Pressable(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WeatherScreen())),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF2B6A3C), Color(0xFF1F4D2C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: KeyedSubtree(key: ValueKey(report?.fetchedAt), child: body),
        ),
      ),
    );
  }
}

class _TaskCard extends StatefulWidget {
  const _TaskCard();

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    await FarmScope.read(context).addTask(text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final tasks = [...store.overdueTasks, ...store.tasksToday]
      ..sort((a, b) => (a.done ? 1 : 0).compareTo(b.done ? 1 : 0));
    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        children: [
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('오늘 할 일이 없습니다. 아래에 추가해 보세요.', style: AppText.caption),
            ),
          for (final t in tasks) _TaskRow(key: ValueKey(t.id), task: t, overdue: t.dateKey != store.todayKey),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: TextField(
              controller: _input,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(),
              decoration: InputDecoration(
                hintText: '할 일 추가',
                isDense: true,
                suffixIcon: IconButton(
                  onPressed: _add,
                  icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({super.key, required this.task, required this.overdue});

  final FarmTask task;
  final bool overdue;

  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey('dismiss-${task.id}'),
    direction: DismissDirection.endToStart,
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
    ),
    onDismissed: (_) => FarmScope.read(context).deleteTask(task.id),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => FarmScope.read(context).toggleTask(task.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: task.done ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: task.done ? AppColors.primary : AppColors.line, width: 2),
              ),
              child: task.done ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: AppText.body.copyWith(
                  color: task.done ? AppColors.muted : AppColors.text,
                  decoration: task.done ? TextDecoration.lineThrough : null,
                ),
                child: Text(task.title),
              ),
            ),
            if (overdue) const Tag('지난 일', color: AppColors.red),
            if (task.zone != null) ...[
              const SizedBox(width: 6),
              Icon(task.zone!.icon, size: 16, color: AppColors.muted),
            ],
          ],
        ),
      ),
    ),
  );
}
