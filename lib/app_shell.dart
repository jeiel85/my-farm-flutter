import 'dart:async';

import 'package:flutter/material.dart';

import 'core/layout.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'features/barn/barn_screen.dart';
import 'features/farm/away_dialog.dart';
import 'features/farm/farm_screen.dart';
import 'features/records/records_screen.dart';
import 'features/reminders/reminders.dart';
import 'features/settings/settings_screen.dart';
import 'game/game_store.dart';
import 'l10n/l10n.dart';

enum AppTab {
  farm(Icons.spa_outlined, Icons.spa_rounded),
  barn(Icons.warehouse_outlined, Icons.warehouse_rounded),
  records(Icons.bar_chart_outlined, Icons.bar_chart_rounded),
  settings(Icons.settings_outlined, Icons.settings_rounded);

  const AppTab(this.icon, this.activeIcon);

  String label(AppLocalizations l) => switch (this) {
    AppTab.farm => l.tabFarm,
    AppTab.barn => l.tabBarn,
    AppTab.records => l.tabRecords,
    AppTab.settings => l.tabSettings,
  };
  final IconData icon;
  final IconData activeIcon;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// 하위 화면에서 탭을 전환할 때 쓴다.
  static void goTo(BuildContext context, AppTab tab) => context.findAncestorStateOfType<_AppShellState>()?._select(tab);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  AppTab _tab = AppTab.farm;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 남은 시간이 초 단위로 줄어 보이게 매초 시계를 돌린다(저장은 분이 바뀔 때만 한다).
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => GameScope.read(context).tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _showAwayIfAny());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      GameScope.read(context).resume().then((_) => _showAwayIfAny());
    } else if (state == AppLifecycleState.hidden) {
      // 켜 둔 동안 앞으로 당겨진 오프라인 진행 범위(최대 4시간)에 맞춰, 닫혀 있는 동안 올 알림을 다시 잡는다.
      ReminderScope.read(context)?.sync();
    }
  }

  void _showAwayIfAny() {
    if (!mounted) return;
    final store = GameScope.read(context);
    final report = store.awayReport;
    if (report == null) return;
    store.dismissReport();
    showAwayDialog(context, report);
  }

  void _select(AppTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  Widget _page(AppTab tab) => switch (tab) {
    AppTab.farm => const FarmScreen(),
    AppTab.barn => const BarnScreen(),
    AppTab.records => const RecordsScreen(),
    AppTab.settings => const SettingsScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final store = GameScope.of(context);
    final banners = [
      if (store.migratedFromManagement)
        _Banner(text: context.l10n.migratedNotice, onClose: store.dismissLoadNotice)
      else if (store.recoveredFromCorruptData)
        _Banner(text: context.l10n.recoveredNotice, onClose: store.dismissLoadNotice),
      if (store.saveError != null) _Banner(text: context.l10n.saveFailed('${store.saveError}'), color: AppColors.red),
    ];
    Widget page = AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(anim), child: child),
      ),
      child: KeyedSubtree(key: ValueKey(_tab), child: _page(_tab)),
    );
    // 배너가 상태 표시줄 여백을 이미 차지했으므로 화면이 위 여백을 한 번 더 두지 않게 한다.
    if (banners.isNotEmpty) page = MediaQuery.removePadding(context: context, removeTop: true, child: page);
    final content = Column(
      children: [
        if (banners.isNotEmpty) SafeArea(bottom: false, child: Column(children: banners)),
        Expanded(child: page),
      ],
    );
    // 넓은 화면(PC·태블릿 가로)은 아래 탭 대신 왼쪽 메뉴를 둔다.
    // 창 폭이 900을 넘나들어도 트리 모양(Row → 키 있는 Expanded)을 그대로 둬야 탭 화면 상태가 다시 만들어지지 않는다.
    final wide = isWide(context);
    return Scaffold(
      body: Row(
        // 옆 메뉴(스크롤 가능)가 내용 높이로 줄어 가운데에 뜨지 않게 세로로 꽉 채운다.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide) _SideBar(current: _tab, onSelect: _select),
          Expanded(key: const ValueKey('content'), child: content),
        ],
      ),
      bottomNavigationBar: wide ? null : _BottomBar(current: _tab, onSelect: _select),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, this.onClose, this.color = AppColors.orange});

  final String text;
  final VoidCallback? onClose;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
    child: Row(
      children: [
        Icon(Icons.info_outline_rounded, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: AppText.caption.copyWith(color: AppColors.text)),
        ),
        if (onClose != null)
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
      ],
    ),
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.current, required this.onSelect});

  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      boxShadow: [BoxShadow(color: Color(0x143A2E12), blurRadius: 20, offset: Offset(0, -4))],
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 66,
        child: Row(
          children: [
            for (final tab in AppTab.values)
              Expanded(
                child: Pressable(
                  onTap: () => onSelect(tab),
                  scale: 0.9,
                  child: _BarItem(tab: tab, active: tab == current),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _BarItem extends StatelessWidget {
  const _BarItem({required this.tab, required this.active});

  final AppTab tab;
  final bool active;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: active,
    button: true,
    label: tab.label(context.l10n),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: active ? 16 : 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              active ? tab.activeIcon : tab.icon,
              key: ValueKey(active),
              size: 22,
              color: active ? AppColors.primary : AppColors.muted,
            ),
          ),
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.primary : AppColors.muted,
          ),
          child: Text(tab.label(context.l10n)),
        ),
      ],
    ),
  );
}

class _SideBar extends StatelessWidget {
  const _SideBar({required this.current, required this.onSelect});

  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    width: 220,
    decoration: const BoxDecoration(
      color: AppColors.surface,
      boxShadow: [BoxShadow(color: Color(0x143A2E12), blurRadius: 20, offset: Offset(4, 0))],
    ),
    child: SafeArea(
      right: false,
      // 창 높이가 낮아도 넘치지 않게 스크롤한다.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
              child: Row(
                children: [
                  const IconBubble(
                    color: AppColors.primary,
                    size: 38,
                    child: Text('🌱', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(context.l10n.appTitle, style: AppText.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            for (final tab in AppTab.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _SideItem(tab: tab, active: tab == current, onTap: () => onSelect(tab)),
              ),
          ],
        ),
      ),
    ),
  );
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.tab, required this.active, required this.onTap});

  final AppTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: active,
    button: true,
    label: tab.label(context.l10n),
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(active ? tab.activeIcon : tab.icon, size: 22, color: active ? AppColors.primary : AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tab.label(context.l10n),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppColors.primary : AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
