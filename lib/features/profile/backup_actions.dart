import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../l10n/l10n.dart';

/// 현재 데이터를 JSON 백업 파일로 저장한다(웹은 내려받기).
Future<void> exportBackupFile(BuildContext context) async {
  final store = FarmScope.read(context);
  final bytes = Uint8List.fromList(utf8.encode(store.exportBackup()));
  final name = 'myfarm-backup-${DateFormat('yyyyMMdd-HHmm').format(store.now)}.json';
  try {
    final uri = await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: context.l10n.saveBackupDialog,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (!context.mounted) return;
    if (uri == null) {
      showMessage(context, context.l10n.backupCancelled);
    } else {
      await store.markBackedUp();
      if (!context.mounted) return;
      showMessage(context, context.l10n.backupSaved(savedFileName(uri, name)));
    }
  } catch (e) {
    if (context.mounted) showMessage(context, context.l10n.backupFailed('$e'));
  }
}

/// 백업 파일을 골라 내용을 확인받은 뒤 복원한다.
Future<void> importBackupFile(BuildContext context) async {
  final PlatformFile? file;
  try {
    file = await FilePicker.pickFile(
      dialogTitle: context.l10n.pickBackupDialog,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
  } catch (e) {
    if (context.mounted) showMessage(context, context.l10n.openFailed('$e'));
    return;
  }
  if (file == null || !context.mounted) return;

  final BackupContents contents;
  try {
    contents = FarmStore.parseBackup(await file.xFile.readAsString());
  } on BackupException catch (e) {
    if (!context.mounted) return;
    final l = context.l10n;
    final reason = switch (e.problem) {
      BackupProblem.notJson => l.backupNotJson,
      BackupProblem.notBackup => l.backupNotOurs,
      BackupProblem.damaged => l.backupDamaged,
      BackupProblem.newerVersion => l.backupNewer,
    };
    showMessage(context, l.restoreRejected(reason));
    return;
  } catch (e) {
    if (context.mounted) showMessage(context, context.l10n.readFailed('$e'));
    return;
  }
  if (!context.mounted) return;

  final s = contents.state;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.restoreTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(file!.name, style: AppText.caption),
          const SizedBox(height: 10),
          Text(context.l10n.restoreSummary(s.profile.name, s.animals.length, s.harvests.length, s.tasks.length)),
          if (contents.exportedAt != null)
            Text(
              context.l10n.backupMadeAt(DateFormat.yMd(context.localeName).add_Hm().format(contents.exportedAt!)),
              style: AppText.caption,
            ),
          const SizedBox(height: 10),
          Text(context.l10n.restoreWarning),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.restore)),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await FarmScope.read(context).restoreBackup(s);
  if (context.mounted) showMessage(context, context.l10n.restored);
}

/// 저장된 위치(file·content·blob URI)에서 사람이 읽을 파일 이름을 뽑는다. 알 수 없으면 [fallback].
String savedFileName(Uri uri, String fallback) {
  if (uri.scheme != 'file' && uri.scheme != 'content') return fallback;
  if (uri.pathSegments.isEmpty) return fallback;
  // content URI는 마지막 조각이 "primary:Download/이름.json"처럼 인코딩되어 있다.
  final last = Uri.decodeComponent(uri.pathSegments.last).split(RegExp(r'[/:\\]')).last;
  return last.isEmpty ? fallback : last;
}
