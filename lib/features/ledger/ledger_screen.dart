import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/models.dart';
import '../../l10n/l10n.dart';
import 'ledger_export.dart';

/// 농장 통화로 금액을 적는 형식(₩1,250,000, $1,250.00).
NumberFormat moneyFormat(BuildContext context, String currency) =>
    NumberFormat.simpleCurrency(locale: context.localeName, name: currency);

/// 금액 입력을 읽는다. 금액은 천 단위 쉼표를 붙여 적는 일이 많아 쉼표는 구분자로 보고 버린다.
/// 통화의 소수 자릿수(원화 0, 달러 2)에 맞춰 반올림한다.
double? parseMoney(String text, int decimalDigits) {
  final value = double.tryParse(text.replaceAll(RegExp(r'[\s,]'), ''));
  if (value == null || !value.isFinite) return null;
  return double.parse(value.toStringAsFixed(decimalDigits));
}

Color ledgerColor(bool income) => income ? AppColors.primary : AppColors.orange;

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  late DateTime _month = () {
    final now = FarmScope.read(context).now;
    return DateTime(now.year, now.month);
  }();

  Future<void> _add() async {
    final store = FarmScope.read(context);
    final now = store.now;
    final thisMonth = DateTime(now.year, now.month);
    // 지난 달을 보고 있으면 그 달 마지막 날을 기본값으로 둔다.
    final initial = _month == thisMonth ? now : addMonths(_month, 1).subtract(const Duration(days: 1));
    final saved = await showLedgerSheet(context, initialDate: initial);
    if (saved == null || !mounted) return;
    setState(() => _month = DateTime(saved.date.year, saved.date.month));
    showMessage(context, context.l10n.ledgerSaved);
  }

  @override
  Widget build(BuildContext context) {
    final store = FarmScope.of(context);
    final money = moneyFormat(context, store.state.profile.currency);
    final now = store.now;
    final nextMonth = addMonths(_month, 1);
    final entries = store.ledgerBetween(_month, nextMonth);
    final (income, expense) = store.ledgerTotals(_month, nextMonth);
    final categories = store.ledgerByCategory(_month, nextMonth);
    final canGoNext = nextMonth.isBefore(DateTime(now.year, now.month, now.day + 1));

    final days = <DateTime, List<LedgerEntry>>{};
    for (final e in entries) {
      days.putIfAbsent(e.date, () => []).add(e);
    }

    var index = 3;
    final wide = isWide(context);
    final addButton = PrimaryButton(label: context.l10n.addLedgerEntry, icon: Icons.add_rounded, onTap: _add);
    return Scaffold(
      body: WideBody(
        maxWidth: wideContentMaxWidth,
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                title: context.l10n.ledgerTitle,
                subtitle: context.l10n.ledgerCurrencyNote(store.state.profile.currency),
                trailing: IconButton(
                  tooltip: context.l10n.exportLedgerCsv,
                  onPressed: () => exportLedgerCsvFile(context),
                  icon: const Icon(Icons.file_download_outlined),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    // 넓은 화면: 왼쪽에 달 이동·요약·분류별·기록 버튼, 오른쪽에 날짜별 기록.
                    SplitList(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      widePadding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                      primary: [
                        rise(
                          Row(
                            children: [
                              IconButton(
                                tooltip: context.l10n.previousMonth,
                                onPressed: () => setState(() => _month = addMonths(_month, -1)),
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              Expanded(
                                child: Text(
                                  DateFormat.yMMMM(context.localeName).format(_month),
                                  style: AppText.h2,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              IconButton(
                                tooltip: context.l10n.nextMonth,
                                onPressed: canGoNext ? () => setState(() => _month = nextMonth) : null,
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                            ],
                          ),
                          0,
                        ),
                        const SizedBox(height: 8),
                        rise(_MonthSummary(income: income, expense: expense, money: money), 1),
                        if (entries.isNotEmpty) ...[
                          SectionTitle(context.l10n.byCategory),
                          rise(_CategoryCard(categories: categories, money: money), 2),
                        ],
                        if (wide) ...[const SizedBox(height: 14), addButton],
                      ],
                      secondary: [
                        if (entries.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Center(child: Text(context.l10n.noLedgerThisMonth, style: AppText.caption)),
                          )
                        else ...[
                          for (final day in days.entries) ...[
                            SectionTitle(DateFormat.MMMEd(context.localeName).format(day.key)),
                            for (final e in day.value)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: rise(_EntryTile(entry: e, money: money), (index++).clamp(0, 10)),
                              ),
                          ],
                        ],
                      ],
                    ),
                    if (!wide) Positioned(left: 20, right: 20, bottom: 16, child: addButton),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.income, required this.expense, required this.money});

  final double income;
  final double expense;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final net = income - expense;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xFF2E6B3F), AppColors.primary]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.netProfit, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(
            money.format(net),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _amountLabel(context.l10n.income, money.format(income))),
              Expanded(child: _amountLabel(context.l10n.expense, money.format(expense))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountLabel(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      Text(
        value,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.categories, required this.money});

  final List<(LedgerCategory, double)> categories;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final max = categories.first.$2;
    return AppCard(
      child: Column(
        children: [
          for (final (category, amount) in categories)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(category.icon, size: 18, color: ledgerColor(category.isIncome)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 92,
                    child: Text(
                      context.l10n.ledgerCategory(category),
                      style: AppText.body.copyWith(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: amount / max,
                        minHeight: 10,
                        color: ledgerColor(category.isIncome),
                        backgroundColor: ledgerColor(category.isIncome).withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 104,
                    child: Text(
                      money.format(amount),
                      style: AppText.h3.copyWith(fontSize: 13),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.money});

  final LedgerEntry entry;
  final NumberFormat money;

  String get _signed => '${entry.isIncome ? '+' : '-'}${money.format(entry.amount)}';

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteLedgerTitle),
        content: Text(
          context.l10n.deleteLedgerBody(
            DateFormat.MMMd(context.localeName).format(entry.date),
            context.l10n.ledgerCategory(entry.category),
            money.format(entry.amount),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete, style: const TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await FarmScope.read(context).deleteLedgerEntry(entry.id);
  }

  Future<void> _edit(BuildContext context) async {
    final saved = await showLedgerSheet(context, editing: entry);
    if (saved != null && context.mounted) showMessage(context, context.l10n.ledgerUpdated);
  }

  @override
  Widget build(BuildContext context) {
    final color = ledgerColor(entry.isIncome);
    final category = context.l10n.ledgerCategory(entry.category);
    return GestureDetector(
      onTap: () => _edit(context),
      onLongPress: () => _delete(context),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconBubble(
              color: color.withValues(alpha: 0.12),
              child: Icon(entry.category.icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.note.isEmpty ? category : entry.note,
                    style: AppText.h3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.note.isNotEmpty) Text(category, style: AppText.caption),
                ],
              ),
            ),
            Text(_signed, style: AppText.h3.copyWith(fontSize: 15, color: color)),
            IconButton(
              tooltip: context.l10n.delete,
              onPressed: () => _delete(context),
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// 매출·비용 한 건을 입력받아 장부에 적는다. [editing]을 주면 그 기록을 고친다.
/// 적거나 고친 기록을 돌려주고, 취소하면 null.
Future<LedgerEntry?> showLedgerSheet(BuildContext context, {DateTime? initialDate, LedgerEntry? editing}) =>
    showModalBottomSheet<LedgerEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) =>
          _LedgerSheet(initialDate: editing?.date ?? initialDate ?? FarmScope.read(context).now, editing: editing),
    );

class _LedgerSheet extends StatefulWidget {
  const _LedgerSheet({required this.initialDate, this.editing});

  final DateTime initialDate;
  final LedgerEntry? editing;

  @override
  State<_LedgerSheet> createState() => _LedgerSheetState();
}

class _LedgerSheetState extends State<_LedgerSheet> {
  late bool _income = widget.editing?.isIncome ?? true;
  late LedgerCategory _category = widget.editing?.category ?? LedgerCategory.crops;
  late DateTime _date = widget.initialDate;
  final _amount = TextEditingController();
  late final _note = TextEditingController(text: widget.editing?.note);
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final editing = widget.editing;
    if (editing != null && _amount.text.isEmpty) {
      // 쉼표 없이 통화 자릿수만큼 적어 둔다(원화 300000, 달러 12.50). 입력할 때와 같은 형식이다.
      final digits = moneyFormat(context, FarmScope.read(context).state.profile.currency).decimalDigits ?? 0;
      _amount.text = editing.amount.toStringAsFixed(digits);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _setType(bool income) => setState(() {
    _income = income;
    _category = LedgerCategory.of(income: income).first;
  });

  Future<void> _pickDate() async {
    final now = FarmScope.read(context).now;
    final first = DateTime(now.year - 5);
    final picked = await showDatePicker(
      context: context,
      // 아주 오래된 달을 보다가 열어도 달력 범위를 벗어나지 않게 한다.
      initialDate: _date.isBefore(first) ? first : _date,
      firstDate: first,
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final store = FarmScope.read(context);
    final digits = moneyFormat(context, store.state.profile.currency).decimalDigits ?? 0;
    final amount = parseMoney(_amount.text, digits);
    if (amount == null || amount <= 0) {
      setState(() => _error = context.l10n.mustBePositive);
      return;
    }
    if (amount > FarmStore.maxLedgerAmount) {
      setState(() => _error = context.l10n.ledgerAmountTooLarge);
      return;
    }
    final editing = widget.editing;
    final entry = editing == null
        ? await store.addLedgerEntry(category: _category, amount: amount, date: _date, note: _note.text)
        : await store.updateLedgerEntry(editing.id, category: _category, amount: amount, date: _date, note: _note.text);
    if (mounted) Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final money = moneyFormat(context, FarmScope.read(context).state.profile.currency);
    return Padding(
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
            Text(
              widget.editing == null ? context.l10n.addLedgerEntry : context.l10n.editLedgerEntry,
              style: AppText.h2,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(context.l10n.income)),
                  ButtonSegment(value: false, label: Text(context.l10n.expense)),
                ],
                selected: {_income},
                showSelectedIcon: false,
                onSelectionChanged: (s) => _setType(s.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: ledgerColor(_income),
                  selectedForegroundColor: Colors.white,
                  backgroundColor: AppColors.surface,
                  side: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final c in LedgerCategory.of(income: _income))
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 16),
                    label: Text(context.l10n.ledgerCategory(c)),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                    selectedColor: ledgerColor(_income).withValues(alpha: 0.16),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              autofocus: widget.editing == null,
              keyboardType: TextInputType.numberWithOptions(decimal: (money.decimalDigits ?? 0) > 0),
              decoration: InputDecoration(
                labelText: context.l10n.ledgerAmount,
                prefixText: '${money.currencySymbol} ',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: InputDecoration(labelText: context.l10n.date),
                child: Text(DateFormat.yMMMEd(context.localeName).format(_date), style: AppText.body),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: context.l10n.optionalMemo),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: context.l10n.saveRecord, icon: Icons.check_rounded, onTap: _save),
          ],
        ),
      ),
    );
  }
}
