import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../game/reminder_plan.dart';
import '../../l10n/l10n.dart';
import 'reminders.dart';

/// 설정 화면의 알림 설정(Android·Windows).
class ReminderSettingsCard extends StatelessWidget {
  const ReminderSettingsCard({super.key, required this.reminders});

  final ReminderController reminders;

  Future<void> _toggle(BuildContext context, bool on) async {
    final ok = await reminders.setEnabled(on);
    if (!ok && context.mounted) showMessage(context, context.l10n.remindersPermissionDenied);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = reminders.settings;
    final String? status;
    if (!s.enabled) {
      status = null;
    } else if (reminders.lastError != null) {
      status = l.remindersFailed('${reminders.lastError}');
    } else if (reminders.permissionMissing) {
      status = l.remindersPermissionOff;
    } else if (reminders.nextAt case final next?) {
      status = l.remindersScheduled(reminders.scheduledCount, reminderTimeLabel(context, next));
    } else {
      status = l.remindersNoneScheduled;
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.remindersToggle, style: AppText.h3),
                    const SizedBox(height: 2),
                    Text(l.remindersHint, style: AppText.tiny),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: s.enabled, onChanged: (on) => _toggle(context, on)),
            ],
          ),
          if (s.enabled) ...[
            if (Theme.of(context).platform == TargetPlatform.android) ...[
              const SizedBox(height: 6),
              Text(l.remindersAndroidDelay, style: AppText.tiny),
            ],
            const SizedBox(height: 8),
            Text(l.remindersQuietHours, style: AppText.tiny),
            for (final kind in ReminderKind.values)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: s.allows(kind),
                onChanged: (on) => reminders.setKind(kind, on ?? false),
                title: Text(switch (kind) {
                  ReminderKind.harvest => l.remindersHarvest,
                  ReminderKind.animals => l.remindersAnimals,
                  ReminderKind.feed => l.remindersFeed,
                }, style: AppText.body),
              ),
          ],
          if (status != null) ...[
            const SizedBox(height: 4),
            Text(
              status,
              style: AppText.caption.copyWith(
                color: reminders.lastError != null || reminders.permissionMissing ? AppColors.red : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
