import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/data/ledger_csv.dart';
import 'package:my_farm/data/models.dart';

void main() {
  LedgerEntry entry(String id, LedgerCategory c, double amount, DateTime date, [String note = '']) =>
      LedgerEntry(id: id, category: c, amount: amount, date: date, note: note);

  String csv(List<LedgerEntry> ledger, {int digits = 0}) => ledgerCsv(
    ledger,
    header: ['날짜', '구분', '분류', '금액', '통화', '메모'],
    typeLabel: (income) => income ? '매출' : '비용',
    categoryLabel: (c) => c.name,
    currency: 'KRW',
    decimalDigits: digits,
  );

  test('BOM과 CRLF로 쓰고, 오래된 날부터·같은 날은 적은 순서로, 비용은 음수로 적는다', () {
    final out = csv([
      entry('l3', LedgerCategory.feed, 120000, DateTime(2026, 10, 4)),
      entry('l1', LedgerCategory.crops, 300000, DateTime(2026, 10, 3), '토마토 직판'),
      entry('l2', LedgerCategory.vet, 5000, DateTime(2026, 10, 4)),
    ]);
    expect(out.startsWith('\uFEFF'), isTrue);
    expect(out.substring(1).split('\r\n'), [
      '날짜,구분,분류,금액,통화,메모',
      '2026-10-03,매출,crops,300000,KRW,토마토 직판',
      '2026-10-04,비용,feed,-120000,KRW,',
      '2026-10-04,비용,vet,-5000,KRW,',
      '',
    ]);
  });

  test('쉼표·따옴표·줄바꿈은 따옴표로 감싸고, 수식으로 읽힐 메모는 앞에 작은따옴표를 붙인다', () {
    final out = csv([
      entry('a', LedgerCategory.otherIncome, 12.5, DateTime(2026, 1, 2), '1,000개 "특가"\n완판'),
      entry('b', LedgerCategory.otherExpense, 3, DateTime(2026, 1, 3), '=HYPERLINK("x")'),
      entry('c', LedgerCategory.otherExpense, 3, DateTime(2026, 1, 4), '-5kg 손실'),
    ], digits: 2);
    final lines = out.substring(1).split('\r\n');
    expect(lines[1], '2026-01-02,매출,otherIncome,12.50,KRW,"1,000개 ""특가""\n완판"');
    expect(lines[2], '2026-01-03,비용,otherExpense,-3.00,KRW,"\'=HYPERLINK(""x"")"');
    expect(lines[3], "2026-01-04,비용,otherExpense,-3.00,KRW,'-5kg 손실");
  });
}
