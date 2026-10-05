import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';

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
      dialogTitle: '백업 파일 저장',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (!context.mounted) return;
    if (uri == null) {
      showMessage(context, '백업 저장을 취소했습니다.');
    } else {
      await store.markBackedUp();
      if (!context.mounted) return;
      showMessage(context, '백업을 저장했습니다: ${savedFileName(uri, name)}');
    }
  } catch (e) {
    if (context.mounted) showMessage(context, '백업을 저장하지 못했습니다: $e');
  }
}

/// 백업 파일을 골라 내용을 확인받은 뒤 복원한다.
Future<void> importBackupFile(BuildContext context) async {
  final PlatformFile? file;
  try {
    file = await FilePicker.pickFile(dialogTitle: '백업 파일 선택', type: FileType.custom, allowedExtensions: const ['json']);
  } catch (e) {
    if (context.mounted) showMessage(context, '파일을 열지 못했습니다: $e');
    return;
  }
  if (file == null || !context.mounted) return;

  final BackupContents contents;
  try {
    contents = FarmStore.parseBackup(await file.xFile.readAsString());
  } on FormatException catch (e) {
    if (context.mounted) showMessage(context, '복원할 수 없는 파일입니다: ${e.message}');
    return;
  } catch (e) {
    if (context.mounted) showMessage(context, '파일을 읽지 못했습니다: $e');
    return;
  }
  if (!context.mounted) return;

  final s = contents.state;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('백업에서 복원'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(file!.name, style: AppText.caption),
          const SizedBox(height: 10),
          Text('${s.profile.name} · 가축 ${s.animals.length}마리 · 수확 기록 ${s.harvests.length}건 · 할 일 ${s.tasks.length}개'),
          if (contents.exportedAt != null)
            Text('만든 시각: ${DateFormat('yyyy.M.d HH:mm').format(contents.exportedAt!)}', style: AppText.caption),
          const SizedBox(height: 10),
          const Text('지금 데이터는 이 백업으로 바뀝니다. 바뀌기 전 데이터는 앱 안에 따로 보관됩니다.'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('복원')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await FarmScope.read(context).restoreBackup(s);
  if (context.mounted) showMessage(context, '백업에서 복원했습니다.');
}

/// 저장된 위치(file·content·blob URI)에서 사람이 읽을 파일 이름을 뽑는다. 알 수 없으면 [fallback].
String savedFileName(Uri uri, String fallback) {
  if (uri.scheme != 'file' && uri.scheme != 'content') return fallback;
  if (uri.pathSegments.isEmpty) return fallback;
  // content URI는 마지막 조각이 "primary:Download/이름.json"처럼 인코딩되어 있다.
  final last = Uri.decodeComponent(uri.pathSegments.last).split(RegExp(r'[/:\\]')).last;
  return last.isEmpty ? fallback : last;
}
