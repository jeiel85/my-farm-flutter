import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/app_update.dart';
import '../../l10n/l10n.dart';

/// 새 버전 안내 시트. 내려받는 동안에는 닫히지 않는다(같은 파일을 두 번 쓰지 않게).
Future<void> showUpdateSheet(BuildContext context, UpdateController update, UpdateManifest m) async {
  update.resetStep();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => _UpdateSheet(update: update, manifest: m),
  );
  update.resetStep();
}

class _UpdateSheet extends StatelessWidget {
  const _UpdateSheet({required this.update, required this.manifest});

  final UpdateController update;
  final UpdateManifest manifest;

  Future<void> _install(BuildContext context) async {
    final opened = await update.downloadAndInstall(manifest);
    if (opened && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: update,
    builder: (context, _) {
      final l = context.l10n;
      final step = update.step;
      final downloading = step == UpdateStep.downloading;
      final sizeMb = (manifest.apkSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      return PopScope(
        canPop: !downloading,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const IconBubble(
                      color: AppColors.primarySoft,
                      child: Icon(Icons.system_update_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l.updateAvailableTitle(manifest.versionName), style: AppText.h2)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(l.updateSheetBody(sizeMb), style: AppText.caption),
                const SizedBox(height: 16),
                switch (step) {
                  UpdateStep.downloading => Row(
                    children: [
                      const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l.updateDownloading, style: AppText.caption)),
                    ],
                  ),
                  UpdateStep.needsPermission => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.updateNeedsPermission, style: AppText.caption.copyWith(color: AppColors.text)),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: l.updateOpenSettings,
                        icon: Icons.settings_rounded,
                        onTap: update.openInstallSettings,
                      ),
                      const SizedBox(height: 8),
                      PrimaryButton(
                        label: l.updateInstall,
                        icon: Icons.download_rounded,
                        filled: false,
                        onTap: () => _install(context),
                      ),
                    ],
                  ),
                  UpdateStep.failed => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.updateFailed, style: AppText.caption.copyWith(color: AppColors.red)),
                      const SizedBox(height: 12),
                      PrimaryButton(label: l.updateRetry, icon: Icons.refresh_rounded, onTap: () => _install(context)),
                      const SizedBox(height: 8),
                      PrimaryButton(
                        label: l.updateOpenInBrowser,
                        icon: Icons.open_in_new_rounded,
                        filled: false,
                        onTap: () => update.openUrl(manifest.apkUrl),
                      ),
                    ],
                  ),
                  UpdateStep.idle => PrimaryButton(
                    label: l.updateInstall,
                    icon: Icons.download_rounded,
                    onTap: () => _install(context),
                  ),
                },
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: downloading ? null : () => update.openUrl(manifest.releaseNotesUrl),
                      child: Text(l.updateReleaseNotes),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: downloading
                          ? null
                          : () async {
                              await update.skip(manifest);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                      child: Text(l.updateSkip),
                    ),
                    TextButton(onPressed: downloading ? null : () => Navigator.of(context).pop(), child: Text(l.later)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 프로필의 앱 업데이트 설정. 업데이트를 쓰지 않는 플랫폼에서는 [UpdateScope]가 비어 있어 그리지 않는다.
class UpdateSettingsCard extends StatelessWidget {
  const UpdateSettingsCard({super.key, required this.update, required this.now});

  final UpdateController update;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final offer = update.offer;
    final checked = update.lastCheckedAt;
    final String? status;
    if (!update.enabled) {
      status = null;
    } else if (update.checking) {
      status = l.updateChecking;
    } else if (update.lastCheckFailed) {
      status = l.updateCheckFailed;
    } else if (checked != null) {
      status = '${l.updateCheckedAt(l.relative(checked, now))}${offer == null ? ' · ${l.updateUpToDate}' : ''}';
    } else {
      status = null;
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
                    Text(l.updateAutoCheck, style: AppText.h3),
                    const SizedBox(height: 2),
                    Text(l.updateAutoCheckHint, style: AppText.tiny),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: update.enabled, onChanged: update.checking ? null : update.setEnabled),
            ],
          ),
          const SizedBox(height: 10),
          Text(l.updateInstalledVersion(update.build?.versionName ?? '-'), style: AppText.caption),
          if (status != null) ...[const SizedBox(height: 4), Text(status, style: AppText.caption)],
          if (offer != null) ...[
            const SizedBox(height: 12),
            PrimaryButton(
              label: l.updateAvailableTitle(offer.versionName),
              icon: Icons.system_update_rounded,
              onTap: () => showUpdateSheet(context, update, offer),
            ),
          ],
        ],
      ),
    );
  }
}
