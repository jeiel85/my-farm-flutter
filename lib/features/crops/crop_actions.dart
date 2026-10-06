import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';
import '../../l10n/l10n.dart';
import '../ledger/ledger_screen.dart';

Future<void> waterFieldWithFeedback(BuildContext context, CropField field) async {
  final store = FarmScope.read(context);
  try {
    await store.waterField(field.id);
    HapticFeedback.lightImpact();
    if (context.mounted) {
      showMessage(context, context.l10n.wateredField(field.cropName, field.litersPerWatering.round()));
    }
  } on InsufficientWaterException catch (e) {
    if (context.mounted) showMessage(context, context.l10n.tankTooLow(e.storedL.round()));
  }
}

Future<void> smartWateringWithFeedback(BuildContext context) async {
  final (watered, skipped) = await FarmScope.read(context).smartWatering();
  if (!context.mounted) return;
  if (watered == 0 && skipped == 0) {
    showMessage(context, context.l10n.nothingToWater);
  } else if (skipped == 0) {
    showMessage(context, context.l10n.wateredFields(watered));
  } else {
    showMessage(context, context.l10n.wateredFieldsSkipped(watered, skipped));
  }
}

/// 수확량을 입력받아 기록한다. 기록하면 판매 금액도 장부에 적었는지([sale])를 돌려주고, 취소하면 null.
Future<({bool sale})?> showHarvestSheet(BuildContext context, {CropField? field}) async {
  final store = FarmScope.read(context);
  final fields = store.state.fields;
  if (fields.isEmpty) return null;
  return showModalBottomSheet<({bool sale})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => _HarvestSheet(initial: field ?? fields.first, fields: fields),
  );
}

/// 출하·수확 시트의 "판매 금액(선택)" 칸을 읽는다. 비어 있으면 (null, null), 잘못 적었으면 (null, 오류 문구).
(double?, String?) readSaleAmount(BuildContext context, String text) {
  if (text.trim().isEmpty) return (null, null);
  final digits = moneyFormat(context, FarmScope.read(context).state.profile.currency).decimalDigits ?? 0;
  final amount = parseMoney(text, digits);
  if (amount == null || amount <= 0) return (null, context.l10n.mustBePositive);
  if (amount > FarmStore.maxLedgerAmount) return (null, context.l10n.ledgerAmountTooLarge);
  return (amount, null);
}

/// 농장 통화 기호를 붙인 판매 금액 입력 칸.
class SaleAmountField extends StatelessWidget {
  const SaleAmountField({super.key, required this.controller, this.errorText});

  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final money = moneyFormat(context, FarmScope.read(context).state.profile.currency);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: (money.decimalDigits ?? 0) > 0),
      decoration: InputDecoration(
        labelText: context.l10n.saleAmountOptional,
        helperText: context.l10n.saleAmountHint,
        prefixText: '${money.currencySymbol} ',
        errorText: errorText,
      ),
    );
  }
}

class _HarvestSheet extends StatefulWidget {
  const _HarvestSheet({required this.initial, required this.fields});

  final CropField initial;
  final List<CropField> fields;

  @override
  State<_HarvestSheet> createState() => _HarvestSheetState();
}

class _HarvestSheetState extends State<_HarvestSheet> {
  late CropField _field = widget.initial;
  final _amount = TextEditingController();
  final _sale = TextEditingController();
  final _note = TextEditingController();
  bool _replant = false;
  String? _error;
  String? _saleError;

  @override
  void dispose() {
    _amount.dispose();
    _sale.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final kg = double.tryParse(_amount.text.replaceAll(',', '.').trim());
    final (sale, saleError) = readSaleAmount(context, _sale.text);
    setState(() {
      _error = kg == null || kg <= 0 ? context.l10n.harvestAmountError : null;
      _saleError = saleError;
    });
    if (_error != null || _saleError != null) return;
    await FarmScope.read(context).harvest(
      fieldId: _field.id,
      amountKg: kg!,
      replant: _replant,
      note: _note.text.trim(),
      sale: sale == null
          ? null
          : LedgerSale(amount: sale, note: context.l10n.harvestSaleNote(_field.cropName, _formatKg(kg))),
    );
    if (mounted) Navigator.of(context).pop((sale: sale != null));
  }

  static String _formatKg(double kg) => kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : '$kg';

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(context.l10n.recordHarvest, style: AppText.h2),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in widget.fields)
                ChoiceChip(
                  label: Text('${f.emoji} ${f.cropName}'),
                  selected: f.id == _field.id,
                  onSelected: (_) => setState(() => _field = f),
                  selectedColor: AppColors.primarySoft,
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: context.l10n.harvestAmount, suffixText: 'kg', errorText: _error),
          ),
          const SizedBox(height: 10),
          SaleAmountField(controller: _sale, errorText: _saleError),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: context.l10n.optionalMemo),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _replant,
            onChanged: (v) => setState(() => _replant = v),
            title: Text(context.l10n.replantToday, style: AppText.body),
            subtitle: Text(context.l10n.replantHint, style: AppText.caption),
          ),
          const SizedBox(height: 8),
          PrimaryButton(label: context.l10n.saveRecord, icon: Icons.check_rounded, onTap: _save),
        ],
      ),
    ),
  );
}
