import 'package:flutter/material.dart';

import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/app_update.dart';
import '../../game/game_store.dart';
import '../../l10n/l10n.dart';
import '../reminders/reminder_settings_card.dart';
import '../reminders/reminders.dart';
import '../update/update_widgets.dart';
import 'backup_actions.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _name = TextEditingController(text: GameScope.read(context).state.farmName);
  late final Future<String?> _archive = GameScope.read(context).managementArchive();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showMessage(context, context.l10n.nameError);
      return;
    }
    await GameScope.read(context).rename(name);
    if (mounted) showMessage(context, context.l10n.saved);
  }

  Future<void> _restart() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.restartTitle),
        content: Text(l.restartBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.restart, style: const TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final store = GameScope.read(context);
    await store.restart(farmName: store.state.farmName);
    if (mounted) showMessage(context, l.restarted);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final store = GameScope.of(context);
    final reminders = ReminderScope.of(context);
    final update = UpdateScope.of(context);
    return SafeArea(
      bottom: false,
      child: SplitList(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        primary: [
          Text(l.settingsTitle, style: AppText.title),
          SectionTitle(l.farmInfo),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l.farmName),
                  onSubmitted: (_) => _saveName(),
                ),
                const SizedBox(height: 10),
                PrimaryButton(label: l.save, icon: Icons.check_rounded, onTap: _saveName),
              ],
            ),
          ),
          SectionTitle(l.language),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'system', label: Text(l.languageSystem)),
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
          SectionTitle(l.dataSection),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.gameDataExplain, style: AppText.caption),
                const SizedBox(height: 8),
                Text(
                  store.lastBackupAt == null
                      ? l.lastBackupNever
                      : l.lastBackupAt(l.relative(store.lastBackupAt!, store.now)),
                  style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: l.exportBackup,
                        icon: Icons.upload_file_rounded,
                        onTap: () => exportBackupFile(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: l.restore,
                        icon: Icons.restore_rounded,
                        filled: false,
                        onTap: () async {
                          await importBackupFile(context);
                          if (context.mounted) _name.text = GameScope.read(context).state.farmName;
                        },
                      ),
                    ),
                  ],
                ),
                FutureBuilder<String?>(
                  future: _archive,
                  builder: (context, snap) => snap.data == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(l.archiveExplain, style: AppText.caption),
                              const SizedBox(height: 8),
                              PrimaryButton(
                                label: l.exportArchive,
                                icon: Icons.inventory_2_outlined,
                                filled: false,
                                onTap: () => exportManagementArchiveFile(context),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                PrimaryButton(label: l.restart, icon: Icons.restart_alt_rounded, filled: false, onTap: _restart),
              ],
            ),
          ),
        ],
        secondary: [
          if (reminders != null) ...[SectionTitle(l.remindersSection), ReminderSettingsCard(reminders: reminders)],
          if (update != null) ...[SectionTitle(l.appUpdate), UpdateSettingsCard(update: update, now: store.now)],
          const SizedBox(height: 18),
          Center(
            child: Text(l.creditLine, style: AppText.tiny, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
