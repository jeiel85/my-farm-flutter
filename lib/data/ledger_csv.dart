import 'models.dart';

/// 장부를 표 계산 프로그램에서 열 수 있는 CSV(RFC 4180)로 만든다.
///
/// - 엑셀이 한글을 UTF-8로 알아보도록 BOM을 붙이고 줄 끝은 CRLF로 둔다.
/// - 행은 오래된 날부터, 같은 날은 적은 순서대로(목록 위치) 둔다.
/// - 금액은 매출 양수·비용 음수로 적어 열 합계가 곧 순이익이 되게 한다. 통화 자릿수만큼만 적고 천 단위 쉼표는 넣지 않는다.
/// - 메모가 `=`·`+`·`-`·`@`로 시작하면 수식으로 실행되지 않도록 앞에 `'`를 붙인다.
String ledgerCsv(
  List<LedgerEntry> ledger, {
  required List<String> header,
  required String Function(bool income) typeLabel,
  required String Function(LedgerCategory category) categoryLabel,
  required String currency,
  required int decimalDigits,
}) {
  final rows = [for (final (i, e) in ledger.indexed) (i, e)]
    ..sort((a, b) {
      final byDate = a.$2.date.compareTo(b.$2.date);
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
  final out = StringBuffer('\uFEFF')..write(_row(header));
  for (final (_, e) in rows) {
    out.write(
      _row([
        dateKeyOf(e.date),
        typeLabel(e.isIncome),
        categoryLabel(e.category),
        (e.isIncome ? e.amount : -e.amount).toStringAsFixed(decimalDigits),
        currency,
        _safeText(e.note),
      ]),
    );
  }
  return out.toString();
}

String _row(List<String> cells) => '${cells.map(_quote).join(',')}\r\n';

String _quote(String cell) => RegExp(r'[",\r\n]').hasMatch(cell) ? '"${cell.replaceAll('"', '""')}"' : cell;

String _safeText(String text) => RegExp(r'^[=+\-@\t\r]').hasMatch(text) ? "'$text" : text;
