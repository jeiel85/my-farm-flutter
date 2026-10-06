import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/features/settings/backup_actions.dart';

void main() {
  test('저장 위치 URI에서 파일 이름을 뽑는다', () {
    expect(savedFileName(Uri.file(r'C:\Users\me\win-backup.json', windows: true), 'x'), 'win-backup.json');
    expect(
      savedFileName(
        Uri.parse('content://com.android.externalstorage.documents/document/primary%3ADownload%2Fmyfarm.json'),
        'x',
      ),
      'myfarm.json',
    );
    expect(savedFileName(Uri.parse('blob:https://example.com/123'), 'fallback.json'), 'fallback.json');
  });
}
