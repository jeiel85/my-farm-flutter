import 'package:flutter/material.dart';

import 'core/layout.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'data/farm_store.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/farm/farm_screen.dart';
import 'features/harvest/harvest_screen.dart';
import 'features/home/home_screen.dart';
import 'features/profile/profile_screen.dart';
import 'l10n/l10n.dart';

enum AppTab {
  home(Icons.home_outlined, Icons.home_rounded),
  farm(Icons.spa_outlined, Icons.spa_rounded),
  analytics(Icons.bar_chart_outlined, Icons.bar_chart_rounded),
  harvest(Icons.inventory_2_outlined, Icons.inventory_2_rounded),
  profile(Icons.person_outline_rounded, Icons.person_rounded);

  const AppTab(this.icon, this.activeIcon);

  String label(AppLocalizations l) => switch (this) {
    AppTab.home => l.tabHome,
    AppTab.farm => l.tabFarm,
    AppTab.analytics => l.tabAnalytics,
    AppTab.harvest => l.tabHarvest,
    AppTab.profile => l.tabProfile,
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

class _AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.home;

  void _select(AppTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  Widget _page(AppTab tab) => switch (tab) {
    AppTab.home => const HomeScreen(),
    AppTab.farm => const FarmScreen(),
    AppTab.analytics => const AnalyticsScreen(),
    AppTab.harvest => const HarvestScreen(),
    AppTab.profile => const ProfileScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final content = Column(
      children: [
        if (store.recoveredFromCorruptData)
          _Banner(text: context.l10n.recoveredNotice, onClose: store.dismissLoadNotice),
        if (store.saveError != null) _Banner(text: context.l10n.saveFailed('${store.saveError}'), color: AppColors.red),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(anim), child: child),
            ),
            child: KeyedSubtree(key: ValueKey(_tab), child: _page(_tab)),
          ),
        ),
      ],
    );
    // 넓은 화면(PC·태블릿 가로)은 아래 탭 대신 왼쪽 메뉴를 둔다.
    if (isWide(context)) {
      return Scaffold(
        body: Row(
          children: [
            _SideBar(current: _tab, onSelect: _select),
            Expanded(child: content),
          ],
        ),
      );
    }
    return Scaffold(
      body: content,
      bottomNavigationBar: _BottomBar(current: _tab, onSelect: _select),
    );
  }
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
      child: Padding(
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

class _Banner extends StatelessWidget {
  const _Banner({required this.text, this.onClose, this.color = AppColors.orange});

  final String text;
  final VoidCallback? onClose;
  final Color color;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Container(
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
