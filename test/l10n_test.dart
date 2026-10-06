import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/l10n/l10n.dart';

void main() {
  test('남은 시간은 0인 단위를 빼고 짧게 쓴다', () {
    final ko = lookupAppLocalizations(const Locale('ko'));
    String d(int seconds) => ko.duration(Duration(seconds: seconds));
    expect(
      [d(2 * 3600), d(2 * 3600 + 5 * 60 + 9), d(6 * 60), d(6 * 60 + 12), d(30), d(-5)],
      ['2시간', '2시간 5분', '6분', '6분 12초', '30초', '0초'],
    );
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.duration(const Duration(minutes: 40)), '40 min');
  });
}
