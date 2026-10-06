import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/ledger_csv.dart';
import '../../l10n/l10n.dart';
import '../profile/backup_actions.dart';
import 'ledger_screen.dart';

/// 장부 전체를 CSV 파일로 저장한다(웹은 내려받기).
Future<void> exportLedgerCsvFile(BuildContext context) async {
  final store = FarmScope.read(context);
  final l = context.l10n;
  final ledger = store.state.ledger;
  if (ledger.isEmpty) {
    showMessage(context, l.ledgerCsvEmpty);
    return;
  }
  final currency = store.state.profile.currency;
  final csv = ledgerCsv(
    ledger,
    header: [l.date, l.csvType, l.csvCategory, l.ledgerAmount, l.currency, l.csvNote],
    typeLabel: (income) => income ? l.income : l.expense,
    categoryLabel: l.ledgerCategory,
    currency: currency,
    decimalDigits: moneyFormat(context, currency).decimalDigits ?? 0,
  );
  final name = 'myfarm-ledger-${DateFormat('yyyyMMdd-HHmm').format(store.now)}.csv';
  try {
    final uri = await FilePicker.saveFile(
      fileName: name,
      bytes: Uint8List.fromList(utf8.encode(csv)),
      mimeType: 'text/csv',
      dialogTitle: l.saveLedgerCsvDialog,
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (!context.mounted) return;
    showMessage(context, uri == null ? l.ledgerCsvCancelled : l.ledgerCsvSaved(savedFileName(uri, name)));
  } catch (e) {
    if (context.mounted) showMessage(context, l.ledgerCsvFailed('$e'));
  }
}
